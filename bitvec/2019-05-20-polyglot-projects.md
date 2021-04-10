---
title: Polyglot Projects
date: 2019-05-20
tags:
- bitvec
- c
- programming
- rust
summary: >
  An exploration of how I wrote a C++ binding API for my Rust library.
---

> The GitHub links are dead.
{:.bq-harm}

## Introduction

As work on my [`bitvec`] project neared completion <ins>lol</ins>, I began
thinking about how it might be used by other programming languages. While C++
offers optimized `bitset` and `vector<bool>` constructs (mapping to my
`&mut BitSlice` and `BitVec` types, respectively), I know of no languages with
libraries that offer parallels to my project.

At work, I came to a point where I had reason to need a C++ library with the
functionality of `bitvec`, and I realized I could be my own customer of a set of
idiomatic foreign-language bindings against the Rust crate.

## First Steps

The first commit on my branch was to move everything from the project root into
a subdirectory, `rust/`, and then rebuild the project root as a polyglot
repository. This meant making a workspace Cargo manifest so I could run `cargo`
from the root directory, a recipe file to link Rust and other language
development processes, and a new README describing how to use the project.

I then added a feature named `ffi` to the Rust project, then added a module of
the same name gated on that feature. As it is not a default feature, Rust users
who want to use the crate normally will not notice any difference.

## Building the FFI

I then made a module, `ffi/slice`, and began rebuilding the `BitSlice` API in
it. The immediate obstacle is: it is impossible to expose generic types or
functions as C symbols over FFI. Furthermore, the end result of this work is
that the project must be compiled as an object-code archive, with all the
functions monomorphized and present in it.

This means that for each generic method in the `impl<C, T>` blocks, eight
functions (two provided `Cursor` types, four provided storage types) functions
must be written in the `ffi/slice` module. Since these functions are going to be
entirely identical except for function signature, I learned how to make pattern
templates in my editor so that I could enter a macro and have it expand to the
set of eight functions, correctly monomorphized.

### Initial API Design

The FFI functions that Rust exposes must have a C-compatible API surface. This
gives the following constraints:

- the function **must** be `pub` all the way to the crate root, so that the Rust
  compiler will leave it in the artifact even though it is unused
- the function **must** be marked `extern "C"` so that the compiler will give it
  the local C compiled interface, rather than the Rust native ABI (which is
  unspecified)
- the function *should* be marked `#[no_mangle]` so that the name written in the
  source code is the same name written into the symbol table, and accessible
  from C. Without this attribute, the C code will have to call, for example,
  `_ZN7example3ffi5slice18bitvec_bs_b08_name17hf0d3f773bb3ad533E`, instead of
  `bitvec_bs_b08_name`.
- the function *should* be marked `unsafe`. All `extern` functions are treated
  as `unsafe` by default, but without the keyword, their bodies are not `unsafe`
  blocks and so require the keyword to call other `extern` functions or do any
  other `unsafe` work required by the FFI boundary.
- all types in argument or return position **must** be describable to C, and
  *should* be either C fundamentals or wrappers over them. Personally, I don’t
  even pass small structs by value; only the fundamentals transfer by value, and
  everything else by pointer.

Since the `&BitSlice` pointer type is *not* a simple type – it is a two-word
structure, with complex internal rules – I elected to always pass it by pointer.
Furthermore, `BitSlice` is not an object at all in Rust, but a dynamically-sized
type describing a region of memory. As such, it is only ever handled as a
reference.

I thus wound up with the type signature of
`*{const|mut} *{const|mut} BitSlice<BigEndian, u8>`, expanded to each
permutation of `Cursor` and `Bits` implementors the crate offers.

The left-most pointer is a pointer to the `&BitSlice<_, _>` structure, and its
`const` or `mut` flag marks whether the pointer itself can have its structure
values modified. Functions that manipulate `&BitSlice` values take a `mut`
pointer, and functions that only inspect the slice handle take a `const`.

The right pointer is the actual pointer to the region. It is a two-word
structure, which Rust interprets as a pointer and C does not. *Its* flag marks
whether the function can modify the data in the region to which it points. All
four combinations of `mut` and `const` pointers are valid, with their own
meanings and correct uses.

### Problems

Rust references are known to be valid. C pointers are unconstrained, and may be
null.

The FFI boundary functions must take it on faith that pointers they are given
are valid, and must check that the pointers are not null before using them. At
first, I wrote a `nullck!` macro that checked each argument for null, and after
the macro ran, my function body could be sure it was proceeding on valid data.

This is fine, but is not idiomatic Rust, and the boundary functions are still
Rust functions.

I then realized that Rust makes a very big deal out of the fact that
`Option<&T>` has the exact same ABI surface as `*const T`, and `Option<&mut T>`
as `*mut T`.

This means that all pointers can be rewritten in the Rust FFI signatures as
options of references, and then I can use the type system to enforce null
checking for me.

I then moved all my type signatures from double pointers to double option
references. They look like this:

```rust
Option<&'a [mut] Option<&'b [mut] BitSlice<_, _>>>
```

This is (a) ugly and (b) confusing. I found it *extremely* easy to lose track of
which layer I was attempting to inspect or manipulate, especially as I started
to favor `Option` combinators over `match` statements.

### Less Unpleasant Types

Enter type aliases:

```rust
type Pointer<'a, T> = Option<&'a T>;
type PointerMut<'a, T> = Option<&'a mut T>;
```

This alias describes a pointer to any particular type. I used it solely for
types that were ABI-equivalent to C pointers of any type. I then mapped the
`&BitSlice` references to another alias,

```rust
type Slice<'b, C, T> = Option<&'b BitSlice<C, T>>;
type SliceMut<'b, C, T> = Option<&'b BitSlice<C, T>>;
```

These type aliases allowed me to reduce my function signatures to

```rust
#[no_mangle]
pub unsafe extern "C"
fn bitvec_bs_b08_name<'a, 'b: 'a>(
  this: Pointer<'a, Slice<'b, BigEndian, u8>>,
) -> Return {
  //  not-null pointer to slice handle
  if let Some(lhs) = this {
    //  not-null handle to slice
    if let Some(bits) = lhs {
      //  bits: &BitSlice is now usable
    }
  }
}
```

which is much more readable. The distinction between pointer-to-C-value and
handle-of-memory is clearly marked, and I can use `Pointer` for *any* object
crossing the FFI boundary, not just slice handles. Since type aliases are
transparent, I can still use the `Option` patterns and methods on these values.

With a consistent enough naming scheme (`this` and `other` for outer pointers,
`lhs` and `rhs` for inner pointers, and useful names for the final referent),
reading the FFI boundary functions becomes habitual and much less surprising.

Final Rust file: [`rust/src/ffi/slice.rs`][slice-rs]

## Using the FFI

Once the Rust functions are written, they need to be made available to C.

### Finding the Rust Artifacts

If you look at the artifacts that `rustc` produces, you’ll see a *lot* of them,
but…

```sh
$ ls target/debug
.fingerprint/
build/
deps/
incremental/
native/
libbitvec.d
libbitvec.rlib

$ file target/debug/libbitvec.rlib
libbitvec.rlib: current ar archive
```

That `.rlib` file is the compiled artifact of the crate. With the
`--features ffi` flag, it will even have the monomorphized FFI boundary
functions in it, ready for use from C!

Let’s write a quick C program:

```c
int main() {
  return 0;
}
```

and link it against that library and see what happens!

```sh
clang -std=c99 c/example.c target/debug/libbitvec.rlib -otarget/c
```

… oh.

That’s *several* linker errors.

Here’s the problem: Rust compiled *the crate*. It did not link the crate against
`std`. Rust libraries are built to be consumed by Rust executables.

We could tell `clang` to link against the local Rust `std` also, but that’s a
lot of work. Instead, we can tell Rust that we want the library to be usable by
a C program, by modifying the crate’s `Cargo.toml`.

```toml
# Cargo.toml

[lib]
crate-type = [
  "cdylib",    # .so/.dylib/.dll
  "rlib",      # .rlib
  "staticlib", # .a/.lib
]
```

### Using the (Correct) Rust Artifacts

Let’s compile again, with `cargo build`, and look in `target/debug`:

```sh
$ ls target/debug
…
libbitvec.a
libbitvec.d
libbitvec.rlib
libbitvec.so
```

```ps1
> dir target\debug
…
bitvec.d
bitvec.dll
bitvec.dll.d
bitvec.dll.lib
bitvec.lib
libbitvec.d
libbitvec.rlib
```

The `.a` and `.lib` files are statically-linked archives, and the `.so` and
`.dll` files are dynamically-linked. *These* files can be fed into a C linker
for C to use. Let’s try the static!

```sh
$ clang -std=c99 c/example.c target/debug/libbitvec.a -otarget/c
…
/rustc/91856ed52c58aa5ba66a015354d1cc69e9779bdf//src/libstd/sys/unix/thread.rs:374: undefined reference to `pthread_attr_getstack'
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

Awkward. There’s a correct invocation of the other libraries that Rust requires
in order to use static archives correctly, and I remember the compiler *used* to
emit it, but I don’t know the list anymore. Let’s try the dynamic instead.

```sh
clang -std=c99 c/example.c target/debug/libbitvec.so -otarget/c
target/c
```

This compiles, links, and runs. The fact that it does nothing is incidental; we
just needed to get a C program linked against the Rust-made library.

### Telling C About the Rust Library

The next step is to inform C that there exist functions and types for it to use.
We do this by writing a header file that defines equivalents to our Rust types,
and a bunch of `extern` functions that tell C "you may call this function with
these types and get this type back". The C compiler will insert a call to that
function name, and punt to the linker to figure out what object code we meant.

Since we `#[no_mangle]`d our Rust functions, we can copy their names into the C
header, and when C calls them, the linker will find them in the Rust object,
match things up, and everything should Just Work.

Problem: C has *no* idea what the Rust types are.

First solution: declare a `struct` that just matches the ABI of the Rust
`&BitSlice` handles.

```c
#include <stddef.h>

struct BitPtr {
  void * ptr;
  size_t len;
};
```

This is equivalent in ABI to `Option<&BitSlice>` on the Rust side, though as
noted in the `bitvec` docs, the C side absolutely must not read either field of
the struct. But we have a correctly sized record, and we can start passing it to
Rust.

Let’s initialize it!

```c
int main() {
  struct BitPtr tmp;
  bitvec_bs_b08_empty(&tmp);
  return 0;
}
```

```sh
clang -std=c99 c/example.c target/debug/libbitvec.so -otarget/c
target/c
```

This runs, though we still cannot observe any effects. I’m not going to continue
showing calls to functions in C that have no observable effect other than “not
crashing”, so, let’s move on.

## FFI, but, Make It Fashion

Writing a header file that lists functions available to call is table stakes.
Entry fees. The bare minimum to make a project polyglot.

We want `bitvec` to have a native-esque interface in every language that uses
it. This means types.

Our first problem: C doesn’t have an `Option<bool>`, and the API uses that
pervasively. We do happen to know that Rust guarantees it fits in a `uint8_t`,
so we could write a C enum for it, like

```c
enum OptionBool {
  False = 0,
  True = 1,
  None = /* ??? */,
};
```

And use

```rust
println!("{}", unsafe { std::mem::transmute::<Option<bool>, u8>(None) });
```

to get the value of `None` (it’s `2`), but this is silly work to do manually,
especially if the compiler changes its mind about representations.

For all types that C has to know, but are not under `bitvec`’s direct control,
we should have the compiler do the work for us. The simplest way to do this is
to have a build script emit the C declarations of the Rust native types we’re
using.

Rather than reproduce it here, I’ve linked [my build script][build-rs].

### Set Rust Asail in C

The first challenge is carrying over Rust’s distinctions of mutability and
immutability. Neither C nor Rust have the concept of being parametric over `mut`
or `const`, so this means separate types:

```c
typedef struct {
  void const * ptr;
  size_t len;
} BitPtrImmut;

typedef struct {
  void * ptr;
  size_t len;
} BitPtrMut;
```

And since `&mut T` is a superset of `&T`, we need to be able to use all
`BitPtrMut` as `BitPtrImmut`, but not the other way:

```c
typedef struct {
  BitPtrImmut immut;
} BitSlice;

typedef struct {
  union {
    BitSlice immut;
    BitPtrMut mut;
  } u;
} BitSliceMut;
```

There! Now we can degrade a `BitSliceMut` to a `BitSlice`, but a `BitSlice`
cannot[^1] upgrade to `BitSliceMut`.

Now we just rewrite our functions to take `BitSlice *` or `BitSliceMut *`, and
define a macro to degrade from mut to const for us,

```c
#define BV_IMMUT(bvbsm) &((bvbsm).u.immut)
```

so that we can make calls expecting `BitSlice *` with the name of a
`BitSliceMut`, and we’re set.

…

Except C can’t distinguish the cursor or storage types, so this permits mixing
the actual Rust functions we’re calling. There’s nothing to prevent calling the
function `bitvec_bs_l32_get` (using little-endian order on `u32`) on a slice we
initialized with `bitvec_bs_b16_from_slice` (using big-endian order on `u16`).

This, obviously, is Not Good.

The C side needs to mirror each monomorph that the Rust side had.

With sixteen more declarations.

```c
typedef struct {
  BitPtrImmut immut;
} BitSliceB08;

typedef struct {
  union {
    BitSliceB08 immut;
    BitPtrMut mut;
  } u;
} BitSliceB08Mut;
/* repeat for L08, B16, … */
```

and then change all our function declarations to

```c
bitvec_bs_b08_len(BitSliceB08 const * self);
bitvec_bs_l08_len(BitSliceL08 const * self);
bitvec_bs_b16_len(BitSliceB16 const * self);
/* … */
```

and *now* we have an idiomatic C API.

Final C FFI declaration: [`c/bitvec/slice.h`][slice-h]

If you read that file, you’ll notice some blocks like this:

```cpp
#ifdef __cplusplus
// …
#endif
```

and you might remember this bit from the build script:

```cpp
enum
#if defined(__cplusplus) \
&& __cplusplus > 201101L
class
#endif
OptionBool {
```

These are here to make the files forward-compatible with C++, which will also
read them. The text inside these guards is incomprehensible to the C compiler,
so the preprocessor removes them unless in the presence of a (recent enough) C++
environment.

### Sprinkle in Some Class

C is a pretty straightforward language: we call functions with items, and that’s
about it.

C++ is much more interesting, and preferable to use. Furthermore, its object
system and templating allows us to more nicely mirror Rust’s generic structs and
method syntax.

The first thing C++ needs to do is to import the external function declarations
we already wrote in the C headers. Because C++ linkage, like Rust linkage, does
not necessarily use the C ABI and also has name mangling, we must tell C++ that
the functions use the C ABI and do not mangle – the `extern "C" {}` scopes that
were `#ifdef`d away in the C headers.

We then tell C++ that all those names should not be in the global namespace, but
in the library namespace – the `namespace bv {}` scopes also in the `#ifdef`
guards.

Now we have a whole lot of functions, but no types to pass in to them. The
sixteen different structs in C are *awful* to use.

We want the following:

```cpp
template <class /* for now */ C, class T>
class BitSlice : public BitSlice {
public:
  // methods here
};
```

so then we can say `BitSlice</* something */, uint8_t> bs; bs.len();`

Since it’s illegal to have multiple types with the same name, I chose to prepend
`H` to all the C structs to indicate that they are `H`andles to indirect data.

Since the Rust library only exports two `Cursor` implementors, we can recreate
those in C++ with

```cpp
enum class Cursor {
  BigEndian = 0,
  LittleEndian = 1,
};
```

and make our class take `template <Cursor C, class T>`.

#### Defining Methods

My first instinct, not knowing anything about modern C++, was to laboriously
create sixteen monomorphs – eight each of `class BitSlice` and
`class BitSliceMut : public BitSlice` – and define methods on them that call the
C functions:

```cpp
template <Cursor C, class T>
class BitSlice : public HBitSlice {};

template <Cursor C, class T>
class BitSliceMut : public BitSlice<C, T> {};

std::size_t
BitSlice<BigEndian, uint8_t>::size(void)
const noexcept {
  return bitvec_bs_b08_len(this);
}

std::size_t
BitSlice<LittleEndian, uint8_t>::size(void)
const noexcept {
  return bitvec_bs_l08_len(this);
}
```

which, even with editor macros, was horrifically unpleasant.

#### Jumping Through Hoops and also Tables

I swiftly gave up and asked Twitter user [@strega_nil] for help, and thankfully
she knew what the hell she was doing and showed me some magic.

C++ has some *very* powerful compile-time programming abilities. For example, we
can compile all the monomorphs of the same function into a jump table:

```cpp
using len_t = auto(HBitSlice const *) -> std::size_t;
constexpr auto len = std::array<len_t, 8> {{
  reinterpret_cast<len_t *>(bitvec_bs_b08_len),
  reinterpret_cast<len_t *>(bitvec_bs_l08_len),
  // …
}};
```

and we can turn a `Cursor` variant and a storage class into an index in that
jump table:

```cpp
template <Cursor C, class T>
constexpr std::size_t jump(void) {
  return
    (static_cast<std::size_t>(
      __builtin_ctzll(sizeof(T))
    ) << 1)
    |static_cast<std::size_t>(C);
}
```

which computes the number of trailing zeroes in the byte count of each type (0,
1, 2, or 3, for `u8`, `u16`, `u32`, and `u64`, respectively), shifts up by one,
and sets the last bit true for little endian and false for big. This gives us a
number in `0 .. 8` for each combination of cursor and storage, computed at
compile time and const-folded at use.

```cpp
template <Cursor C, class T>
class BitSlice : public HBitSlice {
public:
  std::size_t size(void) const noexcept {
    return len[jump<C, T>()](this);
  }
};
```

During compilation, the `jump<C, T>` call is replaced with its computed value,
then `len[JUMP_C_T]` is replaced with the name of the function in that slot in
the `len` function array, and it becomes a flat function call. Since the table
entries are moved into their use sites, and the table sites are inaccessible to
user code because of namespacing, the tables get removed entirely, and only
the templates that are instantiated and their methods that are called appear in
the final program.

#### The Nobility of Inheritance

We still have a problem: the jump tables expect four different kinds of `this`:

- `HBitSlice *`: mut pointer to immut region
- `HBitSliceMut *`: mut pointer to mut region
- `HBitSlice const *`: immut pointer to immut region
- `HBitSliceMut const *`: immut pointer to mut region

but our class can only produce `HBitSlice *` in unqualified methods and
`HBitSlice const *` in `const`-qualified methods.

This is where [@strega_nil] brought out the really cool work:

First, she defined four functions:

```cpp
static HBitSlice const *
make_immut(HBitSliceMut const * self) {
  return &self->u.immut;
}
static HBitSlice const *
make_immut(HBitSlice const * self) {
  return self;
}

static HBitSlice *
make_immut(HBitSliceMut * self) {
  return &self->u.immut;
}
static HBitSlice *
make_immut(HBitSlice * self) {
  return self;
}
```

These turn any pointer to any handle into a pointer to the equivalent immutable
handle. They are the identity function when the handle is already immutable, and
are union manipulation in the C structure when the handle is mutable.

As it happens, these functions are purely type-level, and are the identity
function for address manipulation, so these calls *also* evaporate in
compilation.

Next, she really blew my mind: C++ lets you conditionally select your ancestor.

```cpp
template <Cursor C, class T>
class BitSlice : public std::conditional<
  std::is_const<T>::value,
  HBitSlice,
  HBitSliceMut
>::type {
  static_assert(
    std::is_integral<T>::value &&
    std::is_unsigned<T>::value
  );
};
```

That class decoration ties everything together: when `T` is `uintN_t const`, the
only methods available are those that do not mutate the referent data; when `T`
is `uintN_t` (not `const`), all methods are available. Each method only needs to
be declared once, in the class template:

```cpp
public:
  std::size_t size(void) const noexcept {
    return len[jump<C, T>()](make_immut(this));
  }
```

#### From Trampoline to Bouncy Castle

Lastly, just to really flex on me, [@strega_nil] folded that trampoline call into
a multiplexer function:

```cpp
template <
  Cursor C,
  class T,
  class Ret,
  class... Params,
  class... Args,
>
auto mux(
  std::array<
    Ret (*)(Params...) noexcept, 8
  > const& funcs,
  Args&&... args
) noexcept -> R {
  return funcs[jump<C, T>()](
    std::forward<Args>(args)...
  );
}
```

This beast, called as `mux<C, T>(table, make_immut(this), rest...);`, selects
the correct function from the table, then passes all the other arguments into
that function and returns the result. It typechecks that the looked-up function
takes the same parameter set as was invoked at the call site, and is evaluated
at compile time to be … just a function call.

Replace `table[jump<C, T>()](args...)` with `mux<C, T>(table, args...)` and now,
finally, the C++ API is finished.

And it *works*.

```cpp
#include <cstdint>
#include <iostream>
#include "bitvec/slice.hpp"

uint32_t arr[4];
bv::BitSlice<BigEndian, uint32_t> bs(arr, 4);
std::cout << std::boolalpha
          << "Bit 13: " << bs[13]
          << std::endl;
bs[13] = true;
std::cout << "Bit 13: " << bs[13]
          << std::endl;
std::cout << "The slice has " << bs.size()
          << " bits. "
          << std::endl;
```

Final C++ bindings: [`c/bitvec/slice.hpp`][slice-hpp].

### Beyond Bindings

The minimum functionality is achieved by creating C++ methods that correctly
call Rust functions exposed through the C FFI with the appropriate values. The
step from thin wrapper to native-feeling library is achieved by extra work, like
renaming Rust methods to the C++ convention (`size` instead of `len`, `at`
instead of `get`), implementing the correct constructors (every `::empty` and
`::from_something` in Rust is a constructor overload in C++), and then the
useful operators (such as `operator [](std::size_t)` for `Index<usize>`).

The effort I spent in making the Rust types match their standard-library
counterparts is mirrored by making the C++ binding types match *their* native
counterparts. I recreated the logic in Rust `bitvec`’s `slice::BitGuard` and C++
`std`’s `std::vector<bool>` that allows write indexing, and I am working on a
design for C++ iteration.

Every programming language has its own idioms for expressing common concepts.
I steadfastly refuse to *port* `bitvec` to other languages[^2], so in order for
other languages to have this functionality, I must provide them with types and
functions that can operate it.

Just as speaking German in an American accent, with American-English grammar, is
not speaking German, so too is dropping a bare list of types and functions or a
stubbornly Rustic API surface in the target language not speaking that language.

Each language I add to the project will have the same level of (best-effort)
thought and polish added to the provided interface. C++ users should not notice
any difference in their source code that makes them realize that `bitvec` is not
a C++ library, nor should any users of future languages.

## Panic! at the Callsite

Every `panic!` in Rust begins a routine that ultimately ends in the destruction
of the thread. In most programs, this works by unwinding the stack until the
thread terminates. A Rust function that begins a panic unwind, which was called
from a foreign-language stack frame, will cause that unwind to cross the
language boundary.

This is *extremely* undefined behavior.

The Rust reference [assures us][unwind] that during codegen, all `extern fn`
definitions are wrapped with an unwind trap that executes an illegal
instruction, causing immediate abort.

Since there are (at time of writing) 646 `assert!` statements in the `bitvec`
repository, most of them in the library proper, this assurance is necessary.

Still, it is probably worthwhile to compile with
`RUSTFLAGS=panic=abort,$RUSTFLAGS` when creating a library intended for foreign
linkage.

> This assurance is why the C++ binding methods were all marked `noexcept`: any
> exceptional circumstance would abort the program before C++ ever saw it, and
> thus the C++ compiler can remove any exception propagation machinery from
> these functions.
>
> Most of the `bitvec` functions do not signal failure in any manner except for
> unwind/abort. In the future, signaling failure and mapping error codes to
> local-language exceptions or other error propagation mechanisms would increase
> native integration and reduce the brittleness of the library’s use.
{:.bq-warn .iso7010 .w002}

## Conclusion

I hope I’ve shown that it’s not sufficient just to mark a Rust function as
`#[no_mangle] extern "C"` in order to make a project polyglot. Each language
supported by a project should have a native, idiomatic feel to it.

This means coming up with a least-common-denominator FFI boundary for other
languages to be able to interact with the Rust artifact. As long as the C-ABI
remains the *lingua franca* of inter-language calls, the Rust FFI surface will
need to be shaped to accomodate the broadest, simplest possible expression of
each operation. Each language can then wrap the FFI calls in local idiomatic
patterns.

This means knowing the destination language well enough – or better yet, knowing
someone who knows the destination language well enough – to create an API that
fits the language, and then maps the local concepts onto the Rust FFI surface.

Furthermore, not all concepts in the Rust library need to be moved through FFI.
While the core logic should certainly remain in one place, it is worth
remembering that FFI calls are at *minimum* a function call that can only be
optimized by the linker, and in many languages can wind up with considerable
overhead cost.

Creation of polyglot bindings to a library is as detail- and design- intensive
of a task as implementing the logic in each language in the first place. The
advantage is that with a Rust library, we have all the Rust language’s
guarantees of correct behavior and direct control, in addition to the convenient
local usage in any language that wishes to take advantage of this functionality.

\[^1\]: Without the user writing ugly code that shows them they’re misbehaving.
They’re free to do that, of course, but I did my best.

\[^2\]: I may have to translate it to C++, in order to use the library on the
MSP-430 which Rust cannot target, but the prospect of this fills me with
trepidation and fear. I certainly will not produce native ports in any *other*
language, *ever*.

[@strega_nil]: https://twitter.com/strega_nil
[`bitvec`]: /crates/bitvec
[build-rs]: https://github.com/myrrlyn/bitvec/blob/feature/ffi/rust/build.rs
[slice-rs]: https://github.com/myrrlyn/bitvec/blob/feature/ffi/rust/src/ffi/slice.rs
[slice-h]: https://github.com/myrrlyn/bitvec/blob/feature/ffi/c/bitvec/slice.h
[slice-hpp]: https://github.com/myrrlyn/bitvec/blob/feature/ffi/c/bitvec/slice.hpp
[unwind]: https://doc.rust-lang.org/reference/items/functions.html#extern-functions
