---
title: Runtime Alias Detection
tags:
- programming
- rust
summary: |
  My [`bitvec`] project is composed of a very small handful of core engineering
  components without which the project fundamentally cannot exist. This article
  addresses the most theoretically important: pointer-value alias analysis.

  [`bitvec`]: /crates/bitvec
---

> Rust version: `1.51.0`
>
> [`bitvec`] version: `0.22`
{:.bq-info role="complementary"}

## Introduction

`bitvec` exists to translate user-code expressions directly into memory-access
and shift/mask instructions. However, it is itself a Rust library, rather than
an assembler macro system, so it cannot emit processor instructions. Instead, it
must emit Rust HIR expressions that satisfy the abstract rulesets of both the
Rust Abstract Machine and the LLVM Memory Model, as implemented in `rustc` and
`miri`.

Neither Rust nor LLVM have sufficient precision to understand and permit
`bitvec`’s operations. Similar endeavours in other libraries or languages result
in failures in safety, performance, or both; these failures are unacceptable to
all Rust projects and to me in particular.

You may find [this report on data races in Firefox][0] interesting. One section
in particular, **Beware Bitfields**, is relevant. I won’t repeat their
investigation here, but I will make two extraördinary claims that I’ll back up
over the course of this article. Specifically, `bitvec`:

1. expresses the functionality they want without permitting the bug they found,
1. and expresses that functionality without demanding the solution they used.

Let’s dive in.

## Memory Aliasing

Miri and LLVM have strict interpretations of memory safety, and have liberty to
either *reject* or *miscompile* programs whose source code violates their rules.
`bitvec` exists solely and specifically to violate the spirit of those rules
without ever violating the letter.

> The ruleset that governs how Rust-language source code is understood to
> operate is generally called the Rust Abstract Machine, but the acronym is
> already taken by a much more prominent entity and I don’t want to keep typing
> it out for the whole article. The primary *implementation* of the Rust
> Abstract Machine ruleset is the Mid-level Intermediate Representation
> Interpreter, Miri, which resides within the `rustc` project.
{:.bq-info .iso7010 .m004 role="complementary"}

The memory model that `bitvec` targets operates in terms of three main concepts:
*regions*, which are sequences of zero or more elements in an abstract memory
space; *elements*, which are indivisible (but perhaps decomposable) typed blocks
of memory.; and *borrows*, which describe relationships from observers to
regions and elements and determine what actions may be applied to them.

> We don’t need to get into the concepts of value representation or liveness,
> because `bitvec` exclusively operates on register types that are flat,
> unsemantic, bags-of-bits. All patterns are valid, there are no niches, and no
> destructors.
{:.bq-info .iso7010 .m002 role="complementary"}

<!-- -->

> **HOWEVER**. Both Rust and LLVM have the concept of *uninitialized memory*,
> which refers to the lifecycle state in the abstract machine where a given
> abstract element has not yet been assigned a value pattern and thus committed
> to a storage location. Just because any bit-pattern is a valid instance in the
> register types `bitvec` uses does not allow it to operate on uninitialized
> memory.
>
> Uninitialized memory is not about the bit-pattern, but about whether a storage
> location has been committed for a name. *Nothing* can step outside this rule,
> *except* for the [`MaybeUninit`] language item. I am not special. You are not
> special. Do not play casually with uninitialized memory.
{:.bq-harm .iso7010 .p024 role="complementary"}

### Ground Rules

Miri (roughly) observes program state as a time-series of transformations
applied to a set of region spaces, and the program transitions through these
states by creating element values in those spaces and by applying borrows to
them.

Miri has a small set of rules for what borrows are valid to do. I’m not going to
dive deeply into them here; the short version is:

- borrows to a *region* can be monotonically narrowed, but cannot re-widen
- borrows to a *region* or to an *element* can be split, producing new,
  narrower, child borrows
- borrows marked as `&mut` can never overlap in space with any other borrow that
  overlaps with them in time
- borrows may be granted write permission by their source, and they may later
  drop that write permission to read-only, but they may never gain write
  permission *from* read-only. This is unrelated to `&mut`

> Bad name! It should have been `&uniq`. But `&mut` was easier to teach at
> first, even if it turned out to be insufficiently precise later. It’s the
> high school explanation but this document is at the post-grad level and Miri
> is *literally* its author’s Ph.D. project. Anyway
{:.bq-info .iso7010 .m001 role="complementary"}

Memory is said to be *aliased* when there exist two or more borrows to any
element or region that overlap in space and time, and *one* or more of thoses
borrows has write permissions. Alias conditions are not themselves illegal in
Miri or LLVM. However, there are only two ways to introduce them.

#### Legal Aliasing

The [`UnsafeCell`] language item is the sole source of `&` shared borrows with
write permissions. If you create values of this type, you can freely create
overlapping references in space (slice regions or structural field projection)
or time (multiple sequence points in program code) that have write permission to
a particular location.

How you deal with that is your problem. The Rust language will help you out by
forbidding you from moving any of those `&` references to other threads of
execution, but this is subversible.

> *To my knowledge*, lying to get an `&UnsafeCell` across a thread boundary and
> performing data races with it doesn’t cause any miscompilations; you just get
> the same torn read/write behavior you would see in other languages. It’s still
> Undefined Behavior, but I don’t think it has any deleterious effects in
> codegen.
{:.bq-warn .iso7010 .w004 role="complementary"}

#### Illegal Aliasing

> This is the other lie you can tell the compiler:
>
> ```rust
> let mut x = 0;
> let y = &x;
> let Z: &mut i32 = unsafe {
>   &mut *(y as *const _ as *mut _)
> };
> ```
>
> These five lines make your entire program invalid. You don’t have to create
> any memory accesses. You could discard `y` unused. Doesn’t matter. The entire
> program is illegal. I don’t know what does or doesn’t happen in codegen here,
> and I don’t care, and neither does anyone on the language team. This is not
> legal, it will never be legal, and any sufferance of it occurs merely because
> the compiler hasn’t bothered to exploit it *yet*.
{:.bq-harm .iso7010 .f005 role="complementary"}

### Aliasing, Mutation, and Exclusion

The only difference between ownership and exclusive access is permission to
destroy the value or the storage slot. `bitvec` doesn’t have destructable values
so this is not interesting to us.

> We’re talking about the [`BitSlice`] region here, not owning handles, which do
> have destructors but don’t get aliased.
{:.bq-safe}

Miri has two rules that in combination allow `bitvec` a great deal of freedom to
operate:

1. Any `&mut` borrow can give up its exclusion and degrade to `&`. `&` is freely
   duplicable.
1. Any write-capable borrow can retain its write permission while changing type.

All `&mut` exclusive references have write permissions; thus, the name. Also,
any `&UnsafeCell` references have write permissions. This means that the
transmutation sequence `&'a mut T` → `&'b mut UnsafeCell<T>` →
`&'c UnsafeCell<T>` preserves its write permission while dropping its exclusion
requirement, allowing alias conditions for the lifetime `'c`.

This is how `bitvec` implements write capabilities. All mutation is done through
aliased references to alias-safe types (some wrapper over `UnsafeCell`), and
write methods are only available on `BitSlice` references which received a write
permission from their creator.

## Sub-Element Splits

As stated earlier, Miri doesn’t have the precision to understand sub-element
borrows. While `bitvec` logically implements the `&mut` exclusion ruleset on
individual bits, and permits the following code to be sound:

```rust
use bitvec::prelude::*;

let mut ax = 0u8;
let bits: &mut BitSlice<_, _>
  = ax.view_bits_mut::<Lsb0>();
let (al, ah): (
  &mut BitSlice<_, _>,
  &mut BitSlice<_, _>,
) = bits.split_at_mut(4);
```

It has to do some trickery in order to keep Miri satisfied. You can read more
about how `&/mut BitSlice` works in [*The Ad-Dressing of Bits*][1]; that’s not
really relevant here.

Let’s fill in the types that occur in that snippet somewhat:

```rust
let bits: &mut BitSlice<Lsb0, u8>
  = ax.view_bits_mut::<Lsb0>();
```

Here, `ax` is `mut u8`, which gets borrowed as `&mut u8`. Because we receive an
exclusive reference from ordinary Rust, we know that Rust guarantees exclusion
and we can use ordinary accesses without concern.

This stays true even if we narrow the borrow: `bits[1 .. 7].set_all(true)` knows
that for the duration of its call, bits `0` and `7` are not observable by any
borrow, so indexing does not need to produce an alias condition.

Now let’s look at that call to `.split_at_mut()`.

```rust
let (al, ah): (
  &mut BitSlice<Lsb0, <u8 as BitStore>::Alias>,
  &mut BitSlice<Lsb0, <u8 as BitStore>::Alias>,
) = bits.split_at_mut(4);
```

You may be familiar with the type signature of `[T]::split_at_mut`, which is
`(&mut [T], usize) -> (&mut [T], &mut [T])` and doesn’t have any extra markers.

But because `.split_at_mut` receives an exclusive region borrow and transforms
it into two coëqual subregion borrows, it has to mark them as potentially
colliding on the underlying elements that Miri can see, even though the `bitvec`
library knows that they do not collide on the individual bits that only it can
see.

> This is what enables it to return two exclusive references: neither handle can
> be used to observe the other’s region.
{:.bq-safe role="complementary"}

This `<T as BitStore> -> <T as BitStore>::Alias` transformation occurs in all
the APIs that may potentially introduce Miri-level aliasing. Let’s go look at
what the consequences of this marker are.

## Finite Typestate Machines

The `.split_at_mut` function describes one transition along a sequence graph.
Let’s take a look at the graph itself:

```rust
//  bitvec:src/store.rs

pub trait BitStore {
  type Mem: BitStore<Mem = Self::Mem>
    + BitRegister;
  type Access: BitStore<Mem = Self::Mem>
    + BitAccess<Item = Self::Mem>;
  type Alias: BitStore<Mem = Self::Mem>;
  type Unalias: BitStore<Mem = Self::Mem>;

  //  some methods and secret constants
}
```

These four associated types represent neighbors in the typestate graph, and
certain transitions between them are defined. Each of them is defined to also be
a `BitStore` implementor with the same `Mem` type as the starting implementor;
this requirement is what enables safe movement along the graph.

The `BitRegister` trait is implemented on the unsigned integers (`u8`, `u16`,
`u32`, `usize`, and `u64` on ABIs with 8-byte alignment), and represents the
width of the bus instruction used to access memory.

The `BitAccess` type tracks the current synchronization instruction used to
access memory. It is either `Cell<Self::Mem>` or `AtomicMem`, depending on crate
build configuration, target capability, implementor, etc. As a rule, `Cell`s and
atomics use themselves, and the ordinary integers use `Cell`s.

Because `Cell`s and atomics are always aliased by borrows outside `bitvec`’s
knowledge, they also `Alias` and `Unalias` to themselves. They are pinned on the
typestate graph, and no amount of manipulation can have an effect.

Remember from above that an exclusive reference to an unsynchronized integer
region can *narrow* without introducing aliasing; only *splitting* introduces
aliases. As such, while the `T: BitStore` parameter in a `BitSlice` is an
ordinary integer, it can safely use `Cell` to access memory: no other handle
exists with write permissions, so reading does not require any synchrony or
concurrency restrictions.

The `Alias` associated type for ordinary integers can’t be either its `Cell`
wrapper or its atomic equivalent, because those types can never leave. Instead,
it uses a newtype that uses crate configuration (`feature = "atomic"`) and
target atomic support to be either atomic or `Cell`ed internally and, most
importantly, require proof of exclusion in order to write to memory. This
ensures that it is never possible to erroneously write to memory with a borrow
ultimately derived from `&u8`.

### For Every Cost, Provide a Rebate

The above work describes how `bitvec` is able to safely and correctly manage
write permissions that alias according to Miri. However, it is applied at the
type level, and not at the value level. This means that code such as the
following has to pay the cost of alias permissions, even though it does not
produce alias conditions in Miri:

```rust
let mut data = [0u8; 2];
let bits = data.view_bits_mut::<Lsb0>();
let (lo, hi) = bits.split_at_mut(8);
```

The `lo` and `hi` bindings here are typed as `<u8 as BitStore>::Alias`, even
though they …don’t alias. The end result is equivalent to this code:

```rust
let mut data = [0u8; 2];
let (lo, hi) = data.split_at_mut(1);
let (l_bits, h_bits) = (
  lo.view_bits_mut::<Lsb0>(),
  hi.view_bits_mut::<Lsb0>(),
);
```

The Miri-observable region borrows in these two code samples are identical, yet
the first version is required to either add atomic locking costs or remove
multithreading capability, while the second is not.

We know that the underlying memory is not aliased by inspecting the values of
the `BitSlice` region pointers as well as their storage type parameters. This
value inspection takes place in the `domain` module, whose types allow taking
any given bit-slice and *removing* the `::Alias` marking from as much of it as
is safe, restoring the original, unrestricted, memory access behavior.

## Preëminent Domains

Consider any region of memory elements. I am going to use eight bits for the
diagram, because I have finite drawing space. When viewing that region as
individual bits, any arbitrary bit-slice breaks down to one primary question and
two subsquent questions:

- does the slice touch the edge bit (`0` or `n-1` in an `n`-bit element)?
- if yes, does it:
  - touch bit `0`?
  - touch bit `n-1`?

Any bit-slice that does not touch either edge bit in a single element is by
definition irreducible. Any bit-slice that *does* touch an edge bit can be
subdivided into two bit-slices, one on each side of the edge bit. In this
diagram I have listed the nine general cases:

```term
|00000000│11111111│22222222|
|76543210│76543210│76543210│
├────────┼────────┼────────┤
│        │        │        │ 1
│        ╞════╡   │        │ 2
│        │ ╞════╡ │        │ 3
│        │   ╞════╡        │ 4
│    ╞═══╪════╡   │        │ 5
│    ╞═══╪════════╡        │ 6
│        ╞════════╪═══╡    │ 7
│    ╞═══╪════════╪═══╡    │ 8
╞════════╪════════╪════════╡ 9
```

1. This is the empty slice; as it touches no bits at all, it by definition
   cannot alias any elements.
1. This slice touches bit `0` in an element, but does not touch bit `n-1`.
1. This slice does touch memory, but does not touch either edge bit in its
   element. As such, it is either the result of *narrowing* a borrow (as all
   borrows begin spanning the entire element) or *splitting* a borrow,
   introducing alias conditions. It can’t change, and is uninteresting.
1. Like 2, this touches bit `n-1`, but not bit `0`.
1. This is the first bit-slice that spans multiple elements. It can be split
   into two subslices: `3:0` in element 0, and `7:3` in element 1. Each subslice
   touches only one edge bit in its respective element.
1. Like 5, this can be split into two subslices at the element 0/element 1
   boundary. It is the first bit-slice where part of it touches both edges (of
   element 1).
1. This is equivalent to 6.
1. This bit-slice spans two elements, and splits into three subslices. It is a
   union of lines 6 and 7.
1. Lastly, this line spans the region in its entirety, excluding any other
   bit-slice.

The questions and table examples are encoded in the four `enum`s provided in the
`domain` module; all have the general shape shown here:

```rust
pub enum Domain<O, T> {
  Enclave {
    addr: *const T,
    head: Head<T>,
    tail: Tail<T>,
  },
  Region {
    head: Option<(*const T, Head<T>)>,
    body: *const [T::Unalias],
    tail: Option<(*const T, Tail<T>)>,
  },
}
```

Each case above can be broken down into either an `Enclave` (line 2), or some
combination of the three fields in a `Region`. Subslices that touch bit `0` but
not `n-1` are `Some(tail)`; subslices that touch `n-1` but not `0` are
`Some(head)`, and any/all fully-spanned elements comprise the `body`.

The `&mut` exclusion rule means that `bitvec` can guarantee that the bits
covered by an `&mut BitSlice` are wholly inaccessible by any other `BitSlice`
handle, and therefore any elements that the bit-slice completely spans are safe
to access without alias markings.

This property is also upheld by shared `&BitSlice` references, as their
existence means that other handles may *view* but may not *modify* the elements.

Partial-use elements at the edges must still retain their original marking
state, because the handle that produced the domain has no way of knowing whether
those elements are subject to other views or not. They do not have to be
affirmatively marked, as all splitting methods already do that before the
reference is created.

### Usage

I have not yet produced benchmarks that show a significant, affirmative,
difference in timing when accessing `BitSlice`s through aliased and unaliased
memory. I do not know whether splitting a bit-slice with [`.bit_domain()`] or
[`.bit_domain_mut()`] has a performance benefit. But the option is there if you
want to make use of it.

I *do*, however, have benchmarks that show using [`.domain()`] and
[`.domain_mut()`] to temporarily drop the bit-precision view and create a
correct, legal, Miri-compliant, alias-aware view of the underlying memory region
enables `bitvec` to have internal algorithms that are expressive, concise, and
fast.

I use it to drive formatting, copying, testing, and most importantly, the
[`BitField`] trait that powers bitfield pseudolocation behavior.

Constructing a `Domain` view has a high overhead cost, and one of my lingering
goals is to figure out how to reduce the cost of repeated computation. I don’t
think I’ll be able to, unfortunately.

## Conclusion

I have strong reason to believe that the domain-splitting algorithm described
here and implemented in [`bitvec::domain`] is correct. I’ve gone over the math
and checked it in theory and in a comprehensive test suite. I have used Miri to
detect memory permission errors in a test case, then introduced the domain logic
to resolve them.

This code has been published and widely used for two years without causing
runtime errors.

If you believe you have found a defect, in practice or in theory, *please*
contact me. This is a critical component in `bitvec` and an area of ongoing
research in Miri, and I do not expect to be able to presume that it is settled
yet.

This analysis is a natural consequence of Rust’s existing borrow rules, and
would not be safely expressible without them. It has enabled `bitvec` to neatly
and precisely implement single-bit addressing in complex usage environments
without introducing data-race bugs and allowing users to remove cautionary
markings to the maximum extent possible without violating the rules of the
underlying logic engines or hardware.

[0]: https://hacks.mozilla.org/2021/04/eliminating-data-races-in-firefox-a-technical-report/
[1]: /blog/bitvec/addressing-bits
[`BitField`]: https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html
[`BitSlice`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html
[`MaybeUninit`]: https://doc.rust-lang.org/core/mem/union.MaybeUninit.html
[`UnsafeCell`]: https://doc.rust-lang.org/core/cell/struct.UnsafeCell.html
[`bitvec`]: /crates/bitvec
[`bitvec::domain`]: https://docs.rs/bitvec/latest/bitvec/domain
[`.bit_domain()`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html#method.bit_domain
[`.bit_domain_mut()`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html#method.bit_domain_mut
[`.domain()`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html#method.domain
[`.domain_mut()`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html#method.domain_mut
