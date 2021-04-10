---
title: How Computers Work
date: 2016-11-14
tags:
- computers
- computing theory
summary: |
  A general introduction to computing and the topics I intend to cover in more
  depth in following posts.
---

Computing is an incredibly complex and detailed topic, and one about which I’m
both passionate and reasonably well-informed. I’ve had some remarks about how
they work received well previously, even getting requests for a blog series
about it.

Well, actually, the commenter was asking if I had a YouTube channel, but I can’t
get into videos to save my life, so, I’m writing instead. Maybe one day I’ll
narrate something. Who knows.

## Series Overview

Modern computing uses a stack metaphor rather extensively, and for good reason.
My goal with this is to have a series of articles, each of which covers one part
of the stack, and will have a general discussion about where it fits in the big
picture, and a more detailed discussion that (ideally) will not require reading
the other articles to grasp it.

### General Knowledge

One of the hazards of specialization is that jargon and technical information
become common knowledge to me, so I lose track of what is or isn’t actually
common knowledge. I will strive to avoid using such terms carelessly, and to
clearly define all the necessary terms when they are first encountered. Since I
have yet to set up a commenting system on this site, feel free to write me by
email or any other means with questions or followups of any kind.

Without further ado, let’s begin.

## Historical Background

In the general sense, a computer is any device which is capable of manipulating
information to suit a human’s purpose. The abacus could be included in this
category as a very early, primitive computer, as it assisted humans in
performing arithmetic.

### Mechanical Computation

However, the modern sense of the word “computer” is a narrower category, whose
first entry is [Charles Babbage]’s [difference engine]. This was a machine which
was built and engineered specifically to translate mechanical state into
mathematical results. Put simply, the user would set up the machine with the
desired input state, crank it, and the machine’s construction and mechanical
linkage would eventually result in a numeric answer.

The Babbage difference engine, although capable of performing remarkable feats
of mathematics, was a non-programmable, single-purpose device whose execution
behavior is defined directly by its construction. The difference engine could
only perform the one algorithm it was designed to run.

Babbage’s next project was to design an [Analytical Engine] which would be able
to perform more general computation controlled by punched cards.

The design for the Analytical Engine included an arithmetic and logic unit, a
control flow processor capable of executing conditional statements and loops,
and persistent memory. These are the necessary elements of computing that would
later be formalized as “[Turing completeness]”, making the Analytical Engine the
first true general-purpose computer, and the ancestor of all modern computers.

If Charles Babbage is the first computer engineer, for designing the first fully
general-purpose computer, then the first computer scientist is [Ada Lovelace],
for designing the first algorithm specifically designed to be executed by a
hardware computer rather than a human being.

Babbage’s Analytical Engine was never built, nor was Lovelace’s algorithm ever
executed, but their work in mechanical computation and mathematics laid the
foundation for the birth of electronic computation nearly a century later.

### Universal Computation

The invention and deployment of telegraph and telephone networks in the late
19<sup>th</sup> century provided the groundwork for electronic systems control.
I will expand on this topic more in a future post.

The formal theories behind general-purpose computation were described in the
mid-1930s independently by [Alonzo Church]’s [lambda calculus] and
[Alan Turing]’s concept of the [Turing machine]. The set of logical behaviors
used to implement computation were described by [George Boole] in the 1850s.

#### Lambda Calculus

I’m going to briefly talk about theoretical mathematics. Don’t worry if you’re
not a “math person” or my usage of the word “calculus” worries you; this *isn’t*
the calculus of which you’re thinking (that’s Newton/Leibniz calculus and
nothing like what I’m covering) and I won’t be talking about it very much. I
encourage you to read this section and the future article, but it’s fine if you
skim or skip.

The lambda calculus (or λ-calculus) is a formal mathematical system for the
notation and analysis of mathematical algorithms. It describes a universal model
of computation, and provides the abstract mathematics governing the operation of
Turing machines.

The lambda calculus models information as three things: *terms*, *abstractions*,
and *applications*. A term is a variable name or constant, such as $$x$$ or
$$2$$. An abstraction is a function definition which transforms a term into
another term, or another abstraction. An application *applies* an abstraction to
a term, and reduces to the abstraction’s output when solving the system.

This is useful because it provides a theoretical model that maps *exactly* to
how universal computing devices work, and allow for formal mathematical proofs
of a program’s correctness. Every possible computation can be modeled on a
whiteboard using lambda calculus, which means that programs can be solved on a
whiteboard and shown to succeed or fail (…mostly.)

#### Turing machine

A *Turing machine* is a theoretical model for a machine which follows a certain
set of rules for its behavior. A machine is said to be *Turing complete* if, by
following these rules, any action and computation may be reached.

A Turing machine has:

- An infinite memory from which it can read and to which it can write
- A set of possible internal states
- A list of instructions

It works by:

- Selecting a single cell from memory and reading it
- Executing the instruction appropriate for the combination of read memory and
  internal state
  - Writing a new value to that memory cell
  - Selecting a new internal state
  - Selecting a different memory cell

Turing machines are *discrete*, *finite*, and *distinguishable*. This means that
it can not operate on, nor select, fractions of a cell; it has a limited amount
of symbols on the memory it can process and a limited amount of internal state,
and that each symbol and state are clearly distinct from all others. The
completeness of a Turing machine comes from its infinite supply of memory and
time of operation.

The importance of this concept, as well as that of the lambda calculus, is that
together they define a formal model of general-purpose computation and the
necessary properties of machines that can implement it.

#### Boolean Algebra

[Boolean algebra] is a set of mathematical rules that mix logic and arithmetic.
It defines three fundamental operations, `AND` ($$\land$$), `OR` ($$\lor$$), and
`NOT` ($$\lnot$$), which can be combined to implement any logical transformation
of data. The logical operators act on binary symbols, *true* and *false*. These
can be represented as *1* and *0*, respectively.

| $$A$$ | $$B$$ | $$A \land B$$ | $$A \lor B$$ | $$\lnot A$$ |
| :---: | :---: | :-----------: | :----------: | :---------: |
| $$0$$ | $$0$$ |     $$0$$     |    $$0$$     |    $$1$$    |
| $$0$$ | $$1$$ |     $$0$$     |    $$1$$     |    $$1$$    |
| $$1$$ | $$0$$ |     $$0$$     |    $$1$$     |    $$0$$    |
| $$1$$ | $$1$$ |     $$1$$     |    $$1$$     |    $$0$$    |

There are other Boolean operators that can be defined as combinations of these
fundamentals: `XOR` ($$\oplus$$), `XNOR` ($$\equiv$$), `NAND`
($$\overline{\land}$$), and `NOR` ($$\overline{\lor}$$).

| $$A$$ | $$B$$ | $$A \oplus B$$ | $$A \equiv B$$ | $$\overline{A \land B}$$ | $$\overline{A \lor B}$$ |
| :---: | :---: | :------------: | :------------: | :----------------------: | :---------------------: |
| $$0$$ | $$0$$ |     $$0$$      |     $$1$$      |          $$1$$           |          $$1$$          |
| $$0$$ | $$1$$ |     $$1$$      |     $$0$$      |          $$1$$           |          $$0$$          |
| $$1$$ | $$0$$ |     $$1$$      |     $$0$$      |          $$1$$           |          $$0$$          |
| $$1$$ | $$1$$ |     $$0$$      |     $$1$$      |          $$0$$           |          $$0$$          |

The `NAND` and `NOR` operators are especially interesting, in that they are each
*functionally complete* – that is, all other Boolean operations can be created
out of combinations of only `NAND` or only `NOR` operators. Coincidentally,
`NAND` and `NOR` logic gates are incredibly easy to make with modern
transistors, so modern computers are usually built entirely out of `NAND` logic
or `NOR` logic.

### Electrical Computation

There are several problems with mechanical general-purpose computers, including
size, speed (or rather the lack), and power consumption.

#### Engineering

The advent of the telegraph and electrical signaling resulted in the discovery
that switching relays could be combined to implement basic Boolean logic. If
you’ll remember grade school electrical science, you’ll remember that there are
two basic kinds of circuit layout: serial and parallel. Switches in series must
all be closed to permit current to flow – an `AND` gate. Switches in parallel
must all be open to forbid current to flow – an `OR` gate. A `NOT` gate can be
created simply by reversing how a switch responds to an input signal. With these
three Boolean primitives, an electronic Turing computer can be assembled
according to equations in the lambda calculus.

At first, these [computers] were built using mechanical switches and plugs
operated by human secretaries. The development of vacuum tubes improved their
operation, although the computers were still large, slow, and power-hungry.

It wasn’t until [William Shockley] invented the first [transistor] in 1947 that
computers were able to begin making significant advances in size, complexity,
and self-manipulation. Since transistors are still in use today, I will delve
more into their operation in a future article.

#### Architecture

There are two overarching kinds of computer: those which keep their programming
separate from their data, and those that do not. The former class is referred to
as the [Harvard architecture], and the latter as [von Neumann machines]. All
computers, from Babbage’s Analytical Engine onwards, were Harvard-type machines
until after the invention of transistors allowed computers to use the same
signals and pathways for instruction programming as for data processing.
Transistors are unlike any other computing element in that they both govern, and
are controlled by, simple electrical voltages. Like a complex rail network with
pressure-operated switches, so that tracks could be rearranged by the trains
traveling across them, transistors can be constructed such that the data flowing
through them alters the layout of the whole circuit.

Most modern computers use the von Neumann architecture, though many smaller
devices such as embedded microcontrolelrs use the Harvard architecture, as it is
often cheaper.

## Conclusion

These topics provide the theoretical and engineering background on which
computers are built, but I’m probably not going to touch on them very much, if
at all, in future articles. They’re good to know, and provide some useful
context, but if you skimmed or skipped them you’re not going to be overly
penalized later. Since one of my goals of this series is to have each layer be
more or less self-contained, it shouldn’t matter very much which topics you read
and which you skip.

[Ada Lovelace]:         https://en.wikipedia.org/wiki/Ada_Lovelace
[Alan Turing]:          https://en.wikipedia.org/wiki/Alan_Turing
[Alonzo Church]:        https://en.wikipedia.org/wiki/Alonzo_Church
[Analytical Engine]:    https://en.wikipedia.org/wiki/Analytical_Engine
[Boolean algebra]:      https://en.wikipedia.org/wiki/Boolean_algebra
[Charles Babbage]:      https://en.wikipedia.org/wiki/Charles_Babbage
[computer]:             https://en.wikipedia.org/wiki/Computer#Digital_computers
[difference engine]:    https://en.wikipedia.org/wiki/Difference_engine
[George Boole]:         https://en.wikipedia.org/wiki/George_Boole
[Harvard architecture]: https://en.wikipedia.org/wiki/Harvard_architecture
[lambda calculus]:      https://en.wikipedia.org/wiki/Lambda_calculus
[transistor]:           https://en.wikipedia.org/wiki/Transistor
[Turing completeness]:  https://en.wikipedia.org/wiki/Turing_completeness
[Turing machine]:       https://en.wikipedia.org/wiki/Turing_machine
[von Neumann machines]: https://en.wikipedia.org/wiki/Von_Neumann_architecture
[William Shockley]:     https://en.wikipedia.org/wiki/William_Shockley
