---
title: Rust Flow, Part Two
date: 2018-11-29
tags:
- rust
summary: >
  Rust doesn’t have a language-level concept of generic mutability, which makes
  “method threading” (which take `self` by some handle, and return it in the
  same way) hard to write. This article covers how to write in that pattern in a
  less painful way.
---

Previously, on *Insufficient Magic*: [*Rust Flow*][rust-flow].

## Method Threading

This is a subset of “method chaining” that covers functions which explicitly
take their receiver by some handle (value, im/mutable reference, or other) and
return that same handle.

Rust encodes certain rules about object access directly into the language, with
its concept of first-class distinction between direct values, mutable
references, and immutable references. These correspond to direct ownership,
unique borrows, and shared borrows.

For any type `T`, the access methods of by-value (`T`), by-mutable-reference
(`&mut T`), and by-reference (`&T`) are considered three discrete types in the
type system. The compiler will implicitly step values down (from `T` to `&mut T`
or `&T`, and from `&mut T` to `&T`) in method calls, but the language does not
permit explicitly writing methods that declare a minimum privilege level as
their receiver, and then *emit that same receiver* regardless of how they use
it.

This is a problem because Rust will implicitly step down a receiver in order to
fit the type declared as the `self` parameter in a method, but this is an
irreversible process.

## Tapping

Ruby provides a method, `Object#tap`, in the standard library which takes and
returns `self`, and runs a given block on that `self`. This is distinct from the
`map` function in that it cannot modify the type of the object on which it runs,
and ensures that the value is returned, so `nil`-returning methods do not
destroy it.

There currently exists a [`tap` crate][tap_crate], which I partially maintain,
which ports this concept to Rust. The `Tap` trait has a method, `tap`, which
takes `self` by value and returns `Self`, and runs a given function or closure
on `&mut self`.

I am currently rewriting the crate to distinguish between immutable and mutable
taps, and improve the conditional tap traits present in the original.

The summary of the tap crate and everything it offers is this: tapping is fully
transparent at the type level – adding or removing a tap call cannot change the
type of the expression before or after it – and agnostic to the behavior of the
accessory block it runs.

## Current API Design

One common problem in building Rust APIs is determining how to support running
multiple small methods on an object in order to make manipulating it more
ergonomic. A canonical example of a well-made builder-pattern API is the
[`Command`] type in the standard library.

`Command`’s constructor has the signature `() -> Self`, its modifiers have the
signature `&mut self -> &mut Self`, and its consumers have the signature
`&mut self -> _`. This makes `Command` objects really easy to method-chain, as
the documentation shows:

```rust
use std::process::Command;

let child = Command::new("count")
  .arg("one")
  .args(&[
    "two",
    "three",
  ])
  .spawn();
```

But if you’ve ever tried to bind the result of a modifier call, such as by
dropping the `.spawn()` call above and just binding after `.args()`, you run
into this error:

```rust_errors
error[E0597]: borrowed value does not live long enough
  --> src/main.rs:4:11
   |
4  | let cmd = Command::new("count")
   |           ^^^^^^^^^^^^^^^^^^^^^ temporary value does not live long enough
...
9  |   ]);
   |     - temporary value dropped here while still borrowed
10 |   // .spawn();
11 | }
   | - temporary value needs to live until here
   |
   = note: consider using a `let` binding to increase its lifetime
```

Once the modifier methods downgrade from `self` to `&mut self`, they can only
return the reference; even if called with a value, they cannot return that
value. It drops at the end of the expression.

This threading pattern is currently the worst combination of possible design
spaces. It is *very* convenient for one case – building a `Command` and then
immediately using it – but very **in**convenient for anything else. Removing the
`.spawn()` call causes non-local restructuring of the code.

Tap solves this problem by decoupling API contracts from usage style.

## Tapping API Design

Tap frees API authors from having to plan for, and constrain, the code style of
end users. The `Command` API is built to expect method chaining, and as a
result, it forces the user to either go all-in on the chain, or break it by
writing

```rust
let mut cmd = Command::new("greet");
let _ = cmd.arg("hello").arg("world");
let child = cmd.spawn();
```

Tap removes the requirement for API methods to return their receiver, removes
the constraints imposed by irreversible degradation of receiver bindings, and
permits the end user the freedom to write their use of your API however they
want.

With taps, API authors can use function signatures to only care about the
contract of their function body, without worrying about how each method composes
with other methods on the same object, or external code.

With taps, end users can control the mutability of a value at each point in a
usage sequence, be assured that value bindings cannot degrade, and still use all
the functionality of Rust’s automatic reference/value manipulation.

Rather than writing methods which take and return `&mut self` even if they do
not mutate it, in order to not degrade the receiver, API authors can declare
exactly the level of mutability they require, and are not required to add an
extra `self` at the end of the function body.

Rather than writing `let` and `let mut` bindings for each point in a usage
sequence, users are able to dodge the repeated shadow bindings that make Clippy
sad, and use as imperative or as functional a style as they like.

An example of an API that is perfectly suited for use under taps is [`Vec`].
`Vec`’s manipulation methods are famously unable to be chained, because they
have the signature `&mut self -> ()`. They also require rebinding in order to
remove mutability after work is done:

```rust
let mut vec = vec![5, 1, 4, 2, 3];
vec.sort();
vec.reverse();
let vec = vec;
```

If you like writing in an imperative style, this is perfectly fine. There is no
unused return value; each usage is a discrete point in the sequence. It just
cannot be written like the `Command` example at all. With taps, however, a
method chain is immediately available:

```rust
let vec = vec![5, 1, 4, 2, 3]
  .tap_mut(|v| v.sort())
  .tap_mut(|v| v.reverse());
```

There is no rebinding to remove mutability. The vector can be created,
manipulated, and frozen, all in one expression. This sequence can be placed in a
closure without requiring braces to contain repeated statements. The presence of
tap calls does not introduce lifetime problems by degrading the initial `Vec`
value.

### Inverse, Inverse

I have described the problems of using `&mut self -> &mut Self` modifier APIs.
This is an easy dodge: make them fully consuming APIs – `mut self -> Self`. Many
builder-pattern APIs do this.

Here’s the problem: these methods can’t be run on a mutable reference. Mutable
references in Rust are supposed to be equivalent in every way except destruction
to full ownership. A mutable reference *should* be able to modify the referent
in every supported, non-destructive way. You don’t have to take ownership of a
`Vec` to sort it. The Rust books explicitly describe the purpose of references
as a temporary transfer of control without requiring `mut self -> Self`
signatures to move and recapture values.

Tap is implemented on all sized types, and that includes references. Rust will
automatically move up or down a reference chain as needed in order to do what
you want. In combination, this means that you can `.tap_mut` a value *or a*
*mutable reference* with the exact same code, and get the same result. You can
`.tap` a value, a mutable reference, or an immutable reference, without changing
anything.

```rust
let mut v = vec![5, 1, 4, 2, 3];
(&mut v).tap_mut(|v: &mut &mut _| v.reverse());
(&    v).tap(    |v: &    &    _| println!("{}", v.len()));
     (v).tap_mut(|v: &mut      _| v.sort());
```

Type-idempotent methods (`self -> Self`) are, in general, an antipattern that
should be replaced with `&mut self -> ()` mutators. Doing so improves both the
experience of writing code against the API and the codegen performed by the
compiler, and the `self -> Self` value passing can be regained with taps.

## Inspection Without Modification

I have primarily described taps as a means of decoupling modifier APIs from end
user bindings. This is the pattern that is more interesting and useful to API
authors, because it means that they don’t have to make tradeoffs about function
signatures or usage styles.

All users can use the immutable taps as a quick shortcut means of inspecting a
value without affecting the code around that inspection. Immutable taps permit
dropping log points anywhere in an expression without requiring temporary bind
points, or ticking a counter, or running any other side effect you might want
when something happens.

## Summary

Tapping methods allow API authors to only use the borrows they explicitly need,
and allow users to write code more ergonomically. They permit adding inspection
or modification to any expression without changing its type or code style.
Tap composes with borrowing methods to enable their use inside composite
expressions without changing the type or mutability at that point.

Because of the ownership guarantees in the tap methods’ signatures, the compiler
can easily eliminate the function calls of the taps, and replace them solely
with the inner function calls on the receiver.

To the compiler, taps are invisible and zero-cost.[^1] To the library author,
taps remove the burden of supporting multiple use conventions. To the user, taps
enable painless structuring of their code however they find easiest.

## Get the Code

I am a co-maintainer of [`tap`][tap_crate] and likely the primary author in the
event of any ongoing work.

```toml
# Cargo.toml

[dependencies]
tap = "1
```

\[^1\]: The compiler learned to optimize this pattern in [1.23.0]. Older
compilers move the receiver value into and back out of the tap function, which
can result in significant `memcpy` work if called on large values.

[`Command`]: //doc.rust-lang.org/stable/std/process/struct.Command.html
[`Vec`]: //doc.rust-lang.org/stable/std/vec/struct.Vec.html
[1.23.0]: //github.com/rust-lang/rust/blob/master/RELEASES.md#version-1230-2018-01-04
[rust-flow]: //myrrlyn.net/blog/misc/rust-flow
[tap_crate]: //crates.io/crates/tap
[tap_portfolio]: //myrrlyn.net/crates/tap
