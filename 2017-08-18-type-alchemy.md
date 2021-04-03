---
title: Type Alchemy
date: 2017-08-18
category: Type Theory
number: 3
tags:
- c
- rust
- software design
summary: >
  We regularly work with data whose size is not fixed or known ahead-of-time –
  text, especially C strings, are a prominent example of this – and manipulating
  it safely requires effort. Part of my work involves using streams of
  structured, unsized, data, with as little indirection and discontinuity as
  possible.
---

> Rust version at time of writing: 1.19
{:.bq-info role="complementary"}

## Introduction

The second draft of this article was 4,000 words long before I wrote the heading
“The Point of This Article, No Really I Mean It This Time” and that’s when I
decided maybe I should scrap it and start over. Third time’s the charm.

One of the primary concerns of my company’s engineering is in data serialization
and deserialization (henceforth <dfn>ser/des</dfn> for short). We also have some
significant concerns in the radio network that lets us talk to orbital hardware,
but ser/des is what makes that network useful. So we think about it a lot.

> Also, I know less than nothing about radio engineering, and am only lightly
> involved in the network. I am, however, both learned and tasked on ser/des.
{:role="complementary"}

Our spacecraft are usually flying software written in C or C++, or firmware
written in Verilog or VHDL, talking to ground sites running applications in C♯,
Java, Ruby, or one specific Rust program that I wrote. The correct ser/des of
messages between all of these languages is of paramount importance. Because it’s
a polyglot environment, we can’t just use Python’s `pickle` or Ruby’s `Marshal`
or C’s “obtain a pointer to the struct, cast it to `unsigned char*`, ship it” or
any such language-specific ser/des mechanism.

So we have standardized grammars for message description formats, such as
[COSMOS][1]’ [command and telemetry format][2], which describe the meaning and
patterns for a sequence of bytes, and it is up to everyone on the network to
appropriately implement ser/des between native types and these byte sequences.

C has a fairly simple, though not necessarily easy, job of this. For any given
COSMOS block definition, create a struct that matches it (where possible given
C’s limitations) and memmove and cast pointers.

Here is an example COSMOS block, taken (and scrubbed) from my current project.

```cosmos
TELEMETRY BLOG_POST FOO_TLM BIG_ENDIAN "I stripped the real names, obviously."
  APPEND_ITEM    LEN              16 UINT        "Packet Length"
  ## This is a magic number that is used for type-match. I'll cover it later.
  APPEND_ID_ITEM OPCODE           16 UINT 0xABCD "Packet Opcode"
  APPEND_ITEM    GPSW             16 UINT        "GPS Week"
  APPEND_ITEM    GPSM             32 UINT        "GPS Millisecond of week"
  APPEND_ITEM    FRT              64 UINT        "Free running timer"
  APPEND_ITEM    ResetCount       16 UINT        "Processor Reset Count"
  APPEND_ITEM    NetLogicalAddress 8 UINT        "Network Logical Address"
  ## This is also a magic typematch number.
  APPEND_ID_ITEM ProtocolId        8 UINT 0x42   "Network Protocol ID"
  APPEND_ITEM    AsciiData        -8 STRING      "Payload text buffer"
  ITEM           NetCrc         -8 8 UINT        "CRC"
```

The above block means “for a sequence of bytes with magic numbers in cells 2, 3,
and 21, interpret the first 22 bytes as these fields, the last bytes as this
other field, and everything from byte 22 to the penultimate as text.”

COSMOS provides Ruby code for building modules and classes from these
definitions, as well as ser/des methods. I do not know of similar libriaries in
other languages, though I am attempting to write one in Rust. That effort is
what motivates this post.

## Data Format

For various reasons not worth exploring here, we do not always write our message
layouts in ways optimally suited for ease of transmutation by C or Rust. The
above message is an example of this: it has an unsized type
(`AsciiData -8 STRING`) that is not at the tail end of the message, and the 4-
and 8- byte wide fields are not aligned for ease of access on the ground.

A C struct naïvely declared to match this description would be (a) illegal, due
to the non-terminal unsized array, and (b) incorrect, because the compiler would
insert holes that this serialized message format does not have.

So the simplest type transmutation, casting a pointer to this message as a
pointer to a matching struct, doesn’t work, and actual ser/des functions are
required.

It helps that we know, because it’s in the documentation, that the `LEN` field
of a `BLOG_POST FOO_TLM` message (henceforth <dfn>BPFT</dfn>) is the width of
the entire message (not the width of the `AsciiData` field) and we can use that
for bookkeeping.

### Example Type and Deserialization in C

Let’s get some basic C types down that we’ll then build on. We need an enum of
all messages in the project and a tagged-union to contain them, as well as a
struct definition of the BPFT type.

```c
enum Message {
  /* others */
  Message_BPFT,
  Message_NONE,
}
/* ... other struct definitions ... */
struct BlogPost_FooTlm {
  unsigned char* ascii_data;
  /* C integer types are terrible */
  unsigned long long frt;
  unsigned int gpsm;
  unsigned short len;
  unsigned short gpsw;
  unsigned short reset_count;
  unsigned char net_logical_address;
  unsigned char net_crc;
}
struct TypedMessage {
  enum Message ty;
  union {
    /* others */
    struct BlogPost_FooTlm bpft,
    void* none,
  } msg;
}
/* Blanks a TypedMessage struct to a safe NONE state */
void blank_typed_message(struct TypedMessage* self) {
  memset(&(self->msg), 0, sizeof(self->msg));
  self->ty = Message_NONE;
}
```

> Notice that the two fields `OPCODE` and `ProtocolId` aren’t in the C struct?
> They’re `ID_ITEM`s in COSMOS, which means they’re magic constants. We need to
> know them for sniffing packets, but they don’t need to be carried in the
> struct. They are *type-level integers*, not instance-level. I’ll get back to
> that.
{:.bq-safe .iso7010 .e011 role="complementary"}

My mission docs state that all 74 packet types have opcodes in the same place,
which makes first-level detection easier. Let’s see what a BPFT-specific
deserializer looks like, and a general function that reads from the network and
returns *some* deserialized message.

```c
/* Deserialize a packet into a BPFT structure */
int deser_bpft(unsigned char* pkt, struct BlogPost_FooTlm* out) {
  out->len = ntohs(*(unsigned short*)pkt);
  out->gpsw = ntohs(*(unsigned short*)&pkt[4]);
  out->gpsm = ntoh(*(unsigned int*)&pkt[6]);
  out->frt = ntohl(*(unsigned long long*)&pkt[10]);
  out->reset_count = ntohs(*(unsigned short*)&pkt[18]);
  out->net_logical_address = ntoh(*(unsigned char*)&pkt[20]);
  out->ascii_data = malloc(out->len - 23);
  if (out->ascii_data == NULL) {
    return -1;
  }
  memmove(out->ascii_data, &pkt[22], out->len - 23);
  out->net_crc = pkt[out->len - 1];
  return 0;
}
/* Deserialize a packet into _some_ structure */
struct TypedMessage deser(unsigned char* pkt, int len) {
  /* Set up a return value */
  struct TypedMessage out;
  /* Early abort if needed */
  if (len < 4) {
    goto fail;
  }
  /* Switch on the globally known identifier position */
  switch ntohs(*(unsigned short*)&pkt[2]) {
  /* A message family */
  case 0xABCD:
    switch pkt[21] {
    /* BPFT specifically */
    case 0x42:
      /* Deserialize as BPFT into the return structure */
      if (deser_bpft(pkt, (void*)&(out.msg)) != 0) {
        goto fail;
      }
      /* Set the type flag */
      out.ty = Message_BPFT;
      goto exit;
    default:
      goto fail;
    }
  default:
    goto fail;
  }
fail:
  blank_typed_message(&out);
exit:
  return out;
}
```

This is *absolutely* error-prone C code. For one, all the dereferences as
multi-byte types are massively undefined behavior because there’s no guarantee
that their offsets in the packet are at valid alignments. That switch stack is
also extremely brittle. This is for a blog post, not a deliverable; I don’t
write like this in real life and neither should you.

Let me break down what’s happening here:

1. The `deser` function is called on a packet freshly received from the network
   layer. It has had all its transport wrappings removed, has been recombined if
   needed, and should look like one of the 74 message types declared in this
   project. This function looks at bytes 2 and 3 as a single 16-bit value and
   compares against known magic numbers.

   > If you haven’t read my previous type posts, let me explain what the weird
   > `ntoh(…)` snippets are doing.
   >
   > 1. We need to get the address of the start of a field, here `LEN`. This is
   >    done by taking `&pkt[2]` because `LEN` starts at byte 2, counting from
   >    0.
   > 1. We need to tell the computer that the value at this address is two
   >    bytes wide. We do this by saying that the address, is the address of an
   >    `unsigned short`. This is the `(unsigned short*)` prefix of `&pkt[2]`.
   > 1. We need to tell the computer, take this address of an unsigned short
   >    and read its contents. This is the `*` in front of everything from
   >    above.
   > 1. We then need to tell the computer “by the way, that unsigned short you
   >    just read? It is in big-endian, or network order. If you’re a
   >    little-endian CPU, flip those bytes.” This is the `ntohs()` function
   >    call wrapping everything.
   {:.bq-warn .iso7010 .w011 role="complementary"}

1. If the discovered number is the magic number indicating one of a family of
   telemetry messages, we enter into another block to finish determining type.
   This means inspecting byte 21 and branching on its value. If it is the magic
   number of a BPFT, we deserialize and return a tagged union over all message
   struct types.

1. To deserialize a BPFT, we have to do the previously-described transformations
   of the data stream on every field (except the magic indicators), and also
   allocate an array elsewhere on the heap to store the string. We can’t store
   it inline, because C doesn’t allow non-final variable-width struct fields.

1. The caller of `deser()` can inspect the `.ty` field of the returned struct to
   determine what kind of structure was returned, and then access the struct
   with `.msg.bpft.ascii_data` or other field names.

### Lessons From the Example

This example code should illustrate a couple issues with the C type and logic
systems, bad code smells notwithstanding.

First of all, C has no concept of type parameters, so it can only presume types
have either totally known, constant, sizes, or absolutely unknown sizes for
which it punts responsibility to the programmer.

Secondly, C has no awareness of field coupling, and only limited awareness of
collection widths. Given compile-time-constant arrays (but not strings), the C
compiler can provide information about their widths, but it lacks the ability to
provide this behavior at runtime. Furthermore, the relationship between fields
(such as the number in `LEN` and the actual size of a message sequence) is
unknown to, and thus unenforced by, the compiler, and so relies on good behavior
from the programmer and every component in the system.

These are both cases that Rust is in a position to address, and has much of the
groundwork laid to do so.

## Rust’s Current Type System

At present, Rust *kind of* has fields integrated into type knowledge; for
example, its slice type is a <dfn>wide pointer</dfn> that looks like this:

```rust
pub struct SliceRef<T> {
  ptr: *const T,
  len: usize,
}
```

and anytime a slice is generated from a collection, the `len` parameter is
bound to the instance and the compiler is able to make intelligent optimizations
about staying within the slice length and not breaking out of logically correct
memory. As I understand it, this compiler awareness does not extend to other
types. This means that, for example, we cannot yet create a Rust struct that
would read a BPFT serialized byte sequence and know within the type system how
to build a safe, correct, BPFT struct out of it.

Rust, like C, shares the limitation that variable-width types must be last in a
struct, and cause the entire struct to become unsized (or in Rust, `!Sized`) and
unable to be used as a direct value.

There is one particular area where C++ has features up to which Rust needs to
catch: type-level integers. Rust does not have these, though there are [RFCs in
progress][3] to add these to the type system. Once these RFCs land, we will be
able to solve the problem of non-tailing unsized types and, I hope, uncoupled
fields. For the rest this article, I will be using Rust syntax that assumes type
level integers have landed according to the linked RFCs.

> Const generics began stabilizing in Rust 1.51. They are not yet able to
> perform type-level computation, but this work is also in progress.
{:.bq-safe .iso7010 .e004 role="complementary"}

## Solving Unsized Types

The message description specification for my project, as for all data formats,
includes a means of determining the finite size of the item. C strings are the
most prominent exception to this rule, which do not carry length out of band but
rather use a special marker value in the stream to signal termination.

> Null-terminated strings and null pointers are the two most catastrophic
> failures of computing theory. At least Tony Hoare had the grace to apologize
> for his sin; Dennis Ritchie (an otherwise truly impeccable pioneer in the
> field) did not.
>
> > Yes, Rust fixes both of these mistakes.
> {:.bq-safe role="complementary"}
{:.bq-info .iso7010 .m011 role="complementary"}

We know that for all message formats that carry their own length information as
a field, there is a finite range of possible sizes, because integers in the
computer science sense of the word are finitely ranged. For the BPFT message I
laid out above, the total length of the message must be no greater than `0xFFFF`
as that is the maximum value an unsigned 16-bit integer can hold.

We also know, from the fields contained in a BPFT message, that its minimum size
is 23 bytes: the sum of the widths of all fields other than the `AsciiData`,
which can have zero bytes to itself (as evidenced by the fact that it begins at
bit offset `-8`, and the `NetCrc` field ALSO begins at bit offset `-8`).

This means that, for the definition of the BPFT message, there are 65,512
possible versions of the BPFT struct that can exist and have concretely known
sizes.

Since writing out sixty-five thousand variants of the same type declaration is
*stupid*, we will instead use the forthcoming type-level integer feature of
Rust’s type system to do the same thing we currently do with type-level types:
make a BPFT type family, that is monomorphized at runtime, just as Rust traits
currently do.

### Generically-Sized Types

```rust
pub struct BlogPost_FooTlm<const N>
where N: u16,
//  the proposed `with` keyword is
//  equivalent to `where` but for math,
//  rather than type logic
with N >= 23,
{
  ascii_data: Box<[u8; N - 23]>,
  frt: u64,
  gpsm: u32,
  len: N,
  gpsw: u16,
  reset_count: u16,
  net_logical_address: u8,
  net_crc: u8,
}
```

In this declaration, I specify that the type family `BlogPost_FooTlm` is
generic over possible values of a constant called `N`, and then specify that `N`
must have the type `u16` and the value constraints `>= 23`. I then state that
the field `len` is an instance of this type parameter. I also state that the
field `ascii_data` is a pointer to an array of bytes allocated somewhere else
that is of a length directly coupled to the type parameter `N`.

The compiler is now aware that the concrete type instance of a BPFT is linked to
the value of one of its fields.

However, this still mirrors my C struct above, and does NOT mirror the field
layout of the `BLOG_POST FOO_TLM` message when serialized as bytes. This means
that transmuting between the in-memory struct and the serialized byte sequence
requires implementing semi-complex functions akin to my C `deser_bpft` function
above.

I’m not going to implement them in Rust. You already saw the gist of the logic
above, and nothing’s changed. Instead, I’m going to showcase an extension of
previously unsafe and/or impossible behavior that type-level integers can make
possible and safe.

### Safed Superpowers: Zero-Cost Transmutation

Let’s first of all declare a Rust structure that exactly mirrors the COSMOS
description text. Thanks to type-level integers, the `ascii_data` field is no
longer unsized, and so we can have it in a non-tailing position.

> Ordinarily `#[repr(packed)]` is a Very Bad Idea, but this particular case is
> the only instance I can imagine where it is not only a good idea but a
> required one.
>
> In the future, my team should design the message layouts such that the
> pitfalls of fully packed structs are not a worry.
{:.bq-harm .iso7010 .p015 role="complementary"}

```rust
#[repr(packed)]
pub struct BlogPost_FooTlm<const N>
where N: u16,
with N >= 23,
{
  len: N,
  opcode: u16,
  gpsw: u16,
  gpsm: u32,
  frt: u64,
  reset_count: u16,
  net_logical_address: u8,
  protocol_id: u8,
  ascii_data: [u8; N - 23],
  net_crc: u8,
}
```

We now have a family of BPFT structures that exactly mirror the BPFT description
text. Note that the `OPCODE` and `ProtocolId` fields have made a comeback.

The end result of all this work in Rust’s type system is that we can go back to
using C-style programming, but safely:

```rust
use std::convert::{From, Into};

impl From<[u8; N as usize]> for BlogPost_FooTlm<N>
where N: u16,
with N >= 23,
{
  fn from(mut src: [u8; N as usize]) -> Self<N> {
    let mut out = unsafe { std::mem::transmute(src) };
    out.from_be();
    out
  }
}

impl Into<[u8; N as usize]> for BlogPost_FooTlm<N>
where N: u16,
with N >= 23,
{
  fn into(mut self) -> [u8; N as usize] {
    self.to_be();
    unsafe { std::mem::transmute(self) }
  }
}
```

That’s it. The only thing these functions do is inform the type checker that
the byte sequence in memory that used to be one type, are now another type, and
because the type parameter is encoded in a known position in the byte sequence,
the compiler is able to generate code that will handle all this correctly,
safely, and completely transparently to the programmer.

> <del>
> For the sake of brevity, we will briefly pretend that there exists a Rust
> trait that defines `from_be` and `to_be` methods that flip bytes around as
> appropriate, and I implemented it on this type to flip each field between
> network (big) and native (little) endianness. The devil’s in the details.
> </del>
>
> <del>
> These methods exist on primitives, but not as a trait that can be implemented
> on structs.
> </del>
>
> <ins>I wrote [Lilliput](/lilliput) to solve exactly this problem.</ins>
>
{:.bq-safe .iso7010 .e016 role="complementary"}

### Handling Concrete-Type Explosions

However, this requires a great deal of work to take place at runtime, and unlike
with standard type generics where all types are known and planned at compile
time, the compiler must not emit sixty-five thousand versions of the struct and
functions to handle it.

The solution to *this* problem is already partially solved with Rust’s trait
system, and will be further solved when the [`impl Trait` RFC][4] lands.

> Update: `impl Trait` landed in 1.26, and has nothing to do with return value
> elision; this was incorrect speculation on my part.
{:.bq-safe role="complementary"}

Rust is very good at recognizing large structures and rewriting things behind
the scenes to use pointers instead of values, so that functions manipulating
large types can work without having to perform lots of redundant copies and
moves. This intelligence will need to be brought to bear for integer-typed
families like BPFT. Rather than making a slew of similar functions and structs
with individual variants of the type family, Rust will simply state that types
are a member of the BPFT or other family, and rely on its deep knowledge of how
BPFT and similar types are constructed to handle runtime-only behavior.

```rust
impl<const N> BlogPost_FooTlm<N>
where N: u16,
with N >= 23,
{
  pub fn extract_ascii_data(self) -> [u8; N - 23] {
    self.ascii_data
  }
}
```

Rust does not need to construct a slew of these functions and choose between
them based on inspection of `self.len` at runtime; it will instead rewrite this
function to consume and return pointers to memory.

If Rust is able to make intelligent optimiziation choices, which it often is, it
may likely simply cause this function to evaporate, and replace it with compile
time knowledge that calling it will free 22 bytes before the array and one byte
after it, and open up these memory locations for use elsewhere. It may also do
nothing, and merely forbid access to the now-logically-destroyed fields until
such time as it can free the entire memory block formerly owned by the BPFT
instance.

## Sentinel Values in Type Declarations

So, types that can be generic over integer values will have solved one of my two
problems discovered in the course of my work. What about the other, that I have
so far barely acknowledged?

In order to deserialize an arbitrary byte stream into well-formed, typed,
structured, data, the code acting upon it must be able to find a way of
deciding which type to generate. The COSMOS declaration text provides these
markers with `ID_ITEM` fields, as I have mentioned, and the parsing code can
look for these magic numbers in their magic positions to determine if a byte
sequence represents a valid instance of a declared type.

Rust has good support for matching patterns based on what data “looks like” when
matching on values already of a known good type, like this:

```rust
#[derive(Debug)]
struct Foobar {
  a: i32,
  b: i32,
}

let f: foobar = Foobar { a: 1, b: 2 };
match f {
  Foobar { a, b: 1 } => println!("Found a Foobar with a/{} and b/1", a),
  Foobar { a: 1, b } => println!("Found a Foobar with a/1 and b/{}", b),
  m @ Foobar { .. } => println!("Found a {:?}", m),
}
```

This code will run the middle arm, as `f` matches the pattern given (a `Foobar`
with its `a` field equal to `1`).

The final arm just says “if the given value is a `Foobar`, give me a handle to
the entire thing at the symbol `m`; don’t destructure into inner fields at all.”

This is the foundation of what I want to accomplish when inspecting `[u8]`
streams for the type into which they should be deserialized. Rust currently does
not offer a way to accomplish this in the type system; it must be done like we
did in C: read from a known location in the stream and match on it:

```rust
enum Message {
  BPFT(Box<BlogPost_FooTlm>),
  None,
}
fn deser(pkt: &[u8]) -> Message {
  use Message::*;
  let opcode = NetworkEndian::read_u16(&src[2 .. 4]);
  match opcode {
    0xCDAB => {
      let proto_id = src[21];
      match proto_id {
        case 0x42 => BPFT(box src.into()),
        _ => None,
      }
    }
    _ => None,
  }
}
```

What if, since we defined our message struct types to be byte-equivalent to the
`[u8]` byte streams that are their serialized form, we could just test if the
packet byte stream fits in a type? This is an extension of type-level integers
that I’m not sure I’ve yet seen, so I’m treating it as a separate offshoot.

### Magic Constants

> <ins>UPDATE: Struct constants landed in Rust 1.20</ins>
{:.bq-safe role="complementary"}

I’m going to redefine BPFT yet again, getting even further from valid Rust.

```rust
#[repr(packed)]
pub struct BlogPost_FooTlm<N>
where N: u16,
with N >= 23,
{
  len: N,
  //  Keep this flip in mind
  const opcode: u16 = 0xCDAB,
  gpsw: u16,
  gpsm: u32,
  frt: u64,
  reset_count: u16,
  net_logical_address: u8,
  const protocol_id: u8 = 0x42,
  ascii_data: [u8; N - 23],
  net_crc: u8,
}
```

> <ins>
> Rust 1.28 expects to make the endian conversion functions, among others,
> `const` so they can be used on literals in `const` context. When this lands,
> the above can be written as `0xABCD.to_be()`.
> </ins>
{:.bq-safe role="complementary"}

This declares that not only is there a type family of BPFT structures dependent
on values of `len`, but that it is *illegal* for BPFT instances to exist whose
`opcode` and `protocol_id` fields are anything but the stated values. This could
have been done by adding additional type parameters

```rust
pub struct BlogPost_FooTlm_Extra<N, O, P>
where N: u16, O: u16, P: u8,
with N >= 23, O == 0xABCD, P == 0x42,
{ .. }
```

but, in my opinion, that adds lots of extraneous syntax noise and ugliness.
Besides, I’m of the opinion that these magic constants are describing a pattern
of the type, rather than a logic of it. Coupling the value of `len` to the type
information of the struct is a logical decision that determines which particular
variant of BPFT is chosen as the type, while the value of opcode determines if
a byte sequence can even fit in a BPFT pattern. I see those as two separate
concerns, even though they are both built upon type-level integers.

So suppose we had Rust syntax that supported assigning magic constants to fields
in the manner I just described. We could then, possibly, extend that as follows
for deserialization:

```rust
fn deser<O, const N>(src: [u8; N]) -> Result<Box<O>, &'static str>
where N: usize, O: As<[u8; N]>
{
  match src {
    bpft @ BlogPost_FooTlm<N> { .. } => Ok(box bpft.from_be()),
    _ => Err("Invalid byte sequence"),
  }
}
```

This dummy example assumes a currently non-existent trait called `As` that is
simply a marker for “calling `std::mem::transmute` between these two types is
safe and logically valid.”

See up above where I said the magic constant for `BPFT.opcode` was not `0xABCD`?
The pattern matcher cannot mutate the source field in any way during inspection,
as this has the possibility to invalidate not only future checks but past checks
also. This means that the matcher has to attempt to compare the source bytes
against the pattern of destination type bytes (here, check if `[2 .. 4]` match
`[0xAB, 0xCD]` and `[21]` matches`[0x42]`) without altering the source, and it
is nonsensical to call `to_be()` on a *type*, rather than an instance. Extending
Rust’s grammar far enough to be able to call manipulator functions on a type
with magic constant is, even in my opinion, too much to ask.

So this function would check at compile time if all left hand patterns were
types that could be represented as `[u8; N]` with a simple transmutation, no
computation or alteration of any kind, and then create code to check the correct
bytes of the source data with the correct bytes of the target pattern. It’s
basically just an implementation of my C switch stack far far above, but done in
the type system rather than by manually inspecting numbers.

If a match occurs, we enter the appropriate arm with a binding to the source
data as if we had called `transmute()` on the source data. Since the message
bytes are in network endian but this is almost assuredly happening on a little
endian machine, we then call `.from_be()` on the binding, which invokes the
type’s correct endian converter, and returns the now-altered result.

## Ending

I’m at 4,000 words again, so rather than my planned conclusion of “reasons this
would be useful to anyone other than me,” I’ll just end here. I’ll build on this
article more in the future, I’m sure.

I recognize that everything I just wrote is entirely the result of one person
spitballing from one particular problem, and is very far from being ready to
write into a proper RFC, much less adding to the compiler. However, if any of
this sounds interesting to you, I’d love to hash this out and refine it into a
better, more general form that might one day land.

## TL;DR

I want `std::mem::transmute()` to be type-safe and give Rust programs run-time
type inference that is statically known to be logically sound.

And also be competitive in speed and behavior with manually tuned C code.

Yeah.

[1]: http://cosmosrb.com
[2]: http://cosmosrb.com/docs/cmdtlm/
[3]: https://github.com/rust-lang/rfcs/issues/1930
[4]: https://github.com/rust-lang/rfcs/issues/1522
