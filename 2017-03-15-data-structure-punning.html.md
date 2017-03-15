---
title: Data Structure Punning
date: 2017-03-15
tags:
- c
- computers
- computing theory
- rust
- software design
category: misc
---

1. ToC
{:toc}

# Introduction

I work in systems-level C for a living, and have reason to do some pretty
esoteric things with it. One of the strengths of C (I don’t, in fact, have
unadulterated hatred for it) is that it is a highly data-oriented language. When
it comes to representing memory in code, what you see is almost always exactly
what you get, with some few, reliable, caveats.

This is a stark contrast from almost every other high level language, especally
object-oriented ones, where the memory layout of large objects is both concealed
and not at all what one would expect.

One of the hallmarks of a system that deals with complex data is the ability to
combine one or more smaller objects into a larger one, much like building with
LEGO bricks.

## Type Punning

The term [*type punning*][1] refers to the practice of performing contortions in
both code and data to transmute an object from one type to another without
necessarily changing its underlying representation. This frequently requires
violating the letter of the type system’s rules while adhering to their spirit.
Much as in real life, such behavior is prone to getting one in trouble with the
law, but it is at times necessary.

One of the more famous and egregious instances of type punning is the [Quake
FISR hack][2], reproduced below in condensed form:

~~~c
float orig; // 32 bits
long i; // probably 32 bits on the original target

// This is the start of the type pun:
// 1 - take the address of the float:
//   &orig
// 2 - pretend that it points to a long:
//   (long*) &orig
// 3 - Copy that 'long' into i:
i = * (long*) &orig;

// This is the meat of the type pun:
// these operations cannot be done on
// a float, but are valid on a long
// that coincidentally has the same
// bit pattern.
i = 0x5F3759DF - (i >> 1);

// This is the end of the type pun:
// reverse the above process
orig = * (float*) &i;
~~~

The actual function does more work, but this is the interesting part for this
article.

The above example is hilariously unsafe and relies on hardware specifics about
the way floating point numbers are represented as bits according to the IEEE754
standard, and likely doesn’t work for all possible float values.

<aside markdown="block">
It also doesn’t compile anymore under `-Wall`. I copied it verbatim and didn’t
attempt to actually run it myself. I also wanted to use that exact notation
because that’s the syntax we’ll be using later with `struct` pointers, where C
is much more relaxed.

C’s firm glare of a warning in this case explicitly mentions type punning and
that a float can’t be stored in an integral type even if we try to sweet-talk
our way past the compiler like this. But this is C, and nothing is truly
forbidden. So we use a `union`, which lets us bypass silly things like alias
restrictions and interpret a bit pattern however we so please.

~~~c
float orig;
union { float f; long l; } u;
u.f = orig;
u.l = 0x5F3759DF - (u.l >> 1);
return u.f;
~~~

This was pointed out to me by some kind redditors and so I updated this post
with the *proper* way to break the rules.
</aside>

Type punning can also be used to reclassify structured data rather than raw
primitives, as I’ll show below.

# Structured Data in C

C uses a purely compositional model of data: `struct`s are types that are built
out of smaller items, which may be primitives or other `struct`s. Structure
types cannot be directly recursive, but they *can* contain pointers (a type
primitive) to other instances of their own type.

C has no concept of inheritance; unlike other languages we cannot use a larger
struct as if it were one of its component members … directly. However, the
state of C’s memory model lets us work type puns to mimic a highly simplified
form of mechanics that somewhat approximate inheritance in other languages.

## Composition in C

This section can be skipped if you’re already well acquainted with type punning
on C structures; I’m including it for any potential audience members who are not
and because my math teachers brainwashed me into showing **all** my work.

The base usage of a `struct` is to bundle related variables together. Suppose I
am implementing strings *correctly*: I have a length and a run of data. I can
tie them together like this:

~~~c
struct String {
    size_t len;
    char* text;
}
~~~

The `struct String` is a single object, two words long. If we have an instance
of it,

~~~c
struct String str;
~~~

then all elements in `str` stay together at all times. We’e just composed two
data primitives, an unsigned word integer and a pointer to bytes, together.

<aside markdown="block">
Note that the actual text isn’t in the `struct String` type. It’s “somewhere
else”, probably the heap, but we don’t really care here.

It’s also possible to store the text inline, by doing

~~~c
struct StringImmediate {
    size_t len;
    char text[];
}
~~~

but now the `struct StringImmediate` type is *unsized*, and the compiler will
assume that it’s two words long and if we want to access memory beyond it, that
is entirely our call but don’t blame it when we break things.
</aside>

Suppose we want to define some other object, say, a mailing address. This is
made up of a few different pieces of text. We might do this:

~~~c
enum UsState {
    Alabama,
    /* ... */
    Wyoming,
}
struct MailingAddr {
    struct String street_addr;
    struct String town;
    UsState state;
    int zipcode;
}
~~~

I used an `enum` for the states because we don’t actually need to store the
textual names of all fifty states in every single address; we just need a common
code we can use to look up those details. This is exactly the purpose for which
C `enum`s are built: give a name to a number, so we can use that number as a
shorthand for the full name and any assoociated data.

Now let’s suppose we might want to describe a person. People have names and
addresses, so we can build a person like this:

~~~c
struct Person {
    struct String name;
    int birthday;
    struct MailingAddr addr;
    /* maybe more data */
}
~~~

This is an excellent shorthand for what the `struct Person` actually looks like
in memory:

~~~c
struct PersonExploded {
    size_t name_len; // 4 or 8 bytes, depending on system
    char* name_text; // 4 or 8 bytes
    int birthday; // almost always 4 bytes anymore
    //  on a 64-bit system, the next four bytes might be skipped
    size_t addr_street_addr_len; // 4 or 8 bytes
    char* addr_street_addr_text; // 4 or 8 bytes
    size_t addr_town_len; // 4 or 8 bytes
    char* addr_town_text; // 4 or 8 bytes
    int addr_state; // enums are transparently ints (4 bytes)
    int addr_zipcode; // 4 bytes
    /* maybe more data */
} // at least 36 or 60 bytes, maybe more with padding
~~~

I for one am glad data composition exists in C. Writing that all out by hand is
a recipe for bugs and disaster.

# Structure Punning

C’s memory model states that structures and arrays have no secret members. This
means that for any given structure or array with some address `A`, the first
element within that structure or array also has the same address `A`.

<aside markdown="block">
This is why C arrays start from 0. The array member syntax `arr[idx]` is syntax
sugar for `*(arr + (idx * size))`.

~~~c
int arr[4]; // 16 bytes of memory
printf("%p", arr); // some address A
printf("%p", &arr[0]); // the same address A
printf("%p", &arr[1]); // A + 4

char* pa = arr;
bool t = (pa + (2 * 4)) == &arr[2]; // true
~~~

The C compiler secretly multiplies offset by width for you when working with
pointers, so `arr + 1` where `1` counts `int`s, is actually `arr + 4` where `4`
counts bytes.

~~~c
bool t2 = &arr[3] == arr + 3; // true
~~~

<aside markdown="block">
Addition is reflexive. $$a + b$$ is identical to $$b + a$$. So the C arithmetic
`base + offset` is equivalent to `offset + base`.

You may be ahead of me. If not, remember that in C, `*(base + offset)` is also
written as `base[offset]`.

~~~c
int d = 3[arr];
//  fetches arr[3]
~~~

This is totally valid C.
</aside>
</aside>

Say we have a `struct Person` and a function that only needs a `struct String`.
A person struct can become their name struct very easily:

~~~c
struct Person p;
struct String* pname = &p;
~~~

This works because the address of `struct Person p` is also the address of
`struct String p.name`.

Similarly, if we have a pointer to a `struct String` that we are *absolutely*
*sure* is pointing at the `name` field of a `struct Person`, we can cast the
type and voila, a `struct Person*` appears!

~~~c
pname->birthday;
// ERROR: struct String has no field `birthday`
struct Person* pperson = pname;
pperson->birthday;
//  Just fine.
~~~

Even though the *value in memory* of the pointer didn’t change, our expectations
and behavior did (this is a direct sequel to my last post; if you haven’t, go
read). This let us seamlessly access fields of a `struct Person` even though we
were handed a pointer that thought it only went to a `struct String`.

<aside markdown="block">
“Hold up,” you may be thinking, “you just took a pointer that could only
guarantee two words of data at its end, and tried to read a third!”

(If you weren’t thinking that, that’s okay, but you *should be*.)

That is in fact exactly what happened. So what if we were wrong? What if that
`struct String*` didn’t aim at a `struct Person` after all?

The answer is ***memory safety violations***. If you’re lucky, you’ll be aimed
at a `struct Person` and this will be okay. If you’re slightly less lucky,
you’ll leave the memory you own, the OS will get mad at you, and your program
will crash.

And if you’re very very unlucky, you’ll gaily access memory you own but
shouldn’t divulge and expose information that shouldn’t be exposed.

Hello, welcome to C, and a good third of all the CVE bugs filed over the last
forty years including disasters like [Heartbleed][3] and [Cloudbleed][4].

This is why I rant about C being recklessly unsafe.
</aside>

Ignoring the aside above about memory safety (a sentence I hope never to write
again as long as I live), type punning like this is at times necessary, and in a
controlled environment, safe. (For certain, not-100%, values of safe.)

## Example Use Case

I write device drivers for an operating system. These drivers require lots of
aggregate information. It looks something like this:

~~~c
struct DevFuncs {
    /* seven function pointers */
}
struct DevHdr {
    /* OS information */
}
struct Device {
    struct DevFuncs vtab;
    struct DevHdr info;
    struct String name;
    /* more data */
}

struct Device devices[16];
~~~

The OS requires that I register my devices with it, but it only knows about
function tables and device headers. It neither knows nor cares what else I
compose into my `struct Device` record; it just wants function tables and device
headers in the format it expects.

So I register all sixteen devices by giving the kernel pointers to the function
table, and to the device header, as it requires.

Later on, the kernel will invoke the functions listed in the table, passing a
`struct DevHdr*` pointer as the first parameter. This pointer is always
guaranteed to belong to the same `struct Device` as the function in the table
being invoked.

This means that, whenever my functions see a `struct DevHdr*` pointer, they know
that it is aimed at a member of a `struct Device`, and in that `struct Device`
is information they need.

So it’s fine for me to attempt to turn a `struct DevHdr*` pointer into a
`struct Device*` pointer. I can’t do it implicitly, though, because the header
isn’t the first element (an unfortunately necessary design requirement).

I do, however, know what the layout of a `struct Device` is, so I know that if I
have a pointer to a `struct DevHdr`, then a `struct Device` begins a fixed
number of bytes before it.

~~~c
struct DevHdr* pdh; // given to us by the kernel
struct Device* pdev = (void*)pdh - sizeof(struct DevFuncs);
~~~

This is a seriously risky hack that only works because the C standard mandates
that structures are as packed as can be. This isn’t perfect: If, for some
reason, there was implicit padding space between the `vtab` field and the `info`
field, this would fail.

I don’t know offhand if C will permit `sizeof(Device.vtab)` as a type, but that
would be the safest way.

But it works. I can take a pointer aimed inside a larger structure and rewind it
to point at the entirety of the larger structure rather than one component.

Note that the security concern form above applies here in full force. If the
assumptions about the original pointer are untrue, this will cause *flagrant*
violations of memory safety.

## Safer Type Punning

I prefer Rust as a systems language for many reasons. It has its tradeoffs from
C, but by and large it is a worthy peer.

Rust uses structs exactly like C does to organize and compose data.

Rust does not, however, provide a guaranteed memory model. So the above pointer
arithmetic only works on structures marked as `#[repr(C)]`.

Instead, Rust has a powerful system based on *type patterns*. It permits working
with pieces of a structure and ignoring the rest, for example, and uses patterns
to express both concrete memory and abstract types.

If Rust is going to integrate with C (a stated goal of theirs), it will have to
support weird use cases like the decomposition I just described in order to work
in every case C does.

Since we neither want to, nor are able to, use pointer arithmetic to accomplish
this in Rust, I envision a system that leverages the language’s powerful pattern
system and the compiler’s excellent ability to trace existence and reference
viability.

## Reference Destructuring in Rust

Let us envision the structure described above in Rust:

~~~rust
#[repr(C)]
pub struct DevFuncs {
    /* function pointers */
}
#[repr(C)]
pub struct DevHdr {
    /* device header */
}
pub struct Device {
    pub vtab: DevFuncs,
    pub info: DevHdr,
    pub name: String,
    /* more */
}

static devices: [Device; 16];
~~~

When we register the `Device`s with the operating system, it can only accept the
function table and the device header, so we simply destructure the `Device`
instance just enough to obtain interior references, like so:

~~~rust
for dev in &devices {
    let num = osRegisterDrivers(&dev.vtab as *const c_void);
    osRegisterDevice(num, &dev.info as *const DevHdr);
}
~~~

We give the OS functions pointers to our struct sub-members. Due to Rust’s
memory model not yet being finalized, we do not **know** that the pointer to the
function table is bit-for-bit identical to the pointer to the whole device
struct, nor do we know that the pointer to the device header is exactly seven
words beyond the pointer to the function table – and even if we did, that still
wouldn’t help us, as already stated.

So how can we do upwards type punning in Rust? Downwards type punning is simple:
references to interior structs are cheap if not free.

Current Rust doesn’t support this at all, for obvious and excellent reasons.
It’s risky, dangerous, and many other synonyms that all essentially mean “if you
do this, puppies and your MMU will cry.”

But just as Rust isn’t C, it also isn’t Java. We can do dangerous things as long
as we pinky promise to be careful and plan ahead.

## Reference Restructuring in Rust

To briefly summarize everything I've outlined so far, I am describing a
situation where our code receives a reference to an interior member of a struct,
and wishes to access the larger struct of which the *referent* is a member.

Essentially, we are given a reference `r: &Child` referring to some `Child` in
memory. We presume that this child referent is in fact residing within a larger
`Parent` struct, so the memory layout looks something like this:
`Parent { ... Child { ... } ... }`. While at the source code level we may not
know the exact offset between the start of the `Parent` and the start of the
`Child`, the compiler *does*.

Therefore, I propose a syntax similar to Rust’s pre-existing syntax for struct
decomposing.

<aside markdown="block">
~~~rust
struct  Foo { foo: i32, bar: i32, baz: i32, }
let f = Foo { foo: 1, bar: 2, baz: 3, };
let f = Foo { foo: -1, .. f };
// f is Foo { foo: -1, bar: 2, baz: 3, }
~~~
</aside>

If we have two types `Parent` and `Child` defined such that

~~~rust
struct Parent {
    /* ... */
    c: Child,
    /* ... */
}
~~~

and some reference `c: &Child` that we have reason to believe refers to a
`Child` embedded within a `Parent`, then we can translate the `&Child` reference
to an `&Parent` reference via the following syntax:

~~~rust
let p: Parent = Parent { c: Child { /* ... */ }, /* ... */ };
//  later
let rc: &Child = &p.c;
unsafe {
    let rp: &Parent = &Parent { c: *rc, .. };
}
~~~

The final line is a programmatic statement of the following logic:

> For some element referred to by `rc`, there exists some super element laid out
> in such a way that its member element `c` is the referent of `rc`, and we can
> obtain a reference to that super element by knowing the relationship between
> the two. However, as such an assumption is not always possible to verify, we
> must flag it as `unsafe` and take responsibility for memory safety ourselves.

This leans on Rust’s proclivity for pattern-based type checking. We need perform
no pointer arithmetic to backtrack from the child reference to reach the parent
reference, as we do not have the information required to do so. Furthermore,
this enables the compiler to assist us by asserting that the new reference is of
a valid type (we can’t build a parent reference by starting from something that
isn’t a child type) and potentially to add compile- or run- time checks that the
child referent does exist inside the parent referent and that all the lifetimes
and validity work out.

This may not always be possible for the compiler to prove (especially in my
example usage, where the child reference arrives from a foreign function and
cannot be provably backtraced to the origin in its parent object), so this
syntax requires an `unsafe` block in order to permit compilation of code that
may well cause memory violations.

# Conclusion

Structured data permits programs to keep related information close by without
requiring more complex tricks such as mutual pointers and permits programs to
add information to data groups that was unnecessary when the APIs were initially
written.

However, this comes with the downside that APIs which only operate on parts of a
record at a time require some risky behavior to reconstruct the full data item
from an interior pointer.

This pattern is useful enough and is at least somewhat prevalent in the areas
where Rust intends to live that I am of the opinion that having language-level
support for such practices would be useful.

The syntax I described above has the additional advantages of being type-sound
and partially verified at compile time, and decouples the source code from the
exact memory model of the record types. This is only partially accomplished in C
– multiple preceding members and surprise padding can both introduce edge cases
in the C method of structure punning – whereas the Rust version uses semantic
patterns and permits the compiler free reign to arrange `struct` memory layouts
as it sees fit for best usage.

Furthermore, the Rust syntax has the advantage that hints can be provided for
the compiler to indicate reference validity. For example, if this is being done
in a fully-Rust codebase to which the compiler has full source code access, it
may be able to trace the path of reference travel from registration through
retrieval. In the case of black-box foreign functions, it may be possible to add
annotations to the functions that give out and receive these references, so that
the compiler will assume that any received references are identical to those
handed out and that it can link them for checking type and lifetime validity.

Example syntax:

~~~rust
struct Bar { /* ... */ }
pub struct Foo {
    name: String,
    bar: Bar,
    id: i32,
    bar2: Bar,
    }
extern {
    fn register_bar(&Bar);
    fn register_bar2(&Bar);
}

static foos: [Foo; 16];

for foo in &foos {
    #[ref_send(Foo)]
    register_bar(&foo.bar);
    #[ref_send(Foo)]
    register_bar2(&foo.bar2);
}

//  later

#[ref_recv(Foo)]
fn do_thing(rbar: &Bar) {
    let rfoo: &Foo = &Foo { bar: *rbar, .. };
}
#[ref_recv(Foo)]
fn do_other_thing(rbar: &Bar) {
    let rfoo: &Foo = &Foo { bar2: *rbar, .. };
}
~~~

The `#[ref_send(Type)]` markers inform the compiler that while the base type
check of the functions indicates that they send out references to child types,
those references are statically known to refer to objects embedded in a larger
type.

The `#[ref_recv(Type)]` marker informs the compiler that while the base type
check of the function indicates that they receive a reference to some child
type, that reference is statically known (presuming correctness in the travel
path) to refer to objects embedded in a larger type.

This behavior is **required** to be marked `unsafe` when these markers cannot be
provided, and may still require an `unsafe` marker even with them present. It
**cannot** ever be assumed to be safe by default, as a black box function cannot
be proven to provide valid references even if our code appears to distribute
valid references.

The compiler can then (reasonably) safely permit construction of a reference to
the enclosing type using the given pattern. This even permits correct
reconstruction when the enclosing type has more than one element of a given
type, as shown. We specify which field of the parent type is referred to by our
given reference, and the compiler will backsolve the struct pattern to make
everything work out.

Internally, when the compiler builds a struct it must know the size, alignment,
and offset of each member field in order to permit member access. This means
that it can solve the layout in reverse: given the address of a member and the
full layout information of the parent type containing that member, it can solve
the memory layout of the parent instance that will satisfy the constraint of a
member instance at a fixed location.

## Summary

Access to the interior of structs is a necessary part of systems programming. C
permits, and many environments make use of, the ability to upcast pointers from
a child element to its owning type by taking the difference of the interior
pointer and the offset from the start of its owning type. This is implicit when
working with the zeroth element in C types due to C’s fixed memory model.

Such behavior is highly dangerous and brittle, however necessary it may be. In
Rust’s mission to add safety to systems programming and to tread cautiously in
all places where C has rushed in, Rust will need to support this kind of
upcasting from a child reference to a parent reference.

Rust already has the foundations laid in both its syntax and its compiler
mechanisms to add sanity guards to this behavior. The use of patterns in syntax
permit powerful and safe abstractions of the child/parent relationship in source
code, and the compiler’s ability to trace reference and lifetime status, combine
to create a rich potential for managed data structure punning. If implemented,
the end result should rival C in performance, and absolutely surpass it in
expressiveness and safety.

[1]: https://en.wikipedia.org/wiki/Type_punning
[2]: https://en.wikipedia.org/wiki/Fast_inverse_square_root
[3]: https://en.wikipedia.org/wiki/Heartbleed
[4]: https://en.wikipedia.org/wiki/Cloudbleed
