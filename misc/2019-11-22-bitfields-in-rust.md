---
title: Bitfields in Rust
date: 2019-11-22
tags:
- programming
- rust
summary: |
  A walkthrough of the recent bitfield behavior I implemented in `bitvec`
---

> This article is significantly out of date. I made a lot of changes to `bitvec`
> in 2020, many, ironically, shortly after publishing this. I will rewrite it
> soon; in the meantime, it is still correct in the general case but
> occasionally very wrong in the specifics.
{:.bq-warn .iso7010 .w001}

Rust version: 1.36. `bitvec` version: 0.16.

If you don’t care about bit collections in other languages, use the table of
contents to jump ahead.

I am the author of a Rust library called [`bitvec`]. This is the most powerful
memory manipulation crate in the Rust ecosystem and, to my knowledge, the world.

Almost every language that is used in the “systems programming” domain has some
form of capability, either in the language itself or in a specialized library,
for manipulating memory as sequences of raw bits, rather than of typed values.

> Other languages with bit-level memory control include:
>
> | Language | Implementation                                                    |
> |:---------|:------------------------------------------------------------------|
> | C        | [bitfields][bitfield_c]                                           |
> | C++      | [bitfields][bitfield_cpp], [`std::bitset`], [`std::vector<bool>`] |
> | D        | [`std.bitmanip`]                                                  |
> | Erlang   | [`bitstring`][bitstring_erl]                                      |
> | JVM      | [`BitSet`]                                                        |
> | .NET     | [`BitArray`]                                                      |
> | ObjC     | [`CFMutableBitVector`]                                            |
> | Python   | [`bitstring`][bitstring_py]                                       |
> | Ruby[^1] | defines [`Integer#​[]`](https://ruby-doc.org/core-2.6.5/Integer.html#method-i-5B-5D) (read), but not `Integer#[]=` (write) |
>
> The [Wikipedia article] has more information, as well.
{:.bq-info role="complementary"}

<!-- Due to a bug in the Markdown parser I use, the Ruby link must (a) have a
zero-width space between the `#` and the `[`, but also (b) must use direct-link
syntax and cannot use reference-link syntax. -->

The specific implementations in each language are largely overlapping, with some
advantages and disadvantages for each, but they are all largely similar to each
other. They all define a single, fixed, ordering of bits in a memory element;
most of them do not permit users to specify the type of memory element in use to
aggregate bits in memory, and only a few (C and C++ bitfields, Erlang
bitstrings) permit users to treat an arbitrary bit region as a value location
where you can write or read typed numeric data against it.

`bitvec` can do all of the things I just said other languages can’t.

Enough about everyone else. Let’s talk about me.

# Creating bitfields with `bitvec`

In order to cook an apple pie, you must first create the universe, and in order
for me to explain something, I must first deliver a CS101 lecture.

This section is the CS102.

## Treat some memory as bits

In order to have a region of memory we can use as bitfields, we must first
allocate a region of memory, either on the heap, or the stack, or in the static
section.

```rust
use bitvec::prelude::*;

let mut stack_raw = [0u16; 4];
let stack_bits = stack_raw.bits_mut::<BigEndian>();

let mut heap = BitVec::<Local, Word>::with_capacity(64);

static mut STATIC_RAW: [u32; 2] = [0; 2];
let static_bits = unsafe {
    STATIC_RAW.bits_mut::<LittleEndian>()
};
```

> None of these type names exist anymore. `Local` is `LocalBits`, `BigEndian`
> and `LittleEndian` are `Msb0` and `Lsb0`, and `Word` is just `usize`.
{:.bq-warn .iso7010 .w001 role="complementary"}

We now have 64 mutable, contiguous, bits in each of the local stack frame, the
heap, and the static memory segment. It doesn’t matter where they are; the main
working type of this crate is the `&/mut BitSlice<C, T>` reference, which
applies equally to them all.

Notice that each of those three allocations uses a different Rust fundamental:
`u16` on the stack, `Word` on the heap, and `u32` in static. `bitvec` allows you
to use the unsigned integer types that correspond to register widths in your CPU
as storage types: `u8`, `u16`, `u32`, and (only on 64-bit-word processors)
`u64`. The `Word` type aliases to your local `usize`[^2].

> Now it’s just `usize`.
{:.bq-warn}

You may also notice that each of the three allocations uses a different first
type parameter. The first type parameter is an implementation of the `Cursor`
trait. The `LittleEndian` type means “counts from the least significant bit
first to the most significant bit last”, and the `BigEndian` type means “counts
from the most significant bit first to the least significant bit last”, in
whatever integer type the slice is using as its group size. The `Local` type
aliases to `LittleEndian` on little-endian byte-order architectures, and
`BigEndian` on big-endian byte-order architectures.

> I really must emphasize that the `LittleEndian` and `BigEndian` types in this
> library are **bit orders** and are **completely independent** from byte
> orders! This is a source of a fair bit of confusion, and requires a big clunky
> table which I will not reproduce here to explain. I picked this behavior as a
> convenience for people who look at core dumps of memory. Do not read more into
> it than that!

Other languages restrict you from one and/or both of these options. This is
unfortunate, because as it turns out, there is not a universal convention for
these among all I/O protocols.

## Choose a region of contiguous bit *indices* within that memory

I emphasized the word *indices* in that heading, because `bitvec` **does not**
expose bit positions in memory to you. The two type parameters in all of the
data structures the library exposes map from abstract unsigned integers into the
actual shift-and-mask procedures used to access memory. Pick the combination
that works for you, and then forget all about memory, and just pretend that the
memory in a slice is a one-dimensional sequence of individual bits, starting at
`[0]`.

`BitSlice` has absolutely no restrictions on where in memory you start or end a
region (except for bounds checks, which it strictly enforces). We have 64 bits
available. Grab any start and end number you want. I’m going to roll some dice
offscreen:

- 27
- 13

`bitvec` currently requires that ranges are strictly in the increasing
direction, from lower numbers to higher[^3], which means that we are interested
in the memory range `[13 .. 27]`. That’s 14 bits. `bitvec` disallows storing a
type whose bit width is smaller than a region, so we can’t store `u8` in it, but
`u16`, `u32`, and `u64` are all fair game.

## Put some data in that region

```rust
stack_bits [13 .. 27].store(0x3123u16);
heap       [13 .. 27].store(0x0000_3456u32);
static_bits[13 .. 27].store(0x00000000_0000_3789u64);
```

That’s it. That’s the whole API.

Truncation is from the most-significant-bit downward. For an `n`-bit region, the
`n` least significant bits of the value are transferred into or out of the bit
slice. This means that the highest two bits of a `u16` are discarded in a 14-bit
region.

This is why the first non-zero digit in the numbers above is `3`: anything
higher would get truncated, and will not be written into the region.

## Pull that data back out

```rust
let s: u16 = stack_bits [13 .. 27].load().unwrap();
let m: u32 = heap       [13 .. 27].load().unwrap();
let l: u64 = static_bits[13 .. 27].load().unwrap();
```

The `load` method returns an `Option`, because I elected to be calm rather than
panicky when presented with a `BitSlice` of length `0` or more than the type
being returned.

```rust
assert!(stack_bits[13 .. 27].load::<u8>().is_none());
```

The region has 14 bits available; a `u8` can’t fill them when `store`ing or
receive them when `load`ing. `store` exits without effect, `load` returns
`None`.

I’m not going to demean myself by posting an uncompiled example here to show
that the `s`, `m`, and `l` values all match exactly what we put in. They do.[^4]

# More than just variable-width data storage

So `bitvec` can compress data storage. If you know you have a number that will
never surpass `1023`, you can treat it as a `u16` when holding it and pack it
into a `u10` when storing it. That doesn’t impress you; C can do that:

```c
struct three_tens {
  uint16_t eins : 10;
  uint16_t zwei : 10;
  uint16_t drei : 10;
  uint16_t _pad : 2;
};
```

and so can Erlang:

```erlang
three_tens = <<
  eins:10,
  zwei:10,
  drei:10,
  _pad:2
>>
```

This is the part where I remind you that C can’t store `u16`s in a byte array,
or in a word array, only in a `u16` array. That struct is two `u16`s. Also, you
don’t get to choose the storage order. It’s from the LSbit on little-endian
architectures and from the MSbit on big-endian[^5].

I have absolutely no idea what the backing memory of Erlang bitstrings is, or of
any other language that has this functionality.

Compacted machine memory isn’t cool. You know what’s cool?

Declaring the layout of an I/O protocol in your type system.

## I/O Packet Destructuring

Let’s pick an example out of thin air, like, for instance, an [IPv4 packet].

How would we use `BitSlice` to describe memory we know contains it?

```rust
type Ipv4Pkt = BitSlice<(/* ??? */), (/* ??? */)>;
```

According to the Wikipedia table I linked above, the IPv4 packet uses 32-bit
words as its logical stride, so that’s a guess as to the backing element type.

Let’s skip the exploration and I’ll tell you why `BitSlice<_, u32>` is the wrong
answer: the kernel I/O interface gives you a sequence of `u8`, and does not
promise that they’re aligned to the 4-byte step that `u32` requires. Also, the
bytes are in network order (big-endian) and your CPU is probably little-endian,
so casting the bytes as `u32` is not only undefined behavior, but also gives you
the wrong numeric values.

The IPv4 table explains that it is enumerated in MSB-0 order, so,
most-significant bit on the left. This means that the packet uses the
`<BigEndian, u8>` type parameters[^6]:

```rust
type Ipv4Pkt = BitSlice<BigEndian, u8>;
```

Let’s pretend that our program has just received a raw socket buffer from the
operating sysetm, and parse it as IPv4. To start, we’ll grab the IHL field, as
that holds a dynamic partition point between the IPv4 header and payload:

```rust
let bytes: &[u8] = recv();
let bits: Ipv4Pkt = bytes.bits();

let ihl = bits[4 .. 8].load::<u8>() as usize;
if ihl < 5 {
  return Err(InvalidIhl);
}
let split = ihl * 32;

let (ipv4_hdr, payload) = bits.split_at(split);
```

We can do the same behavior for most of the other fields of the packet: look up
their range in the protocol, then call `.load()` with the appropriate type on
that range.

There is one field in the IPv4 header that stymies this approach, and I’ll cover
it now: Fragment Offset.

## Byte Endianness Gotchas

Fragment Offset is in word `[1]`, bits `[19 .. 32]`. This translates to bits
`[51 .. 64]` of the bit slice. Note that, in the protocol diagram, bits
`[51 .. 56]` are in byte `[6]`, and bits `[56 .. 64]` are in byte `[7]`. As I
mentioned above, the bytes are in big-endian order as `u32`, which means byte
`[6]` is *more* significant than byte `[7]`.

However, your processor almost certainly uses little-endian byte ordering, and
`bitvec` respects this. The implementation of `load` means that it will take the
five bits in byte `[6]` and treat them as the five least significant bits of the
field, then load the eight bits of byte `[7]` as more significant than them in
the produced `u16` value.

This is not what the IPv4 protocol wants. The five bits of byte `[6]` are the
*most* significant bits of the value, and the eight bits of byte `[7]` are the
*least* significant bits.

Writing this article made me realize I need to add specific methods for
correctly processing big- and little- endian memory, independently of the local
machine architecture. At the time that I publish this, I have not done so; I
will update this article once I do.

So you have to do the endian switch yourself, sorry:

```rust
let mut bytes = [0u8; 2];
bytes[0] = bits[51 .. 56].load().unwrap();
bytes[1] = bits[56 .. 64].load().unwrap();
let fragment_offset = u16::from_be_bytes(bytes);
```

In the future, `.load_be()` will interpret the memory as big-endian, and
`.load_le()` will interpret it as little-endian.

## Building a Bitfield Struct

Rust does not have bitfield syntax. `bitvec` does not provide this; it is purely
a library, not a syntax extension. This means that access to bitfields in a
struct, such as for a protocal packet or matching a C type API, requires using
methods, rather than fields.

For a C structure such as this:

```c
struct SixFlags {
  uint16_t eins : 3;
  uint16_t zwei : 2;
  uint16_t drei : 3;
  uint16_t vier : 3;
  uint16_t funf : 2;
  uint16_t seis : 3;
};
```

> “six” in German is “sechs”, which is too many letters.

You might write a corresponding Rust structure like this:

```rust
type SixFlagsBits = BitSlice<Local, u16>;

#[repr(C)]
#[derive(Copy, Clone, Default)]
pub struct SixFlags {
  inner: u16,
};

impl SixFlags {
  pub fn eins(&self) -> &SixFlagsBits {
    &self.inner.bits()[0 .. 3]
  }

  pub fn eins_mut(&mut self) -> &mut SixFlagsBits {
    &mut self.inner.bits()[0 .. 3]
  }

  pub fn zwei(&self) -> &SixFlagsBits {
    &self.inner.bits()[3 .. 5]
  }

  pub fn zwei_mut(&mut self) -> &mut SixFlagsBits {
    &mut self.inner.bits()[3 .. 5]
  }

  //  you get the idea…
}
```

Filling out such a structure in Rust:

```rust
let mut flags = SixFlags::default();
flags.eins_mut().store(2u8);
flags.zwei_mut().store(0u8);
flags.drei_mut().store(4u8);
flags.vier_mut().store(5u8);
flags.funf_mut().store(1u8);
flags.seis_mut().store(7u8);
```

is guaranteed to be binary-compatible with its equivalent C structure:

```c
struct SixFlags flags = get_from_rust();
flags.eins; // 2
flags.zwei; // 0
//  …etc
```

whenever you use the `Local` ordering, and match your interior layout to the C
ABI with `#[repr(C)]` and faithful transcription of the memory types.

> I could, in theory, create a guard type which dereferences to a Rust
> fundamental and commits its value to a slice on `Drop`, just like I did with
> “mutable references to single bits” in [`BitMut`], I just haven’t yet. That
> would enable an API like:
>
> ```rust
> let val = *bits[start .. end].span::<u16>();
> *bits[start .. end].span_mut::<u16>() = 300;
> ```
>
> Which, now that I write it here, looks like it’s going on the to-do list. For
> `0.17`.
{:.bq-info}

<!-- -->

> I did.
{:.bq-safe}

# Summary

Rust has bitfields now. More flexible than C, about as capable as Erlang, though
without the language support, and miles beyond the sequence libraries in every
other language.

I fully intend for `bitvec` to be the universal Rust library for lowest-level
direct construction and interpretation of memory segments. If `bitvec` does not
work for you, please get in touch with me directly or [file an issue].

`bitvec` optimizes *fairly* well. The steps I’ve taken to implement the library
in a manner that fits in the existing Rust language and library pattern means it
has certain unavoidable performance costs that just have to be paid for a fully
capable bit-slice type. The assembly, even in `--release`, for a `.store()` call
is far larger than an equivalent hand-written shift-and-mask operation would be.

This non-zero-cost abstraction is due to the runtime computations that must be
done for correctness, and cannot yet be moved into the compiler. As the
compiler’s constant evaluator gets more powerful, it will be able to perform
ahead-of-time range computations on `BitSlice` handles, reducing the runtime
load on statically-known slice boundaries.

Personally, I am of the opinion that offloading shift/mask and split
computations to the machine in favor of *much* simpler source code is a
worthwhile trade. If you need to tighten a hot loop, `BitSlice` offers you
access to the raw memory elements, and you can drop down to directly-computed
shift/mask operations.

And if your processor can afford a hundred-instruction store function (whose
actual runtime will be significantly less; `load` and `store` branche *heavily*
based on runtime conditions of the slice, and must include code for all paths),
the comprehension gain in the source code – clear text, automatic bounds checks,
and idiomatic Rust patterns – is a benefit you do not want to miss.

# Footnotes

\[^1\]: Ruby’s `Integer` class is, in fact, implemented as a hybrid between an
`i31` and a bit-vector so that it can have arbitrary-sized integers with minimal
cost. No, you are *not* tricking me into explaining what an `i31` is in this
article. Footnotes don’t nest.

\[^2\]: For technical reasons, including but not limited to the fact that
`usize` is a discrete type and *not* an alias to `u32` or `u64`, `bitvec`
disallows `usize` as backing storage. I might remove this restriction later.

\[^3\]: I might change that in the future, but `std` has the same requirement,
so why get wild too soon? It would be pretty neat to have `[high .. low]`
provide reversed directionality, though.

\[^4\]: This is, of course, checked by the [test suite].

\[^5\]: Matching the (bad) behavior of existing C code is the other reason I
chose `<Local, Word>` as the default type parameter.

\[^6\]: `<BigEndian, u8>` used to be the default parameter choice in `bitvec`
types, as it appears to be a very common sequence type. I changed it since
`<Local, Word>` gives better performance for users who don’t care about layout,
and users who *do* care about layout will specify it.

[IPv4 packet]: https://en.wikipedia.org/wiki/IPv4#Packet_structure
[Wikipedia article]: https://en.wikipedia.org/wiki/Bit_array "Wikipedia: Bit array"
[bitfield_c]: https://en.cppreference.com/w/c/language/bit_field "CppReference: Bit fields"
[bitfield_cpp]: https://en.cppreference.com/w/cpp/language/bit_field "CppReference: Bit fields"
[bitstring_erl]: http://erlang.org/doc/programming_examples/bit_syntax.html "Erlang: Bit Syntax"
[bitstring_py]: https://pythonhosted.org/bitstring/ "PythonHosted: bitstring"
[file an issue]: https://github.com/myrrlyn/bitvec/issues/new "File a feature request or bug report"
[test suite]: https://github.com/myrrlyn/bitvec/blob/48a68c67d936912e25b693246f9f5211962d240b/src/fields.rs#L631-L725 "Test cases for bitfield behavior"
[`BitArray`]: https://docs.microsoft.com/en-us/dotnet/api/system.collections.bitarray "MSDN: BitArray"
[`BitMut`]: https://github.com/myrrlyn/bitvec/blob/48a68c67d936912e25b693246f9f5211962d240b/src/slice/guard.rs#L42-L71 "Proxy write reference to a single bit"
[`BitSet`]: https://docs.oracle.com/javase/10/docs/api/java/util/BitSet.html "Java: BitSet"
[`CFMutableBitVector`]: https://developer.apple.com/documentation/corefoundation/cfmutablebitvector-rqf#//apple_ref/doc/uid/20001500 "Apple Developer: CFMutableBitVector"
[`bitvec`]: /crates/bitvec "myrrlyn: bitvec"
[`std.bitmanip`]: https://dlang.org/phobos/std_bitmanip.html "D/Phobos: std.bitmanip"
[`std::bitset`]: https://en.cppreference.com/w/cpp/utility/bitset "CppReference: bitset"
[`std::vector<bool>`]: https://en.cppreference.com/w/cpp/container/vector_bool "CppReference: vector<bool>"
