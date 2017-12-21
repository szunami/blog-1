---
title: Data Types
date: 2017-03-14
tags:
- computers
- computing theory
- software design
category: Type Theory
number: 1
summary: >
  An exploration of how programs assign meaning to patterns of data, and the
  theories behind that behavior.
---

1. ToC
{:toc}

# Introduction

Computing is composed of two categories of information: instructions, and data.
If computers speak a language, instructons are verbs and adverbs, and data are
nouns and adjectives.

Computer science has a concept called *type theory* that extends from the
mathematical concept of *set theory*, which itself is a formal definition of the
natural thought process by which we categorize things into groups.

Humans can do this instinctively, and we can categorize even complicated objects
by one or more attributes. Imagine a collection of toys, which are all various
colors, shapes, and textures. We can arbitrarily sort and separate those toys by
any or all of their categories with ease. It helps that the attributes I
described were all clearly distinct and could be measured by different senses:
color perception is purely sight, texture is purely touch, and geometry is a
mixture of the two that also requires complex calculation.

Computers only have one sense, though: voltage level. So for them, determining
data type is more complex.

In mathematics, where everything is abstract and unreal, set theory describes a
rule set by which we can describe and categorize arbitrary elements in arbitrary
ways. The classic example of this is the Venn Diagram, a visual depiction of two
sets $$A$$ and $$B$$ (the circles) inside a universe $$U$$ (the area in which
the diagram is drawn). These sets are given names, and items which satisfy
membership in none, one, or both are placed accordingly. Things that are in
neither $$A$$ nor $$B$$ go outside the circles, things that are either in $$A$$
or in $$B$$ go in the outer area of their respective circle, and things that are
both in $$A$$ and in $$B$$ go in the intersection in the middle.

<aside markdown="block">
Incidentally, this maps well to Boolean logic. The [Venn Diagram][1] of two
intersecting circles in a universe is equivalent to the [Karnaugh Map][2] of two
binary variables. The diagram below has a K-map on the left and a Venn diagram
(which is harder to draw in text than one might think) on the right.

~~~text
   ┌─┬─┐    ┌─────────────────┐
 A │1│3│    │   ┌───┮━━━┭───┐ │
   ├─┼─┤    │ 0 │ 1 │ 3 │ 2 │ │
¬A │0│2│    │   └───┶━━━┵───┘ │
   └─┴─┘    └─────────────────┘
   ¬B B
~~~

Cell 0 is full of elements which are neither `A` nor `B`, but are in the
universe `U`. Cell 1 is full of elements which are `A` but are not `B`: the
outer section of one of the two circles. Cell 2, `B` but not `A`, is the other
circle. Cell 3 is the intersection, filled with elements that are both `A` and
`B`.

The group of cells 1, 2, and 3 holds all elements that are in either `A` or `B`,
and relates to Boolean OR. In mathematics, this is called the union operator:
$$A \cup B$$. Cells 1 and 2 hold elements that are `A` or `B` but not in both,
and relate to Boolean XOR. This is called the disjoint union or symmetric union:
$$A \Delta B$$. Cell 3 alone is composed of items that are both `A` and `B`, and
relates to Boolean AND. This is also called the intersection: $$A \cap B$$.
</aside>

# Set Theory in Programming

In mathematics, we have freer room to say what elements belong to what sets
because we have an infinite symbol space that need never collide. This is untrue
for computers, where we have finite symbol space that collides often, and so we
must be able to distinguish between symbols *somehow*. Consider a single byte:
`0b1010_0101` (also written `0xA5`).

What does this byte mean?

It depends on context.

If we are treating it as an unsigned integer, it is a representation of the
number 165. If we are treating it as a signed integer, it is a representation of
the number -91. If we assume it is a piece of text, it gets even stranger. It’s
not valid ASCII, and in UTF-8 it is a continuation byte of a longer character
sequence. It could also be an index into memory that informs us where the data
we *really* seek can be found.

It’s impossible to tell purely by inspection, because bits are bits and carry no
meta information. To describe bits, we encode that information in yet more bits,
and anyone looking at the system has to agree to abide by arbitrary rules about
interpreting meaning. Some examples of these arbitrary rules are text encodings
such as ASCII, UTF-8, or the myriad other standards, memory models (also known
as Application Binary Interface, or ABI for short), or transmission protocols
used to operate communication lines like Ethernet, telephone, serial, or more.

# Data Types

As I briefly touched on above, computing has a concept of *data types* that
governs how bits are interpreted. All programming languages have some kind of
type system that determines how data is interpreted. In some languages, the type
of a variable is just a number that lives alongside the variable data itself,
whereas in some others the type is known by the compiler and does not need to be
visible at runtime if the compiler knows it has arranged the code in such a way
as to not need it.

Scripting languages such as Python and Ruby are often dynamically typed, where
the type of data is stored alongside the data, while compiled languages such as
C and Rust are more often statically typed, where data types are tied to points
in the instruction stream, and data that doesn’t match expectations causes
problems to arise. Both methods have pros and cons, which I do not plan to
discuss here.

Let us imagine a 32-bit integer in C. The exact value doesn’t matter, so we’ll
say it is `0x12345678`. This could be an integer (sign doesn’t matter; it’s
positive in both), four ASCII letters `"␒4Vx"` (the first byte, `0x12`, is the
control character DC2 and does not have a true visible form), a memory address,
or anything else. Merely by looking at the memory, we don’t know, because C uses
static typing and doesn’t encode type information into data. In C, types are
stored in the source code and evaporate during compilation.

~~~c
int i = 0x12345678;
printf("%i", i);
//  305419896
~~~

Now we know that the data value is an integer.

~~~c
int* pv = i;
printf("%p", pv);
//  0x12345678
printf("%i", *i);
//  Prints ... whatever currently lives
//  at that address. Could be anything.
~~~

This is perfectly legal (on a 32-bit system, pointers are 32-bits wide; on a
64-bit system, it is assumed that the missing digits are all zero), because C’s
type system is also very weak. The variable `pv` has the exact same *value* as
the variable `i`, but a very different meaning. `i` is a number, but `pv` is a
memory location where some other variable (here, also an int) is stored.

We can also do stranger things, like this:

~~~c
char bytes[4];
*(int*)bytes = i;
printf(
  "%x %x %x %x",
  bytes[0],
  bytes[1],
  bytes[2],
  bytes[3]
);
//  '12 34 56 78' (big endian) or
//  '78 56 34 12' (little endian)
~~~

This is fine: C’s type system is very permissive, and as long as we guarantee
that the sizes of everything we’re throwing around are sufficient, it won’t
cause catastrophes merely by writing data to memory locations.

<aside markdown="block">
In C, the above symbol `bytes` is of type `char*`. The compiler knows that the
symbol `bytes` points to four consecutive bytes, but this information never
leaves the compiler.

We can use type casting to pretend that `bytes` actually points to one 4-byte
slot, rather than four one-byte slots in a row, by casting to `(int*)bytes`. We
can then dereference it to store `0x12345678` at the location. Without the
leading `*`, this would attempt to redefine the symbol `bytes` to point to
`0x12345678` rather than to whatever address it was originally pointing.

However, because computers are weird, the memory at `bytes` may likely turn out
to be `0x78563412`, not `0x12345678`, because most modern CPUs store bytes from
least significant first to most significant last.

I am convinced that endianness exists solely because every discipline has to
have some kind of issue over which to bitterly feud despite, if not because of,
there being no real difference between the sides, and the hardware engineers
were feeling left out.
</aside>

C also lets us build complex data structures, like so:

~~~c
//  Make a struct Foo that takes up four bytes
struct Foo {
    short s;
    char c1;
    char c2;
} foo;

//  Assign four bytes into foo
(int)foo = i; // i is still 0x12345678

printf("%i, %i, %i", foo.s, foo.c1, foo.c2);
//  4660 86 120 (big endian) or
//  30806 52 18 (little endian)
~~~

In every single case above, the data value found in memory is exactly the same.
What changes is how that run of data is interpreted.

# Type Theory

It’s important to remember that bare bits have no type whatsoever. Data is
inherently untyped, and humans and programs give meaning to data by how they
act on it.

> Types are a property of behavior, not of existence.

Types are abstract, and only exist in our minds. We choose how to interpret data
and how our programs should interpret it. Things break down when our
interpretations are wrong (for instance, treating a bare integer as a memory
address, or as text), and so some languages and environments like to store type
alongside the data it describes to ensure that it is interpreted correctly. Of
course, since this practice encodes the type information in raw bits, it works
only so long as everything working with that data agrees on the metadata as
well, and as long as it is kept in sync with the data it describes.

This doesn’t change the premise that types are abstract, not concrete. When data
is tagged with its type, the type is read and used to select among behavior. The
type itself is just a number that the code treats as significant.

## Weak Types

C is a classical example of a weak type system: it is only concerned with memory
logistics. If a symbol has a certain bit width, it can store any value that will
fit in that width. As I showed above, C will gladly permit redefining what the
type of a symbol is, and will only raise a complaint if the memory size doesn’t
match up.

This permits programmers a great deal of freedom, but leaves lots of room for
mistakes.

## Strong Types

By contrast, the Rust language has an incredibly strong type system. It matches
C’s level of memory efficiency by not storing type metadata in memory wherever
possible, but enforces type soundness by refusing to compile programs that are
perfectly valid in C, do not break memory, but merely irk the abstract
mathematics powering the type system.

~~~rust
struct Foo(i32);
struct Bar(i32);

let foo = Foo(0x12345678);
let bar = Bar(0x12345678);
~~~

If we hook a debugger to this code and inspect the memory, we will see two
identical 32-bit integers. There is no difference, whatsoever, between them, and
certainly no trace of the `Foo` or `Bar` wrapper types.

~~~rust
if foo == bar { do_something(); }
~~~

This will cause a compilation failure. I have informed the compiler that the
variable `foo` is of `Foo` type, and `bar` is of `Bar` type, and the compiler
treats these as completely separate, independent, never-the-twain-shall-meet,
groups. Unless I give the compiler instructions permitting it, `Foo` and `Bar`
types are as Capulets and Montagues, and aspiring Romeos find themselves
mercilessly shut down at compile time, even though an inspection of the raw
memory would consider this comparison successful. Mathematically, this means
that the compiler sees a set $$Foo$$ and a set $$Bar$$, and elements of one are
**not** elements of the other.

In set theory terms, these plain types are fully disjoint and cannot mix.
Rust does offer a way around this, however.

## Algebraic Types

The term *algebraic types* refers to treating types as abstract mathematical
sets, rather than blocks of memory. In addition to being abstract, these types
define an *algebra* (hence the name) for manipulating them, including basic
mathematical terms like addition and multiplication.

Let us consider *nullable values*. In C, this mostly refers to pointers. One
specific pointer value, `NULL`, is the universal symbol for invalid, and any
other value is considered valid. However, `NULL` takes the same memory layout as
a real pointer, and so in C, they are the same type.

Rust has a different opinion. In Rust, values that exist are not members of the
set of things that do not exist, and `NULL` is the sole member of the set of
nonexistent items and is **not** a member of the set of existing items.

Rust solves this by using *sum types*: types which are the sum of the component
elements.

~~~rust
enum Option<T> {
    Some(T),
    None,
}
~~~

This first declares two types: `Some`, which can have anything as a contained
value, and `None`, which is empty. `Some` is essentially a nearly infinite set,
of which many things are elements, but `None` is not.

`Option` is a type which includes `Some` and `None` both. All `Some`s are
`Options`, and all `None`s are `Option`s, and all `Option`s are either a `Some`
or a `None` but there is no `Option` that is both a `Some` and a `None` at the
same time. Let’s put that in mathematical terms: the set $$Option$$ is the sum
of the sets $$Some$$ and $$None$$, which are two sets such that their
intersection is empty.

$$Option := \{ Some + None \} | \{ Some \} \cap \{ None \} = \{∅\}$$

(The $$|$$ character above means “where”, and this states that the left side is
only true when the right side is satisfied. If there exists an element that is
both $$Some$$ and $$None$$, then the whole expression is invalid.)

Normally, this distinction would require an extra bit alongside the data to
state what flavor of `Option` some value was. However, Rust knows that for many
data types (specifically, pointers and references), the memory value of a `None`
is unique and will never be the memory value of a `Some`, so it makes that
special value the *discriminant*.

C pointers use the `NULL` value to indicate invalidity. This value is often
presumed to be 0, but might not be, depending on the hardware.

<aside markdown="block">
Furthermore, address number `0` is not required to be invalid to access, and on
many architectures, is a perfectly serviceable address to use. I work on a
processor whose memory map includes `0`, but our C compiler has not been patched
to use a non-zero `NULL` value, and so I am unable to access that word in a
program.

The AVR microcontroller architecture is another example of an address space in
which `0` is valid; however, in AVR, address zero is not a memory cell, but a
CPU register.

This is educational, but also allows for horrifyingly unsafe program behavior.
</aside>

In Rust, the exact value is hidden from us, but for `Option<Pointer>`, the `None`
variant is just the platform’s `NULL` value, and the `Some(Pointer)` variant is
anything else. This permits memory that looks in Rust to be identical to C, but
is treated by the code as being two completely different types. The compiler
will refuse to treat a `None` as a `Some`, and if it can’t prove it at compile
time, it will inject code that will enforce this behavior at runtime.

In Rust’s type theory, `enum`s are sum types, since the set of all enum values
is the sum of all the values of each set within it.

There also exists a product (mulitiplicative) type: the `struct`, seen above.

The set of all values of a `struct` is the product of all values of each member
within the struct. The `Foo` and `Bar` structs above only had one member, so
the set of all `Foo` values is $$1 \times \{ i32 \}$$. This is also true for
`Bar`, but the sets `Foo` and `Bar` do not intersect at all.

A more complex structure has many more possible values.

~~~rust
struct Baz {
    a: i32,
    b: Option<i32>,
}
~~~

There exists a `Baz` struct for every value of `a` and for every value of `b`,
but multiplied rather than added.

$$
Baz := \{ i32 \} \times \{ \{ Some(i32) \} + \{ None \} \} | \{ Some(i32) \}
\cap \{ None \} = \{∅\}
$$

# Conclusion

In daily life, we organize information by type. In the real world, type is often
an innate quality things have (like weight or strength or color), but can also
be a quality we give them (like monetary value or beauty or relevance).

This same process of categorization occurs in computing, but with a slew of
unique challenges due to the utter lack of intrinsic information carried by
bits.

In computing, as in human decision-making, type is a property of the behavior
chosen in response to a datum. Just as the same sentence can be taken in very
different ways when heard by two different people, so can the same bits be
taken in different ways when processed by two different instructions.

If you want a one-sentence summary of this article, though, it’s the snippet I
gave above:

> Type is not what the data is, but how we act on it.

That’s an important concept, and one that is often forgotten.

[1]: https://en.wikipedia.org/wiki/Venn_diagram
[2]: https://en.wikipedia.org/wiki/Karnaugh_map
