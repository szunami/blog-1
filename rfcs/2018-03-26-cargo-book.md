---
title: Cargo Book
tags:
- rust
summary: >
  A draft RFC for adding a `book` subcommand to Rust’s Cargo tool.
---

- Feature Name: cargo-book
- Start Date: 2018-03-12
- RFC PR: (leave this empty)
- Rust Issue: (leave this empty)

# Summary

The Rust distribution has an official book generator, [`mdBook`][mdbook], in the
nursery. This generator should be able to be used in Cargo projects to build the
external documentation into a book independent of the artifacts produced by
`rustdoc`.

# Motivation

External documentation is very good, and standalone Markdown files are a much
nicer editing environment than are comments in Rust source files. Furthermore,
the external documentation set for a project can include a more comprehensive
suite of project documentation, in contrast to the `rustdoc`-generated docs
which are primarily technical.

As `rustdoc` supports an external documentation file now via
`doc(include = "path")`, documentation files can even be reused!

# Guide-level explanation

Rust projects often follow certain conventions about where items are located.
For example, the source code for a project lives under `src/`[^1], integration
tests in `tests/`, and example uses in `examples/`. Documentation for a project
can be written directly in source code, as documentation comments (`///`, `//!`,
`/** **/`, or `/*! !*/`[^2]), or can be written in Markdown files that live
under `doc/` and are referenced by the Rust code (see
[RFC #1990][rfc_external_doc] and [issue #44732][issue_external_doc]).

The `cargo doc` subcommand builds documentation from your source code, and the
`cargo book` subcommand builds a manual from the contents of your `doc/` folder
with the `mdBook` tool.

This manual is built from the `doc/SUMMARY.md` root file by default. A custom
root file, or multiple books, can be set in your `Cargo.toml` file, like this:

```toml
[[book]]
# Title of the book
name = "User’s Guide"
# Path to the book
# `/SUMMARY.md` is implicitly appended
path = "doc/user"
```

The contents of a book directory are laid out in the
[`mdBook` documentation][mdbook_docs]. The output of `cargo book` can be found
in `target/book`.

## Book vs Docs

While Rust docs *are* superheroes, this isn’t a Hulk-vs-Thor gladiator scene.
Books and docs are teammates.

The book is meant to be a complement to, not a replacement of, the source code
documentation that we already have. Source code documentation provides an
excellent set of technical information for the APIs and behavior found in a
project, but is less well-suited for non-technical documents such as a user’s
manual, or a comprehensive guide, or an explanation of the theory behind a
library.

Every project you’ve seen that has a guide distinct from the API docs —
[Rocket][rocket_guide], [Diesel][diesel_guide], [Turtle][turtle_guide], and more
— can benefit from having these manuals directly in the project repository.

## Testing

The `cargo test` command knows how to ask `cargo book` for all the book files in
the project, and pull out any pieces of Rust code inside them. All the Rust code
snippets in your book is part of your test suite, just like the snippets in your
documentation comments!

# Reference-level explanation

Since `mdBook` is in the Rust Nursery and considered an official project, and
used to render [everything in The Rust Bookshelf][rust_bookshelf], it is a good
candidate for inclusion into the Cargo workflow and the Rust distribution.

Cargo will add the creation of a `doc/` directory to its `cargo new` command,
and add a `cargo book` command that uses the `mdbook` library to drive the book
generation. The default book configuration for `cargo book` differs from the
defaults that `mdBook` expects; currently, the `cargo book` configuration is
equivalent to the following `book.toml` in the root of a Cargo project:

```toml
[book]
title = "$crate_name"
src = "doc"
description = "$crate_description"

[build]
build-dir = "target/book/$crate_name"
```

Cargo will add a `[[book]]` table to its `Cargo.toml` specification that takes
the same keys as the `[book]` table currently in `mdBook`’s `book.toml`. The
only difference is that `[book] src` will be changed to `[[book]] path` in order
to match existing conventions in `Cargo.toml`.

When executing `cargo book`, Cargo will map each `[[book]]` table into an
`MDBook` struct and build the book into `target/book`. If more than one
`[[book]]` table exists in `Cargo.toml`, then each book will receive its own
subdirectory named by its title and hash.

The `mdBook` project does not need to be altered from its present state for this
RFC to land. The `book.toml` settings above are sufficient for `mdbook` to
correctly operate in the root of a Cargo project directory that has one book in
`doc/`.

Cargo will need to be changed in four areas:

- the `Cargo.toml` specification, to include `[[book]]`
- the addition of a `cargo book` subcommand
- the expansion of `cargo new` to create `doc/{SUMMARY,README}.md` (perhaps
  optional, such as behind a `--with-book` flag)
- the expansion of `cargo test` to extract all Rust code from `doc/**/*.md`

The Cargo documentation will also need to be expanded with a chapter on using
`cargo book`.

This RFC should require comparatively little technical work, as the components
required already exist and require “only” integration, rather than full
construction.

# Drawbacks

This expands the scope of Cargo’s work in a project directory, and may result in
more complexity in both the codebase and the user interface. Furthermore, it may
not be desirable to have Cargo accumulate more and more features that can be
managed by distinct programs.

The author’s counterargument to the above paragraph is that Cargo ate Rustdoc
and everyone is fine with that. Add a `cargo mdbook` parallel to `cargo rustdoc`
to control the tool directly with Cargo support for paths if desired, but Cargo
is very clearly a project manager, and Rust’s culture very clearly holds that
documentation is a first-class citizen of a project that is an equal peer of
source code.

# Rationale and alternatives

- Why is this design the best in the space of possible designs?

  It integrates with existing workflows for Cargo, uses existing unofficial
  conventions, and existing tools.

- What other designs have been considered and what is the rationale for not
  choosing them?

  None to my knowledge

- What is the impact of not doing this?

  Projects have to write their user manuals separately from their API docs and
  don’t have native testing support for any code in them, aka, the status quo.

# Prior art

I don’t know off the top of my head of any language toolchains that have a book
builder in their tool set, be it in the official project manager or not.

# Unresolved questions

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?

  Human interface details like “should we call it `book/` instead of `doc/`
  and use `doc/` for API documentation files” or “what should the Cargo
  interface be”

- What parts of the design do you expect to resolve through the implementation
  of this feature before stabilization?

  None come to mind.

- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?

  Everything related to how `mdBook` actually functions is out of scope of
  this RFC. If `mdBook` grows new features *because* it is integrated into
  Cargo by this RFC, those new features are still `mdBook`’s responsibility.

# FOOTNOTES ARE NOT PART OF THE RFC I JUST HAVE STRONG (BAD) OPINIONS

{:.no-toc}

[^1]: I firmly believe `src/bin/` should have been `app/` instead.

[^2]: Doc comments are block comments, fight me.

[summary]: #summary
[motivation]: #motivation
[guide-level-explanation]: #guide-level-explanation
[reference-level-explanation]: #reference-level-explanation
[drawbacks]: #drawbacks
[alternatives]: #rationale-and-alternatives
[prior-art]: #prior-art
[unresolved]: #unresolved-questions

[diesel_guide]: http://diesel.rs/guides/
[issue_external_doc]: https://github.com/rust-lang/rust/issues/44732
[mdbook]: https://github.com/rust-lang-nursery/mdBook
[mdbook_docs]: https://rust-lang-nursery.github.io/mdBook/
[rfc_external_doc]: https://github.com/rust-lang/rfcs/pull/1990
[rocket_guide]: https://rocket.rs/guide/
[rust_bookshelf]: https://doc.rust-lang.org/#the-rust-bookshelf
[turtle_guide]: http://turtle.rs/docs/
