---
title: Convert Trait
date: 2018-12-02
category: RFCs
tags:
- rust
summary: >
  Create a partner trait to `From` that allows conversion in a method chain.
---

- Feature Name: convert_trait
- Start Date: 2018-12-02
- RFC PR: (leave this empty)
- Rust Issue: (leave this empty)

# Summary
[summary]: #summary

This is a partner trait to [`From`] and [`Into`] that allows using a conversion
method in the middle of a chain.

# Motivation
[motivation]: #motivation

Currently, Rust code cannot write

```rust
struct A; struct B; struct C;
impl From<A> for B { /* … */ }

let a: A = A::new();
let c: C = a.into().b_to_c();
```

This is because the expression `a.into()` does not specify a final type, and
there is an infinite set of possible types that may have a method with the
signature `fn b_to_c(self) -> C`. The compiler is incapable of determining which
specific `Into<?> for A` impl to use, and fails compilation.

Because the `Into` trait defines `fn into(self) -> T` as a **non**-generic
function, the expression `.into::<T>()` is ill-formed, and attempts to select a
method that does not exist.

Currently, the only way to write this expression without temporaries is to use
UFCS:

```rust
let c: C = <A as Into<B>>::into(a).b_to_c();
```

> This can be shortened as `Into<B>::into(a)`, because `a` has a known type and
> thus fully specifies the trait impl to use. I will use fully specified trait
> functions in this RFC for clarity.

or to use the companion trait, `From`:

```rust
let c: C = <B as From<A>>::from(a).b_to_c();
```

> This can be shortened as `B::from(a)`.

Both of these require significantly rearranging the expression, using a leading
type and function instead of method and trailing type, and introduce a lot of
noise. This loses all the advantages of method syntax, both syntactic and
semantic.

This trait supports the use case of type conversions in a method chain where
`map` is unavailable. The expected outcome is that `a.into().use()` chains will
require a much smaller insertion of type information, rather than a large
rewrite, making writing these expressions more smooth.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

Rust offers the `std::convert` module as a defined set of interfaces for
converting values from one type to another. The `From` trait is the idiomatic
standard for moving values between types, and the companion traits `Into` and
`Convert` provide automatic conveniences for invoking it.

A type conversion between an existing source type, `Source`, and a target type,
`Target`, is established by writing an `impl From<Source> for Target` block with
the conversion function. Once this block exists, the universal implementations
in the standard library make `Into<Target>` and `Convert` methods available on
`Source`.

Conversion from an instance of the source type to the target type can be
achieved with the `From` free function or with the `Into` or `Convert` methods.

```rust
#[derive(Clone, Copy)]
struct Source;
struct Target;

impl From<Source> for Target {
    fn from(src: Source) -> Self {
        Target
    }
}

fn main() {
    let a = Source;
    let b = Target::from(a);
    let c: Target = a.into();
    let d = a.convert::<Target>();
}
```

`Into` and `Convert` are complements of each other. `Into<Target>` is the right
choice for use in trait bounds, while `.convert::<Target>()` is the right choice
for use in method calls. They both perform the same underlying thing:
`<Target as From<Self>>::from(self)`.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

In the `std::convert` module, define a new trait:

```rust
pub trait Convert : Sized {
    fn convert<T: Sized + From<Self>>(self) -> T {
        <T as From<Self>>::from(self)
    }
}
```

and blanket-implement it on all sized types:

```rust
impl<T: Sized> Convert for T {}
```

# Drawbacks
[drawbacks]: #drawbacks

Why should we *not* do this?

The standard library should not be a slowly-accumulating pile of idioms.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?

  It's a trivial wrap around `From`, just like how `Into` is written

- What other designs have been considered and what is the rationale for not
  choosing them?

  Type ascription : apparently difficult, has not made much progress, requires
  language-level support

- What is the impact of not doing this?

  Method chains are less ergonomic than possible when they require type
  conversions.

# Prior art
[prior-art]: #prior-art

The `Into` trait shows willingness in the standard library to define companion
traits that function only as a reshaping of how the base trait is invoked.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?

  What should it be named?

  - `Convert` is the full word
  - `Conv` is four letters, matching `From` and `Into`
  - other?

- What parts of the design do you expect to resolve through the implementation
  of this feature before stabilization?

  None

- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?

  None

# Future possibilities
[future-possibilities]: #future-possibilities

None

[`From`]: https://doc.rust-lang.org/std/convert/trait.From.html
[`Into`]: https://doc.rust-lang.org/std/convert/trait.Into.html
