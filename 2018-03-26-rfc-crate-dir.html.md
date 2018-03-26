---
title: Crate Directory
date: 2018-03-26
category: RFCs
tags:
- rust
summary: >
  A draft RFC for solidifying the library usage mechanisms for non-Cargo
  Rust projects.
---

- Feature Name: lib_dir
- Start Date: 2018-03-22
- RFC PR: (leave this empty)
- Rust Issue: (leave this empty)

# Summary
[summary]: #summary

Add a standardized folder in the Rust project directory structure for
external libraries, in source or compiled form, for ease of use in
projects that do not use Cargo.

# Motivation
[motivation]: #motivation

While Cargo is the official Rust build tool and most common human-facing
interface to the compiler, it is not universally used or usable. Cargo
currently is the primary mechanism for passing dependencies into a Rust
project, which makes it harder to build dependency-consuming Rust
projects without it.

This RFC proposal will make the process of managing and using external
dependencies easier for projects that do not use Cargo, and invoke the
Rust compiler manually or in the scripts of another build tool.

This proposal will also ease the process of vendoring dependencies into a
project.

Both of these are concerns of use cases in environments such as corporate or
otherwise strictly controlled organizations where a foreign build tool or
network-fetched dependencies are unacceptable.

The expected outcome is that it will be very easy to invoke a `rustc` command
line to compile a project that has external crate dependencies without using
Cargo to manage the dependency storage and `rustc` command line generation.

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

When creating a Rust project in an environment that cannot use Cargo, make a
project directory `my_new_project/` with child directories `src/` and `lib/`.
If you have external dependencies available, say from a company repository,
place them inside `lib/`.

Precompiled artifacts (`.rlib`, `.dll`, `.a`, `.so`, for example) do not need
their own folder; they would be stored as `my_new_project/lib/foo.rlib` and
`my_new_project/lib/bar.dll`.

If you have source dependencies, these *are* placed in a subfolder, such as
`my_new_project/lib/baz/`. The `lib/baz` subfolder is the project root of the
`baz` project, and when `baz` is compiled, it will prefix its artifacts with
`baz` and place them directly under `lib/`.

When it comes time to compile your Rust project, whose root file is by default
`src/lib.rs` or `src/main.rs`, you will execute a `rustc` command line from the
project root directory.

```sh
$ pwd
/path/to/my_new_project/

$ tree
.
├── lib
│   ├── regex.rlib
│   └── zip.so
└── src
    └── main.rs

$ head -6 src/main.rs
```

```rust
extern crate regex;

#[link = "zip"]
extern "C" fn compress(ptr: *const u8, len: usize) -> i32;

fn main() {
```

```sh
$ rustc src/main.rs --crate-name my_new_project
```

By default, `rustc` knows to read any `extern crate` lines in your `src/` files
and immediately look in your `lib/` folder for them. If you have a line
`extern crate regex;`, then the artifact `lib/libregex.rlib` will be linked into
your project. If `lib/regex.rlib` does not exist, then `rustc` will continue
searching in its set of known library directories, and if unsuccessful, exit
with an error.

`rustc` also knows to use this folder for dependencies that are not Rust
libraries, so any `extern fn` declarations that have a `#[link = "zip"]` will
cause the compiler to search for a `lib/libzip` with any of the appropriate
library file extensions before searching in its other known library directories.

If you wish to call your library folder something else, or to not have it stored
inside your project dir, then you can instruct `rustc` to search elsewhere with
the `-L /path/to/libraries` flag. Any paths given with this flag take precedence
over builtin library search paths.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

Add a `./lib` at the front of the library search path set in the compiler, and
search `extern crate`-declared libraries in the library search path without
requiring an `--extern /path/to/crate` flag in the compiler invocation.

# Drawbacks
[drawbacks]: #drawbacks

I can't really think of any.

# Rationale and alternatives
[alternatives]: #alternatives

- Why is this design the best in the space of possible designs?

The project-level `lib/` directory is a reasonably common idiom for projects
that must carry their dependencies with them. Making the compiler aware of an
in-tree directory to search for dependency artifacts, both `rlib` and not, makes
a more ergonomic experience for using Rust without the Cargo tool.

- What other designs have been considered and what is the rationale for not
    choosing them?

None that I know, hence why this RFC document is on my website and not a pull
request.

TODO: Remove before requesting pull.

- What is the impact of not doing this?

It will be slightly less ergonomic to invoke `rustc` by hand or by foreign build
system to use vendored dependencies, aka status quo.

# Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.
A few examples of what this can include are:

- For language, library, cargo, tools, and compiler proposals: Does this feature
    exists in other programming languages and what experience have their
    community had?
- For community proposals: Is this done by some other community and what were
    their experiences with it?
- For other teams: What lessons can we learn from what other communities have
    done here?
- Papers: Are there any published papers or great posts that discuss this? If
    you have some relevant papers to refer to, this can serve as a more detailed
    theoretical background.

This section is intended to encourage you as an author to think about the
lessons from other languages, provide readers of your RFC with a fuller picture.
If there is no prior art, that is fine - your ideas are interesting to us
whether they are brand new or if it is an adaptation from other languages.

Note that while precedent set by other languages is some motivation, it does not
on its own motivate an RFC. Please also take into consideration that rust
sometimes intentionally diverges from common language features.

# Unresolved questions
[unresolved]: #unresolved-questions

- What parts of the design do you expect to resolve through the RFC process
    before this gets merged?
- What parts of the design do you expect to resolve through the implementation
    of this feature before stabilization?
- What related issues do you consider out of scope for this RFC that could be
    addressed in the future independently of the solution that comes out of this
    RFC?
