---
title: Processors
date: 2016-11-17
tags:
- computers
- electronics
- digital design
category: How Computers Work
number: 2
---

In the previous post, I talked about how transistors work and how Boolean
algebra can be implemented using them. The details of that are not required to
read this article, but it may help.

I also mentioned the concept of *composability* without giving it a formal
definition.

A *module* is an element of hardware or software with a defined interface and
functionality. A module is *composed* of smaller elements, and these may be
other modules or fundamental units. For our purposes, the fundamental units are
now logic gates –  how logic gates are constructed is an electrical engineer’s
problem.

Two modules which have the same interface (set of inputs and outpus) and overall
functionality (emit the same output for the same input states) can be
interchanged without affecting the rest of the design. This is an important goal
for designing and selecting modules for use, as there are always performance
characteristic tradeoffs to be made. Some may be faster; some may use fewer
transistors; others may have less surface area. The best module for a specific
scenario can be chosen without having to rework everything connected to it, if
a standard interface is used.

I am mainly going to discuss the CPU here, but the principles apply to any
processing device, including *peripheral devices* (single-purpose computers
controlled by a CPU, which provide real functionality such as storage or
transmission).

1. ToC
{:toc}

# CPU Components

In order to determine what should go in a CPU, we first need to identify what it
is.

The most basic functionality of a CPU is this: it is an element of hardware that
is capable of performing mathematical or logical operations on input data, and
emitting the result as output.

Let us begin there, at the module called the **Arithmetic/Logic Unit** (ALU).

# ALU

The ALU is essentially a multi-function calculator. It has two main input
*buses* and one main output *bus*. These buses must all have the same width; for
the purposes of this article, I will be using 8-bit buses.

<aside markdown="block" class="terminology">
- A *bus* is a collection of *wires*.
- A *wire* is an electrical pathway which carries one *bit* of information.
- A *bit* is a single **b**inary dig**it**. It can be either `1` or `0`.
</aside>

The first functions to construct for the ALU are the logic functions. These are
simple: pick the operations to implement, and then create them in parallel.

<aside markdown="block" class="terminology">
Multi-bit signals are given names and widths, and can be referred to by the name
alone, which implies the full width, or as a slice. Slices look like this:
`Name[high:low]`, for wide slices, or `Name[bit]` for single-bit slices.
</aside>

## Logic

Let us implement the three Boolean fundamental operations: `AND`, `OR`, and
`NOT`. While we can ask our electrical engineers to make 8-bit-wide logic gates,
this has performance penalties, so we will use eight 1-bit-wide gates in
parallel.

- `A[7:0] & B[7:0] => Y[7:0]`

becomes

- `A[7] & B[7] => Y[7]`
- `A[6] & B[6] => Y[6]`
- …
- `A[1] & B[1] => Y[1]`
- `A[0] & B[0] => Y[0]`

and then the individual output wires recombine into the output bus.

This implements Boolean-`AND` logic, but we have yet to implement any of the
others. We do exactly the same pattern for Boolean-`OR`, swapping out gates, so
now we have sixteen logic gates in a line: eight `AND` and eight `OR`, with each
bit of `A` and `B` inputs splitting to go to two gates, and each output from the
gates converging back to a single bit of `Y` output.

This is the part where you stop and ask how we resolve contention between two
different logic gates. Suppose that an `AND` gate asserts low voltage while the
`OR` gate on the same line asserts high voltage. The continuous connection from
high voltage coming out of `OR`, into `AND`, and thence into `GND`, will not
only waste power, but also destroy the logic gates.

## Selection

The solution to this problem is called a *multiplexer*. A multiplexer is a logic
element which is capable of acting like a railway switch: multiple input buses
enter the device, which uses `AND` gates to only connect one of them to output.

<aside markdown="block" class="terminology">
If you’re interested, the formula for a mux is
$$Y = (A \land S) \lor (B \land \lnot S)$$, or `Y = (A & S) | (B & ~S)` in C
syntax.
</aside>

There also exists a demultiplexer, which is just a multiplexer facing backwards.
One input bus comes in, and gets routed among different output buses. We’ll get
back to that later.

So we put a 2:1 8-bit multiplexer between the logic gates and the *actual*
output bus, and use a 1-bit selector line to switch the multiplexer back and
forth. When the selector line is high (`1`), one of the operations is chosen to
pass to output; when the selector line is low (`0`), the other operation gets to
write.

Do note, however, that in our current design, the ALU is performing *both* the
`AND` and the `OR` operation simultaneously. This means that we are powering two
calculations, but only using one. This wastes power, and is not ideal.

This is where the demultiplexer comes in: put it in front of the collection of
logic operators, and tie it to the same select line that controls the
multiplexer on the output, and now the input signals will be routed through only
one logic cluster, and the rest lie dormant.

Now that we’ve solved the problem of selecting between multiple operations,
let’s add in the `NOT` operator. Remember that `NOT` is a *unary* operator (that
is, it only takes one argument. `AND` and `OR` are *binary* operators, meaning
that they take two arguments. It has nothing to do with the fact that Boolean
logic only has two symbols), so we only connect the `A` input to it.

This is three operation clusters, but our multiplexer only supports two!

### Composition

This is where composition becomes most useful. We have established that a 2:1
multiplexer (mux for short, henceforth) and 1:2 demultiplexer (demux) are a
simple enough construct, with a 1-bit selection line and n-bit selection buses
(we frankly don’t care what the bit width of a multiplexer is, since it has no
bearing on its actual operation, as long as all our data goes through).

So, suppose you want to select between more than two things. What do you do?

You take a 2:1 mux, and have each of its inputs be… another mux! This is a
“binary tree” structure, and it’s extremely common in computing.

##### Multiplexer Tree

It looks something like this:

~~~text
     ┌─────┐             |
══A══╡     │          S[1:0]
     │ mux ╞══Y0══╗      │
══B══╡     │      ║      │
     └──┬──┘      ║   ┌──┴──┐
        └────┐    ╚═══╡     │
             ├──S0────┤ mux ╞══Y══
        ┌────┘    ╔═══╡     │
     ┌──┴──┐      ║   └─────┘
══C══╡     │      ║
     │ mux ╞══Y1══╝
══D══╡     │
     └─────┘
~~~

As you can see, every doubling of input buses only requires one more selector
line. The new selector line controls where the end mux looks, while the old
selector line gets forwarded to each leaf (left) mux.

<aside markdown="block" class="terminology">
The downside of binary tree structures is their *overhead*. A 4:1 mux has three
internal buses which are not part of the interface, and rather than being a
single unit, is three.

An 8:1 mux consists of two 4:1 muxes connected to a 2:1 mux. This structure has
two 2:1 muxes sitting in the internal logic, not part of the interface at all,
as well six internal paths.

<aside markdown="block" class="terminology">
The expense formula for binary trees is both incredibly simple (make one and
count) and also requires Calculus II. This is the calculus; I’m throwing it in
as a bonus and you can skip this if you want; I will only reference it one time.

If you take a sum, starting at some number and successively adding half of that
to your result, your sum approaches twice the starting number.

$$\sum_{k=0}^{\infty}\frac{1}{2^k} = 2$$

If you have an n-bit-wide binary tree, you wind up with $$2^n - 1$$ nodes in the
tree. This formula uses $$log_2{n}$$ to compute the *depth* of the tree, and
accumulates the width of the tree at each level. Since each level closer to the
root has half as many nodes as the previous root, we wind up following the above
series to a finite end.

$$\sum_{k=log_2{n}}^{0}2^k = n + \frac{n}{2} + \frac{n}{4} + \frac{n}{8} + ... + 8 + 4 + 2 + 1 = 2^n - 1$$

Deep trees have a *lot* of middleware that links them together, but performs no
user-facing work.
</aside>
</aside>

Suppose you want to mux 8 things? You take two of these, slap a 2:1 mux between
them, and now you're done. The lower two bits of the now-three-bit select line
get forwarded to each 4:1 mux, while the new highest bit switches the new root
(right) mux.

Repeat ad nauseum for multiplexing more things. Yay modular composition!

A demux system works the exact same way, only flowing right to left in the above
diagram rather than left to right. As long as the select buses for both the
demux and mux are properly synchronized, traffic flow through the whole system
is seamless, and it appears from the outside as if the logic operators are
swapped out on the fly.

##### Braced ALU Core

~~~
     ┌─────┐     ┌─────┐
     │ 1:2 ╞══A══╡ AND │
     │  d  ╞══B══╡     ╞══Ya══╗   ┌─────┐
══A══╡  e  │     └─────┘      ╚═══╡ 2:1 │
══B══╡  m  │     ┌─────┐      ╔═══╡ mux ╞══Y══
     │  u  ╞══A══╡  O  ╞══Yb══╝   └──┬──┘
     │  x  ╞══B══╡  R  │             │
     └──┬──┘     └─────┘             │
──S─────┴────────────────────────────┘
~~~

<aside markdown="block" class="terminology">
The usage of early-alphabet letters starting from A as input, the S for select,
and the Y for output is an informal convention that I will be (mostly) keeping
throughout the series.

The usage of X and Z are discouraged as variable names, because they refer to
the other two Boolean states.

Other two Boolean states? Yes, I lied, a little bit. Circuit analysis has four
possible values of a digital line at any point: `1` (logic-HIGH), `0`
(logic-LOW), `X` (don’t-care), and `Z` (floating). A value of `Z` means that no
logic element is actively *driving* the line, and it is floating at some garbage
environmental value about which we don’t care.

This is different from `X` in that `X` is an actively asserted line, just not
one that matters to us. A discarded, driven mux input is `X`; the unused demux
output is `Z`.

The nice thing about `Z` is that, since it is not contested by any other logic
element, a line at `Z` can safely connect to an active line without causing the
circuit to melt. We will return to this concept later as well.
</aside>

The 1:2 demux and 2:1 mux can be replaced with 1:n and n:1 elements, where n is
whatever power of 2 necessary to route through all the elements contained
between them. The only necessary change is to ensure that the S line is n bits
wide.

We can imagine adding in a `NOT` block in our system, connecting it only to `A`
and letting `B` be discarded, and our ALU gains new functionality without
any change to the interface besides widening the mode selector.

## Mathematics

This is where things get weird. Honestly, you can skip this.

The way computers do math is the topic of a good solid *month* of a senior-level
design class. I’m not going to attempt to compress that whole month into this
article, because honestly I don’t think it can be done, so I’m just going to
cover the very simplest method of performing arithmetic, which is not the method
used in any modern computer, and if you really want to know, email me asking for
it.

### Decimal Addition

Let’s do some basic addition. In base-10 numbers, the order of digits is
0123456789, and after 9, you wrap to 0 and generate a *carry digit* which
propagates to the next more significant column.

<aside markdown="block" class="terminology">
We read left to right, so the left-most digit is the *most significant*, meaning
that it has the highest power of whatever base we are using. The power decreases
by one with every column to the right, until the decimal point is reached, at
which point the powers become negative.

$$123.45$$ breaks down to $$1 \times 10^2 + 2 \times 10^1 + 3 \times 10^0 + 4
\times 10^{-1} + 5 \times 10^{-2}$$. The farthest left column has the most
affect on the value of the number, so it is the most significant; the farthest
right column has the least affect on the value of the number, so it is the least
significant.
</aside>

When you carry a digit, you perform normal decimal addition on the next column,
but also add the 1 generated by the previous column. Then you repeat the process
working your way left, until you reach the end of the number. The sum is
guaranteed to be one digit wider, at most, than the arguments going in (called
*addends* for addition).

### Binary Addition

Binary addition works the exact same way, except it only has two digits, so we
have the digits 01 and $$1 + 1 == 10$$, which means that the bitwise-addition
emits a 0 as its bit output and sends a carry to the next column over.

~~~text
  1010
  1100
+_____
 10110
~~~

The left-most column of the addends generates a carry, which rolls to the next
column left. In 4-bit addition, the result is also 4-bits, so the carry output
(the fifth bit from the right) is not part of the returned sum, but on a carry
line, which goes somewhere else.

### Ripple-Carry Adder

So, the most obvious algorithm for addition is that which you learned in grade
school: start at the right and work your way left, pushing carries as you go. A
carry plus a one plus a one is 1 and a carry, so the carries can never build up.

Let’s take a look!

~~~text
A B                                        Cin
║ ║                                         │
║ ╚═══╤════╤════╤════╤════╤════╤════╤════╕  │
╚════╤╪═══╤╪═══╤╪═══╤╪═══╤╪═══╤╪═══╤╪═══╕│  │
    ┌┴┴─┐┌┴┴─┐┌┴┴─┐┌┴┴─┐┌┴┴─┐┌┴┴─┐┌┴┴─┐┌┴┴─┐│
┌───┤ 7 ├┤ 6 ├┤ 5 ├┤ 4 ├┤ 3 ├┤ 2 ├┤ 1 ├┤ 0 ├┘
│   └──┬┘└──┬┘└──┬┘└──┬┘└──┬┘└──┬┘└──┬┘└──┬┘
│ ╔════╧════╧════╧════╧════╧════╧════╧════╛
│ ║
│ Y
│
Cout
~~~

Our interface is this: two 8-bit inputs, `A` and `B`, and one 1-bit input `Cin`,
which is our carry-input; one 8-bit output `Y`, and one 1-bit output `Cout`,
which is our carry-output. Internally, the carry-out of each adder is attached
directly to the carry-in of its next higher neighbor (the pipe running from
`Cin` horizontally left to `Cout`).

There are two reasons to have a carry-input: wider addition gets broken down
into smaller chunks, so 16-bit addition on this machine is addition of the low
half, with the carry-out saved and fed to the carry-in when adding the high
halves; and subtraction. I’ll cover subtraction later.

Notice that `Y` is also eight bits; since 8-bit addition can generate a 9-bit
sum, the 9<sup>th</sup> bit goes on carry-out.

Let’s take a minute to think about the algorithm this implements.

1. The `A`, `B`, and `Cin` inputs arrive at the module and fill the input
    transistors.

1. All eight 1-bit adder elements compute their sum and write it to `Y` and
    `Cout`.

    Pause, ask yourself if we’re done at this point, and why you picked your
    answer.

1. The zeroth adder computes its carry output, and pipes it to the first adder.

1. The first adder, whose inputs just changed, recomputes its sum, writing to
    `Y` and *its* carry-out.

1. The second adder recomputes and passes the carry.

1. The third adder recomputes and passes the carry.

1. The fourth adder recomputes and passes the carry.

1. The fifth adder recomputes and passes the carry.

1. The sixth adder recomputes and passes the carry.

1. The seventh adder recomputes and sets carry-out.

1. The outputs `Y` and `Cout` are now stable and ready to be read.

Think about it: we have to pass the intermediate carry computation between each
adder, so the length of time required to wait before the outputs are guaranteed
stable is directly proportional to the number of bits being added.

Remember earlier when I said that binary trees come up a lot in computing? It
turns out that there is an addition algorithm that uses a tree arrangement to
make it so that carry computations can be executed proportionally to the
log<sub>2</sub> of the width of the adder, rather than the full width. This is
faster, but uses far more elements and power.

Callback to modular, composable design: the tree adder, called **Look-Ahead**
**Carry**, has the exact same interface as the linear adder, called
**Ripple-Carry Adder**, and thus the two adder types can be swapped out without
affecting the design of their neighbors. Anything that takes two n-bit and one
1-bit input, and emits one n-bit and one 1-bit output, can be plugged in. As
long as the replacement module is mathematically correct, the formal behavior of
the system is unchanged. (Obviously, the layout and power consumption are
altered, but that’s an electrical engineer’s problem, not ours.)

<aside markdown="block" class="terminology">
A Look-Ahead Carry adder is a binary tree structure, which I discussed earlier.
A 32-bit adder requires 63 worker elements, so while it operates quickly (carry
math goes up and down the tree, so it only takes 5 steps to stabilize), it costs
almost twice as much as a ripple-carry adder. This tradeoff is not always ideal.
</aside>

#### Binary Subtraction

First, let’s talk about how numbers are represented in binary. 8-bit *unsigned*
numbers (positive only) range from 0 (`0b00000000`) to 255 (`0b11111111`).
Adding 1 to 255 causes an *overflow*, where the lowest 8 bits roll over to 0 and
the carry output goes to where carry-outs go, which is *not* with the rest of
the sum. This is a limiting factor of machine arithmetic, and a common pitfall
for programmers.

Notice, though, that these numbers are positive only. *Signed* integers have two
representations. The first is to use the highest bit as a sign bit, `0` for
positive and `1` for negative, and the lower seven bits look normal. This is
easy for people, but not great for machines.

Recall that the 8-bit integer space is cyclical. We can use this with a notation
called *2’s-complement*, where the numbers run from -128 (`0b10000000`) to 127
(`0b01111111`). -1 is `0b11111111`, and 0 is `0b00000000`, as you’d expect from
adding 1 to eight bits of ones. Unfortunately, this means that 127 + 1 is -128,
not 128, so signed-arithmetic overflow is still a problem to avoid.

Notice, though, that addition that passes the overflow point winds up being
a subtraction of 256. Thanks to properties of arithmetic, we can thusly say that
subtraction is actually addition plus 256. The way 2’s-complement notation maps
to bits, means that in bit representation, `A - B` is actually `A + ¬B + 1`.

Let me prove I’m not making this up:

~~~text
let minus_one = 0b1111_1111;
let plus_one  = 0b0000_0001;

~minus_one = ~0b1111_1111 = 0b0000_0000;
plus_one = 0b0000_0000 + 0b1 = 0b0000_0001 = ~minus_one + 0b1;

let plus_127  = 0b0111_1111;
let minus_128 = 0b1000_0000;
let minus_127 = 0b1000_0001;

~plus_127 = 0b1000_0000;
minus_127 = 0b1000_0000 + 0b1 = 0b1000_0001 = ~plus_one + 0b1

Inductively:

~(number-in-2s-complement) = -number - 1
~(number-in-2s-complement) + 1 = -number
~~~

This works for all `n`-bit numbers, which can represent integers from
$$-2^{n-1}$$ to $$+2^{n-1} - 1$$.

So to implement subtraction, we use the exact same hardware, but stick a `NOT`
gate in front of `B` and force the carry input high. Since we can use the same
hardware as from addition, we don’t need to make a new block like we did with
the Boolean primitives; we just stick a multiplexer on `B` and `Cin` rigged to
do nothing (addition), or invert `B` and assert `Cin` (subtraction). Tada,
basic arithmetic.

Multiplication and division, and fractional numbers, are an entirely other
problem. I will not be discussing them.

## Combining Mathematics and Logic

Scroll way back up to the top, and imagine a multiplexer setup rigged to route
two data streams through one of our available operations: `AND`, `OR`, `NOT`,
addition, subtraction. This is the operating core of a CPU. A single execution
of the machine requires the following pieces of data:

- `S[2:0]` – The three select bits choose which operation is turned on.
- `A[7:0]` – Eight bits of the first argument to our operation.
- `B[7:0]` – Eight bits of the second argument to our operation.
- `Cin` – One bit of carry input (only used for arithmetic).

A twenty bit bus can be split up into `S`, `A`, `B`, and `Cin` buses, routed
through our ALU, and result in 9 bits of output (`Y[7:0]` and `Cout`). This
20-bit number is a *binary instruction*, which is exactly what all CPUs execute.

The specification of which bits in the number are which inputs, and which
numbers are legal (not all combinations of `S` and `Cin` result in sensible
output), comprise (part of) an **instruction set**.

# Memory

As it stands, our ALU is barely useful. We have to manually provide the input
instruction, and the output result gets dumped in our lap for us to use or throw
away.

The solution to this is another digital element, called a *register*. A register
is a component which has two inputs and one output. The registers in modern CPUs
are *positive-edge triggered*, which means that when the control signal switches
from low to high, the register takes an instantaneous sample of its data input
and then fixes the output line to be that value, until the control line ticks
from low to high again.

We can collect a group of registers into a *register file*, which is a large
bank of registers (each of which is as wide as our ALU operators), and connect
that register file to the input and output buses of the ALU. Thus, data comes
out of the register file, flows through the ALU, and is stored back in the
register file.

By signaling the register file, we can choose which registers in the file emit
to the `A` and `B` buses, and which register receives from the `Y` bus, of the
ALU. Now we only need to be able to put data in and out of the register file to
see the ALU’s progress, and the ALU can be set up so that data is stored and,
potentially, reused later.

Furthermore, now that our data is provided by the register file, we can take
the 16 bits of raw (also called *immediate*) data out of our instruction numbers
and replace it with the *register file addresses* we wish an execution to use.

Suppose that we have 32 registers. $$log_2(32) = 5$$, so we need five bits to
specify each register number. We need three registers: the sources for `A` and
`B`, and the destination for `Y`, so our instructions come out to 19 bits
instead of 20, and look like something like this: `SSSCAAAAABBBBBYYYYY`.

Our CPU now looks like this:

~~~text
SCABY      Register File      ╔════Data access
│││││┌──┬──┬──┬──┬──┬──┬──┬──┐║
││││└┤  │  │  │  │  │  │  │  ╞╝
││││ ├──┼──┼──┼──┼──┼──┼──┼──┤
│││└─┤  │  │  │  │  │  │  │  ╞══╗
│││  ├──┼──┼──┼──┼──┼──┼──┼──┤  ║
││└──┤  │  │  │  │  │  │  │  ╞═╗║
││   ├──┼──┼──┼──┼──┼──┼──┼──┤ ║║
││   │  │  │  │  │  │  │  │  ╞╗║║
││   └──┴──┴──┴──┴──┴──┴──┴──┘║║║
││ ╔═══B══════════════════════╝║║
││ ║╔══A═══════════════════════╝║
││ ║║┌───┐  ┌───┐       ┌───┐   ║
││ ║║│ d │  │ A │       │ m │   ║
││ ║╚╡ m ╞══╡ L ╞═══════│ u ╞═Y═╣
││ ╚═╡ u ╞══╡ U ├─Cout─┐│ x │   ║
││   │ x │  │   │      ││   │   ║
││   └─┬─┘  └┬─┬┘      │└─┬─┘   ║
│└─────┼─────┼─┴───────┘  │     ╚══to memory controller
└──────┴─────┴────────────┘
~~~

The `S` bus connects to the demux and mux in the ALU, as well as going into the
ALU block (to toggle addition/subtraction), and controls which route through the
ALU is active. The `C` line connects to the ALU; the `Cout` line is shown here
as looping back into the ALU; the truth is less clean. Don’t worry about it. The
`A`, `B`, and `Y` selectors go into the register file, which then sets up
internal state to emit the desired registers onto the `A` and `B` data buses,
and receive data from the `Y` bus into the specified register.

That’s pretty much it for a (simple) CPU.

# Review

A CPU consists of the worker logic in the ALU (arithmetic/logic unit) and
data storage in the register file. A multiplexer pair bookends the ALU, so that
power waste is minimized by not using the undesired operator units, and the ALU
can be set to perform partial addition or subtraction as well as Boolean logic.

There is more to the matter than this, of course: I have neither discussed nor
shown the clock line which ticks all the registers, and the data flow from
instruction bus and register file, through ALU, back into the register file, is
continuous. This is not actually true, but this is a useful approximation for
now.

The `SCABY` instruction bus is fetched from *instruction memory*, which is
controlled by a dedicated auto-adder called the *Program Counter*. This is
essentially a memory bank and self-feeding adder, which loads an instruction
from memory and then automatically increments so that next clock pulse, the next
instruction will be fetched.

Data can be fed into the register file from an external bus, so the CPU has some
initial state from which to begin operating.

In order to make the machine Turing complete, the ALU must also be able to
compare two numbers, and write to the Program Counter. This permits condition
inspection and jumps in program code, which are the two remaining criteria for
universal computation.

Additionally, there are other special registers that are kind-of-sort-of part of
the register file. One, called the Status Register, is the actual target of
`Cout`, as well as other status values from the CPU’s operation.

Lastly, there is a memory controller which grants us access to more than 32
memory locations. Some computers (Harvard architecture, from earlier posts) have
separate memory banks for instruction codes and data storage, while others (von
Neumann architecture, from earlier posts) have only a single memory bank where
both code and data are stored.

Von Neumann machines permit a computer to modify its own instructions, which
makes it an incredibly powerful system, and unique among all other computer
architectures which preceded it.

____

Post-Script: I will add external references to this in the near future. If you
have *any* questions or confusion about this post, please let me know. I’m sure
there are parts I could explain better.
