---
title: The Ad-Dressing of Bits
tags:
- programming
- rust
scripts:
- ./2021-04-16-addressing-bits/randaddr.js
summary: |
  My [`bitvec`] project is composed of a very small handful of core engineering
  components without which the project fundamentally cannot exist. This article
  addresses the pointer encoding allowing it to interact with the language core
  libraries.

  [`bitvec`]: /crates/bitvec
---

> Rust version: `1.51.0`
>
> [`bitvec`] version: `0.22`
{:.bq-info role="complementary"}

## Introduction

`bitvec` exists to implement a bit-precision addressing scheme that has the same
source code affordances as byte-addressed memory while transparently using
compacted memory accesses internally. It is a library implementation of
shift/mask operations that presents a `usize -> bool` API to clients that
mirrors existing APIs in the Rust core libraries that do not use memory
compaction.

Processors have stabilized as addressing memory with the byte as the unit of
step for several decades now, and software built atop them retains the same
model. As such, neither LLVM nor Rust have the concept of single-bit addressing,
and the implementation in `bitvec` has to exist within their rules about element
addressing in order to work.

## Memory Addressing

> If you already know about slot alignment, you can skip
> [past this section](#consequences-of-alignment).
{:.bq-safe role="complementary"}

The main-memory address space is modeled as a long sequence of slots. Each slot
is consecutively numbered, running from `0` at the bottom and some very large
number at the top. The slot at each number has a fixed amount of information it
can store. That amount is eight bits. These bits are always in the same order at
each slot.

This makes memory essentially two-dimensional: it is a plane with a length of
the memory capacity in bytes and a depth of eight bits.

### Batched Access

Because information is typically wider than eight bits, and individual memory
transactions are slow, memory controllers will frequently send back larger
batches of memory at a time, since heuristically for any given request, it is
*very likely* that the processor will also request its neighbors. Rather than
start the batch at the requested address and count upwards for the batch size,
though, memory controllers typically just mask away the least `N` bits of the
requested address. This imprecision is what gives rise to alignment: if the
range you want is not the range that the memory controller produces, you need to
issue two requests rather than one.

> Some processors don’t penalize misaligned requests; they’ll do the lookup and
> recombination for you and just take longer. Others will cause a processor
> fault if your requested address does not match the instruction you’re using to
> request it.
{:.bq-warn .iso7010 .w004 role="complementary"}

### What, Exactly, Are Addresses?

To the CPU, they’re exactly what I’ve said. They’re street numbers on one very
long street.

To a programming-language compiler, they’re more than just a number. But I am
not a compiler engineer, and so I’m not going to talk about that too much.

Let’s look at some arbitrary address.

```text
0x00_00_7f_fc_8a_ff_6d_ef
```

{:data-contents="pointer"}

> Like I said, addresses are actually only 48 bits wide today, but their slots
> are 64 bits wide in the processor. The top sixteen bits are reserved, and the
> processor will issue a bus fault if they do not match bit 47. They may become
> used in the future, and so are not eligible to store non-address metadata in
> future-compatible programs.
{:.bq-info .iso7010 .m007 role="complementary"}

That is the address of a single byte, so it can have any last digit, including
odd digits, it wants. Let’s get an address for a two-byte value:

```text
0x00_00_7f_fd_c0_ed_be_de
```

{:data-contents="pointer"}

This will always be an even number, ending in `0`, `2`, `4`, `6`, `8`, `a`, `c`,
or `e`. It can be any of those, but not an odd number.

Let’s ask for the address of a four-byte region.

```text
0x00_00_7f_fe_61_a7_3a_ec
```

{:data-contents="pointer"}

This address is required to be a multiple of four, ending in `0`, `4`, `8`, or
`8`. Let’s finish by asking for the address of an eight-byte region:

```text
0x00_00_7f_ff_26_fb_ef_88
```

{:data-contents="pointer"}

These ones are easy: the last digit of the address will be either `0`, or `8`.
Nothing else.

There are wider numbers than this in memory, but eight bytes is usually where
CPUs stop enforcing alignment. So we won’t talk about those.

### Consequences of Alignment

The address of an element with one-byte alignment can have any last digit it
wants, and so has zero bits at the end of the address number to spare.

The address of an element with two-byte alignment can only be an even number, so
it must always have a last bit of `0`, so that last bit is available. We can put
a flag in it to mark whether we want the lower or higher byte, as long as we
remove that flag before giving the address to the memory controller.

The address of an element with four-byte alignment has two bits to spare at the
very end; we can use one of those bits to select the high or low pair, and the
other to select the high or low byte within that pair.

The address of an element with eight-byte alignment has three bits to spare at
the end; we can put three flags in them, for high or low quadron, high or low
pair in that half, and high or low byte in that pair.

Thus, no matter what *element* type we have – `u8`, `u16`, `u32`, `u64` – we
can always cram enough information in its address element to narrow the address
down to a single interesting byte.

Here’s a table:

|  Type | Alignment | Spare Bits |
| ----: | --------: | ---------: |
|  `u8` |         1 |          0 |
| `u16` |         2 |          1 |
| `u32` |         4 |          2 |
| `u64` |         8 |          3 |

This may seem obvious, or tautological, and it is. All the work done in this
section is just done to compute the bitmasks used to turn a byte address back
into a correct element address, in a way that `bitvec` can write generically
over the integer types.

## Rust References

Rust has a concept called a “reference”. A reference is, to the machine, the
address of some data. To the compiler, it has much more information attached to
it, but we don’t care about that right now.

There are six versions of references in the language, on two axes. On one axis,
we have `&T` references vs `&mut T` references – this distinction is purely
internal to the compiler, and only marks whether or not the compiler will allow
us to use exclusive privileges through the reference to the *referent*, that is,
whatever data lives at the address the reference contains.

The other axis is the structure of the reference value. There are three
structural variants:

- `&[mut] T where T: Sized`: A reference, immutable or mutable, to a section of
  data with a statically known size, fixed for the lifetime of the program and
  known to the compiler. Because the compiler knows the length, it does not need
  to put the length in the program, and so these two references are only the
  address of the start of the referent.

- `&[mut] T where T: !Sized`: A reference, immutable or mutable, to a section of
  data whose length the compiler does *not* know, or *might* change in the
  lifetime of the program. The most common two examples are `[T]` slices, and
  `str` text. Because the length of that data might change at runtime, the
  compiler must store the length of the data alongside its address, so these
  references are essentially a tuple of `(&[mut] _, usize)`, where `_` is some
  underlying type of known size, and the `usize` is the count of how many
  elements of the underlying type are in the referent region.

- `&[mut] dyn Trait`: A reference to an object of unknown concrete type. This is
  two pointers: one to the object itself, and the other to a table of functions
  that can be called on it. It is a tuple of `(&[mut] _, &VTable<_>)`. We don’t
  care about this reference for this article.

As I discussed above, any of the four machine fundamental types `u8`, `u16`,
`u32`, or `u64` can be legally refined to the address of a `u8`. As long as we
remember to remove the refinement before asking the memory controller to give us
the original type, this is fine. It only uses the known-available bits at the
low end of the address, and doesn’t touch the sixteen bits at the high end
that will cause the CPU to crash us.

This does not address a bit.

## Bit References

A byte is eight bits wide. Eight bits of position require only three bits of
address. So we need to get three more bits, *somewhere*, and we already know
that the sixteen empty-looking bits of the high end of the address are
forbidden to us on pain of termination.

```text
xxxxxxxxxxxxxxxx yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy zzz
^---Illegal----^ ^---------------Selects a u64---------------^ ^^^
                                                    Selects a byte
```

This is why I talked about unsized references (the middle type in the list)
above. We can get sixty-four more bits if we decide we don’t want to address
just *one* bit, but rather, address *any amount* of them.

```text
xxxxxxxxxxxxxxxx yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy zzz
^---Illegal----^ ^---------------Already used----------------^ ^---+
aaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa zzz +- Bit
^------------------------(Bit) Length------------------------^ ^---+
```

By adding in a second component to our reference, we get the last three bits we
need to turn our byte address into a bit address, and we get all the rest of the
bits in the second component to count how many bits we have, starting at the
bit denoted by the address.

Additionally, this works on 32-bit processors that do not use the AMD64 page
table pointer layout and do not have dead high bits, allowing `bitvec` to be
used portably across any device Rust targets.

## Encoding

We have our target structure (an address and a counter), and we have our
components (a data address, a byte selector, a bit selector, and a bit counter).
Now let’s pack everything into the space available.

```rust
#[repr(C)]
struct BitSpan<T> {
  ptr: *const T,
  len: usize,
}
```

> This is not exactly correct, and I’ll address it below. My articles are a
> journey. Bear with me.
{:.bq-harm .iso7010 .p025 role="complementary"}

First up: the data address goes in the pointer slot, exactly as already
expected. We double-check that the bottom 0-3 bits, depending on data type, are
already zeroed.

Next, we pack our byte selector into the bottom 0-3 bits. This essentially turns
the address field into the address of a `u8`, no matter its original type. This
is okay; the total address is always to a `u8` that is covered by the original
type at the original address, and the original address is recoverable by
masking. Furthermore, Rust guarantees that all references are aligned to their
type, so we can statically ensure this property by simply only accepting
*references*, not pointers, when creating these structures.

Next, we take our count of how many bits live in the region we’re trying to
describe, make sure the top three bits are zero, and then shift the counter up
by three. We need to check that the top three bits are zero, because they’re
about to be thrown away.

Because our byte selector is between 0 and 3 bits, and our bit selector is 3
bits, we know that the total selector is between 3 and 6 bits. So we can carry
both of them in a single `u8`, and only split them apart inside the structure.

Last, we take our bit selector, and pack it into the bottom three bits of the
bit counter field.

```rust
impl<T> BitSpan<T> {
  pub fn new(data: *const T, bit: u8, len: usize) -> Self {
    //  safety first
    assert!(data.is_well_aligned());
    assert!(bit < data.bit_width());
    assert!(len <= !0 >> 3);

    //  store the address
    let mut ptr = data as usize;
    //  store the byte part of the selector
    ptr &= !7;
    ptr |= (bit as usize >> 3);

    //  store the counter
    let mut len = len << 3;
    //  store the bit part of the selector
    len |= bit as usize & T::BITMASK; // 7, 15, 31, or 63

    Self {
      ptr,
      len,
    }
  }
}
```

And there we have it: a data address, refined to a byte, refined to a bit, and
spanning some count of bits, all neatly packed up in the structure of a slice
reference.

> Rust also defines references as being non-null, and since `BitSpan` is only
> created from references, it can preserve the non-null optimization niche by
> using `NonNull<T>` instead of `*const T`.
{:.bq-safe .iso7010 .e009 role="complementary"}

Now we just need to make the compiler think that it really is a slice reference.

## I Didn’t Understand That Reference

Rust uses references pervasively throughout the language. They’re by far one of
the most common ways to interact with anything. If we want our custom-made bit
address and counter to fit in the language, we have to sneak it past the
compiler.

And the compiler has a very watchful eye.

Here’s what we do:

### Attempted Alchemy

First: it is absolutely undefined behavior to package up any `(&_, usize)` tuple
and use `mem::transmute` to turn it into a reference. It doesn’t matter that the
reference type we’re targeting happens to have the same structure. Calling
`mem::transmute` with a reference in either the input or the output type is
instantly, totally, undefined behavior. The compiler will seize this opportunity
to erase the call to transmute, then the code that tried to use the value that
would have come out of the transmute, then the data that went into the
transmute, then everything that eventually wound up making the data that went
into the transmute.

All of it gets tainted when you try to use `mem::transmute` to make something
that isn’t a reference into a reference, or try to turn a reference into
something else.

Remember: the Rust compiler is *not* your friend. Its primary motivating goal is
to *not* compile your code. It will proactively seek out every avenue it can in
order to not compile your code. As much as a computer program can be said to
want anything, it wants to find any legal reason to reject your code, and it
will use any instance of UB to start doing so. We’re not going to give it any.

So we can’t use `mem::transmute`.

### Sneaking In The Sally Port

There is, however, another way in.

Rust is written in Rust. The Rust compiler and core libraries are all built by
the Rust compiler, and the language is helpfully designed to have as much as
possible defined in the core libraries, rather than in the compiler. We only
have access to the compiler through `core::intrinsics`, but we have access to
(almost) *all* of the core libraries.

And slice references are defined in `core::slice`.

There exist two methods: [`core::slice::from_raw_parts`] and
[`core::slice::from_raw_parts_mut`]. Their full signatures are:

```rust
pub unsafe fn from_raw_parts<'a, T>(
  data: *const T,
  len: usize,
) -> &'a [T];
pub unsafe fn from_raw_parts_mut<'a, T>(
  data: *mut T,
  len: usize,
 -> &'a mut [T];
```

And these functions, it turns out, will package any pointer and counter you give
them into a slice reference, and the compiler has no choice but to let it
happen.

You might be thinking, this is perfect! We’ll take our nicely modified pointer
to some data element, and our nicely modified length counter, and stick them in
this function, and out pops a slice value that fits right in the language!

> ***This is undefined behavior.***
> {:.text-center style="font-size: 125%;"}
{:.bq-harm role="complementary"}

Rust has *very* firm rules about references, and *especially* about slice
references.

All reference values, at all times in a program, *must* obey the rules of the
type to which they refer. A reference to `u32` **must** have an address that is
well aligned to `u32`, so, it **must** have zeros in its bottom two bits.

A *slice* of any type **must** describe exactly as many elements of that type as
the length counter indicates. There **must** be that many elements, starting at
the address and marching up through memory, and if the compiler even suspects
that there aren’t, then that slice becomes undefined behavior, and that UB
propagates up and down through everything that leads to or from it.

### The Narrowest of Types

So far in this article, I’ve talked about types that have a known size in
memory, and types that have an unknown size. There is a third family of types:
those that don’t have any size at all. These are called Zero-Sized Types, or
ZSTs for short.

A ZST can be found at any address in the memory space. It has no width, and it
<ins>generally</ins> has no alignment requirement. Addresses cannot get narrower
than a byte, so ZSTs can only be placed at the start of a byte, but any
<ins>aligned</ins> byte address will do.

> ERRATUM: ZSTs can have alignment requirements attached to them externally. For
> example, `[u64; 0]` has size 0 and alignment 8. Additionally, you can still
> attach the `#[repr(align(BYTES))]` attribute to your own ZST struct
> declarations. Thanks to [@lcnr] for the feedback.
{:.bq-info .iso7010 .m011 role="complementary"}

ZSTs have no width. If you put two ZST elements in a row, the first will be at
some address `x`, and the second will be offset from that address by its width:
`x + 0`, which is, `x`.

You can have infinitely (well, `!0`) many ZST elements in a row in memory,
starting at any address you want, and the only constraint is that the address
you choose must actually be available in your context. This probably means no
kernel-space addresses, but that’s pretty much it. In particular, it does *not*
disallow the zero page – Rust makes a great deal of use of addresses just above
0 as sentinel values that are valid to have as pointers to empty regions.

This even means, for instance, that you can have eight times too many ZST
elements at an address.

So if we take our mangled data address and cast it to `*const ()` or `*mut ()`,
and take our mangled length counter, we can feed them into these particular
slice constructors:

```rust
let bp = BitSpan::<T>::new(addr, start, len);
let bp_ptr = bp.ptr as *const ();
let bp_len = bp.len;
let magic: &'_ [()] = unsafe {
  slice::from_raw_parts(
    bp_ptr,
    bp_len,
  );
};
let more_magic: &'_ mut [()] = unsafe {
  slice::from_raw_parts_mut(
    bp_ptr as *mut (),
    bp_len,
  );
}
```

And this, dear reader, is *not* undefined behavior. Any address can be made the
address of `()`, the canonical empty type, and any amount of `()` can be placed
at that address, and the slice `&[()]` must be able to refer to that many `()`
elements at that address.

Now, because any address may be made into a `()` address, and any address may be
a `u8` address, we can later extract the pointer and length components to go dig
up a byte and work on it.

```rust
let byteptr = magic.as_ptr() as *const u8;
let offset = magic.len() >> 3;
let byte: u8 = unsafe {
  *(byteptr.offset(offset as isize))
};
let which_bit = magic.len() & 7;
let bit = byte & (1 << which_bit) == 1;
```

And just like that, we have used our mangled descriptors to go dig up a byte and
pull a single bit out of it, and the compiler can’t prove we’re not allowed to
do that. It is required to allow raw-pointer jumps and dereferences to occur,
but it doesn’t have to like it, which is why it takes place in an `unsafe`
block.

And that’s how you teach Rust to address individual bits of memory, and describe
contiguous regions of them, without any change to the language itself.

## The Extra Mile

`BitSpan` itself is not a type that anyone should ever use. It is equivalent to
a raw `*const T` or `*mut T` pointer. We can turn it into a `&[()]` slice
reference in order to participate in the entirety of the language framework that
requires references, but we can’t attach any behavior to `&[()]` because that
type is defined entirely in `core`.

What we can do, however, is make a newtype wrapper over `[()]`, and ensure that
our mangled slice handles are only ever used as references of that type, and
have the internal implementation route through `&[()]` as described above.

So we make a new struct:

```rust
struct BitSlice<T> {
  region: [()],
}
```

and now, because `BitSlice` ends in an unsized slice type, it itself becomes an
unsized type. It must only ever be held by reference, `&BitSlice<T>` or
`&mut BitSlice<T>`.

We define two constructors: one to make an immutable reference, and one to make
a mutable reference, both delegating through `BitSpan` and `&[()]`.

```rust
impl<T> BitSlice<T> {
  pub fn new<'a>(
    data: &'a T,
    bit: u8,
    len: usize,
  ) -> &'a Self {
    let bp = BitSpan::new(data, bit, len);
    unsafe { &*(
      slice::from_raw_parts(
        bp.ptr as *const (),
        bp.len,
      ) as *const BitSlice<T>
    )}
  }
  pub fn new_mut<'a>(
    data: &'a mut T,
    bit: u8,
    len: usize,
  ) -> &'a mut Self {
    let bp = BitSpan::new(data, bit, len);
    unsafe { &mut *(
      slice::from_raw_parts_mut(
        bp.ptr as *mut (),
        bp.len,
      ) as *mut BitSlice<T>
    )}
  }
}
```

`&T` and `*const T`, and `&mut T` and `*mut T`, can implicitly convert between
themselves. References to unsized and pointers to unsized are both two-element
structures. This lets us glide through the type pathway without affecting the
bit patterns after construction, and end up with well-formed reference handles.

Then we just add methods to `BitSlice` which take `&self` or `&mut self`, and
teach them how to extract their required parts, and we’re all set with slices.

### Ownership (It’s Not Theft `where T: Copy`)

There are three owning types of `[T]` in standard Rust: `Box<[T]>` and `Vec<T>`.
These happen to be, under the hood, slice pointers, and `Vec` has an allocation
capacity tracker also.

We can do the same thing, but we absolutely cannot use standard-library types.
We have to make our own:

```rust
#[repr(transparent)]
pub struct BitBox<T> {
  ptr: BitSpan<T>,
}

#[repr(C)]
pub struct BitVec<T> {
  ptr: BitSpan<T>,
  cap: usize,
}
```

and reimplement the entire `Box<[T]>` and `Vec<T>` API on them, as well as
custom methods to lower each to their equivalent `&[mut] BitSlice<T>` slices,
but this is more tedious than actually difficult and risky.

## Conclusion

That covers about everything interesting about how `bitvec` makes bit-precision
references. The crate itself does a lot more work I haven’t touched on here,
such as the [`BitOrder`] trait, the relationships between the types above
`BitSpan`, or [avoiding aliasing concerns][0].

The `BitSpan` type’s ability to be used as an ordinary reference is what enables
[`BitSlice`] to fit in all the language core APIs and reach full parity with the
original types. The encoding itself is not terribly interesting nor is it public
API, but it is a necessary component to enable `bitvec` to distinguish itself
from any of its competitors and to fulfill its goal of drop-in compatibility
with existing code.

[0]: /blog/bitvec/alias-detection
[@lcnr]: https://twitter.com/lcnr
[`BitOrder`]: https://docs.rs/bitvec/latest/bitvec/order/trait.BitOrder.html
[`BitSlice`]: https://docs.rs/bitvec/latest/bitvec/slice/struct.BitSlice.html
[`bitvec`]: /crates/bitvec
[`bitvec::pointer::BitSpan`]: https://github.com/myrrlyn/bitvec/blob/master/src/pointer.rs
[`core::slice::from_raw_parts`]: https://doc.rust-lang.org/core/slice/fn.from_raw_parts.html
[`core::slice::from_raw_parts_mut`]: https://doc.rust-lang.org/core/slice/fn.from_raw_parts_mut.html
