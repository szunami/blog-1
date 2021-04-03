---
title: Processors Part II
date: 2016-11-18
tags:
- computers
- electronics
- digital design
category: How Computers Work
number: 3
summary: >
  A continued exploration of computer processors and memory.
---

Unlike the previous two posts, I am going to massively skim, abridge, and
otherwise compress everything discussed here because, well, it’s (a) hard and
(b) not the point of the blog series; I’d like to actually work my way up into
programming soon.

This is just a list and brief overview of some advanced topics on processor
design, to give you some starting points on your own reading.

## Advanced Processor Features

The processor I drew at the end of the previous post was *extremely* simple. It
consisted solely of a register file and an ALU linked together, with interfaces
to load instructions from *somewhere else*, and a data input/output bus.

That’s a good gist of how processors work, but the reality is way, way more
complicated, and it took up an entire senior-level class.

### Miscellaneous Registers

While the concept of the register file is accurate, from an engineer’s point of
view, software architecture puts semantic meaning on various groups of registers
inside the file.

For example, on the MIPS architecture, there are 32 registers which are given
the following purposes and names. Only register zero has hardware alterations –
it always emits the number 0 when read, and drops writes.

> This is because `0` is a very common number when programming, and it can be
> shorter to encode “read from `$0`” than “use this embedded number: `0`” in
> many instruction sets.
{:.bq-safe role="complementary"}

- `$0` (`$zero`) – drops writes, reads 0
- `$1` (`$at`) – temporary register used by the assembler
- `$2` and `$3` (`$v0`, `$v1`) – return values from function calls or expression
    evaluation go here, and then get moved if they are to be preserved
- `$4` through `$7` (`$a0` to `$a3`) – arguments for function calls. If a
    function takes more than four arguments, the rest go on the *stack* (I’ll
    get to that later).
- `$8` through `$15` (`$t0` to `$t7`) – temporary registers for the currently
    executing function. These registers are considered to always be fair game to
    use and overwrite.
- `$16` through `$23` (`$s0` to `$s7`) – saved registers for the previously
    executing function. If a function wants to use them, it *must* push their
    old values to the stack when the function starts, and then restore them from
    the stack to those registers before it exits.
- `$24` and `$25` (`$t8` and `$t9`) – more temporary registers like `$t0` to
    `$t7`.
- `$26` and `$27` (`$k0` and `$k1`) – these registers are only for the kernel.
    Some CPUs will only permit access to these registers when the CPU thinks it
    is being run in “kernel mode”; others use the honor system.
- `$28` (`$gp`) – a global pointer into main memory. This is like a bookmark.
- `$29` (`$sp`) – the stack pointer. This is also a bookmark, but has *very*
    strict usage semantics. I will talk about stacks later.
- `$30` (`$fp`) – the frame pointer. This also points to “the stack”, and has a
    different meaning. I will talk about it in the stack article.
- `$31` (`$ra`) – This register stores the *return address*; when the currently
    executing function ends, it loads the return address value into the program
    counter, causing the computer to jump to a different part of the instruction
    sequence.

CPUs also define a special “status register” which contains, instead of a single
`n`-bit value, `n` 1-bit “flag” values indicating the state of the CPU. This
status register holds flags for things like arithmetic overflow, arithmetic
carry output, *interrupt* state, CPU mode, and comparison results.

> The ALU I showed last post actually ties its `Cin` and `Cout` lines to this
> register, not to the instruction bus. I lied about that to make it easier to
> discuss at the time.
{:.bq-warn .iso7010 .w020 role="complementary"}

Architectures can also define other special-purpose registers, but you get the
point about how they work. I’ll talk about what they mean when needed.

On the x86 and x86_64 architectures, which run on modern desktop computers, the
registers have stranger names and widths. Because Intel has specifically
designed x86 (which debuted in the 70s) to be permanently backwards-compatible,
as registers widened, they accumulated names. So the same register element has
up to three different names, referring to which *parts* of the register are
accessed. For example, `ax` is the bottom two bytes of register `ax`, `eax` is
the bottom four bytes (32-bits) of register `ax`, and `rax` is the entire eight
bytes (64-bits) of register `ax`.

This is important because Intel has also designed the x86 Instruction Set to
remain backwards compatible, so as CPUs grew in width, the old instructions and
operating modes stuck around.

So when you boot a desktop computer, it starts out thinking it's a 16-bit core
and only accesses 16 bits from each register, then you do some setup work and
inform the CPU that it can start using 32-bit instructions, which lets you
access the extended registers `eax` and friends, and finally you tell the CPU
to switch to 64-bit mode, which has yet another set of instructions and register
accesses available.

Computers are wild.

### Pipelines

The CPU from my last post could only do one thing at a time, and we had to wait
for it to complete its operation before we could start another.

This is ineffecient, because there are multiple steps to an instruction’s
execution, and they’re frequently independent of each other.

So we can use registers attached to a *global clock* to hold intermediate values
at each stage in the process. This means that rather than an instruction flowing
continuously through the CPU, it steps from one part to the next to the next,
doing so only when the clock “ticks”.

I’m going to use a 5-stage MIPS CPU as my example (can you tell that’s what my
class used yet?).

1. Instruction Fetch

    This stage loads an instruction word from memory into the first pipeline
    register.

2. Instruction Decode

    This stage splits the instruction word into its relevant pieces and sets up
    the registers and ALU to prepare for work. The register file connects the
    specified registers to its `A`, `B`, and `Y` lines; the ALU muxes select the
    proper behavior, and other things about which we need not concern ourselves
    happen.

3. Execute

    The data flows through the ALU, which stores the output in its `Y` temporary
    register and sets any bits in the status register as appropriate.

4. Memory Access

    If the instruction requires access to main memory, this access happens here.
    If the instruction does not require this, this stage is skipped.

5. Writeback

    Data flows into the waiting register file, either from memory or from the
    ALU.

Intel CPUs have up to a 20-stage pipeline. I have no clue what goes on in there.
It’s opaque magic. These five stages are the general actions that must always
happen; Intel has apparently found a way to further subdivide them.

The advantage of pipelining is that as soon as one instruction moves forward in
the pipe, another can step into the place it vacated. This means that it now
takes longer for an instruction to exit the CPU (because the computation time
remains constant, but now it has to work its way through the pipeline stage
registers too), but the CPU can emit instructions more often (an instruction
comes out every tick, which is much shorter than the full processing time).

If the un-pipelined CPU takes 20us to operate, than one instruction comes out
every 20us. Pipelining may add another 10us of total delay, but the longest
stage in the pipeline only needs 5us. Thus, it takes 30us for the first
instruction to come out, but from then on an instruction will be emitted every
5us.

Pipelines trade *latency* (time from input to resulting output) for *throughput*
(time between consecutive outputs).

### Hazards

Here’s a problem: what if a second instruction depends on the result from the
instruction just preceding it? This happens all the time, yet in the pipeline,
we can see that the ALU result doesn’t get stored until stage 4 or 5, yet the
next instruction will try to read it in stage 2. Assuming the second follows
immediately after the first, the second instruction will be reading from the
register file before the first instruction has written the needed value to it!

This is called a write-after-read hazard.

There is also a read-after-write hazard, where an instruction clobbers a
register you had planned to use before you have a chance to read from it, so you
wind up reading garbage. Neither of these are good things.

### Operand Forwarding

This is a solution to WAR and RAW hazards. A cleverly built CPU can detect that
a new instruction is attempting to use the same register or registers as a
recently-executed instruction. As part of the Decode stage, the CPU can then
set up the ALU so that instead of its result going to the register file or
memory, its result is *forwarded* to the next instruction (by going *backwards*
in the CPU); skipping the register write and read processes. The value sits
waiting at the appropriate input register without having to be emitted by the
register file, and all is well.

Alternatively, a CPU can decide to just stop feeding the pipeline until it knows
that register safety is assured, and then resume instruction processing. This is
called a **stall**, and is less awesome (there are ticks without work), but is
easier and cheaper to implement.

### Branch Prediction

> A *branch* refers to an event in the code that informs the CPU to stop getting
> instructions from the current section of the program, and instead start
> getting instructions from somewhere else.
>
> This event is called a *branch* if it occurs based on testing a condition
> (`if` statements in code), a *jump* if it happens unconditionally (`goto`,
> `break`), or a *call* or *return* if it happens as part of changing functions.
{:.bq-info .iso7010 .m002 role="complementary"}

The other problem with pipelines, especially very deep pipelines like Intel’s,
is that if an instruction has a comparison-and-branch, the CPU doesn’t know if
it will branch or not until stage 3. If it branches, then the instructions
behind the branch instruction which have started working through the CPU are now
garbage, and the CPU must throw them out before the new instructions enter the
pipeline. This means that from the time a branch occurs to the time the new code
enters the CPU, the CPU is doing no useful work.

Clever hardware engineers, compiler authors, and programmers will set up their
work to try to predict which branches get taken, and to make such prediction
easy. Complex CPUs manage by using a historical record of the most recent branch
events and whether or not they caused a jump. If the current trend is on taking
the branch, then the instruction fetcher assumes the branch will occur and loads
from the target immediately upon seeing a branch; if the current trend is on not
taking the branch, then the instruction fetcher assumes it won’t occur and keeps
loading from the current region.

This is why if you are writing low-level systems code that branches based on
random noise, and you don’t have a good reason why, your professors (and if
you’re learning from this article, I’m including me in that group) **will** yell
at you for it.

### Instruction Flow

Modern desktop CPUs have gotten so ridiculously fast relative to memory access
that Intel has come up with a clever, opaque-magic piece of wizardry called
**hyper-threading**.

Each CPU core has two instruction fetchers, which operate independently. They
take turns feeding instructions into the CPU, essentially making it do two
different things at once.

Intel will also happily look at the upcoming instructions and rearrange them to
make stalls and hazards less likely to occur.

It’s basically a code zipper. Each instruction stream is one side of the zipper,
and the CPU interleaves them to get a rather seamless result. This allows each
stream some more time for memory to come in before it has to work, and reduces
CPU idle time by increasing the amount of work ready to be done.

## Instruction Set

> This is the only part of the article actually relevant to you if you’re here
> for programming.
{:.bq-safe role="complementary"}

A CPU’s *instruction set* and *instruction set architecture* are its interface
to the outside world. These are specifications of how binary numbers should be
assembled to cause desired behavior in the chip. It defines which bits in an
instruction control the ALU, which control the register file, where *immediate*
values embedded into the instruction go, and most importantly how many ticks an
instruction takes to finish executing.

This is hugely important to writing assembly code, which will be covered shortly
since every other language winds up as assembly.

The instruction set includes more than just control switches for the CPU; other
components that are considered part of the chip (such as a floating-point-math
coprocessor, a GPU, other hardware...) have instructions that tell the CPU to
put them on the field, as it were.

## Peripheral Devices

A CPU on its own is just a calculator with a small amount of internal memory.
That’s incredibly useless.

Peripheral devices allow a CPU to interact with the outside world and expand its
functionality. Each of these devices has its own controlling processor, but the
way those work is defined by a *driver specification* the manufacturer provides
(or the FOSS community reverse-engineers) that tells the CPU how to talk to it.

### Expanded Memory

The CPU only has so much space in its own register file. The CPU’s register file
is small for the following reasons:

- reduce the bits consumed by register selection in instructions
- reduce the area footprint of the CPU
- reduce wiring complexity

but most importantly, memory chips are constrained by a triangle of speed, size,
and cost. Cost is not very fluid, so memory mainly trades speed for size.

If we want a memory component that can keep up with a CPU, it can’t be very
large, because that kind of memory is supremely expensive and delicate.

If we want a memory component that has lots of room and is robust, it can’t be
very fast, because physics is cruel.

If we want a memory component that is not cripplingly expensive, it can be fast
or large, but not both.

The solution for this is a memory hierarchy, with small and fast at one end and
large and slow at the other.

#### Cache

The *cache* is a collection of memory kept on board the CPU, that is distinct
from the register file. There are four tiers of cache, with L1 closest to the
CPU and L4 farthest away. Each tier of cache is somewhat larger and slower than
the last, and these caches may be shared among cores in a multi-core chip.

Even L4 cache, though, is orders of magnitude faster than RAM.

#### RAM

RAM (**R**andom **A**ccess **M**emory) is a large array of memory cells. It is
called random-access in contrast to sequential-access memory (like magnetic
tape, or magnetic platters) because access time to a cell is not dependent on
that cell’s location in memory, absolute or relative to the accessing element.

Current RAM speeds are roughly two to four thousand times slower than CPUs. This
is why CPU caches exist; when the CPU first asks for a chunk of RAM, the CPU
halts† and waits for the RAM request to complete. This request dumps a chunk of
RAM, rather than just the requested cell, into the caches. Since studies of
programs show that subsequent memory access will likely be to the same cell or
near neighbors, the caches provide rapid access to those memory regions until
the CPU is done with them, at which point they are written back to RAM.

> The action that halts the processor is actually an interrupt raised by the
> memory controller. Computers that run a supervisor program such as an
> operating system will usually react to that interrupt by selecting another
> unit of work and jumping the processor’s program counter to it. This is how
> essentially all modern computers implement running more than one program per
> processor.
{:.bq-info .iso7010 .m006 role="complementary"}

##### Alignment

A 64-bit CPU connects to RAM with a 64-bit bus, so RAM access works best when
the address being requested is an even multiple of 64 bits. Even though CPUs
today are 4- or 8- bytes wide, backwards compatibility means that RAM is still
addressed by single bytes. Thus, to preserve *alignment*, RAM accesses typically
leave the last several bits of the address blank.

Let’s look at what one 64-bit word of RAM looks like, with byte-wise addressing.

Each row in this table is an 8-byte word, and each cell is one byte. The least
significant nibble (four bits) of each cell’s address is marked in the cell, and
the remaining nibbles are marked to the left.

> Programming and computer science often work with numbers that make little
> sense to express in base-10, and much more sense to express in bases such as
> -2, -8, or -16.
>
> These are commonly denoted by using an `0<tag>` prefix.
>
> - Binary (base 2) is denoted by `0b` and uses the digits `01`, like `0b1010`.
> - Octal (base 8) is denoted by `0o` or `\` and uses the digits `01234567`. It
>   can be written `0o012` or `\012`. The latter form is a quirk from early C
>   compilers, and is often preferred to the former because `0` and `o` look
>   very similar. A disadvantage of octal is that because each digit is three
>   bits wide, octal digits do not cleanly divide bytes.
>
> - Hexadecimal (base 16) is denoted by `0x` and uses the digits
>   `0123456789ABCDEF`. Hexadecimal digits are four bits wide, and so a byte is
>   cleanly represented by a pair. This makes hexadecimal the most common
>   notation for working with large binary numbers, as it is an optimal balance
>   between compression, legibility, and regularity.
>
> Where hexadecimal numbers are used and include the digits `A` through `F`, a
> prefix is not required; however, it is considered good practice for almost all
> occasions. I am not using it in the table below to save space, and because it
> is obvious that the numbers are hexadecimal.
{:.bq-info .iso7010 .m002 role="complementary"}

```term
Main bits            Last 4 bits
64       32       │               │
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000003  │8│9│A│B│C│D│E│F│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000003  │0│1│2│3│4│5│6│7│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000002  │8│9│A│B│C│D│E│F│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000002  │0│1│2│3│4│5│6│7│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000001  │8│9│A│B│C│D│E│F│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000001  │0│1│2│3│4│5│6│7│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000000  │8│9│A│B│C│D│E│F│
                  ├─┼─┼─┼─┼─┼─┼─┼─┤
00000000_0000000  │0│1│2│3│4│5│6│7│
                  └─┴─┴─┴─┴─┴─┴─┴─┘
```

Modern RAM and motherboards are built for 64-bit words, and so no matter what
byte address is requested by the CPU, the RAM controller will ship the entire
word containing that byte. Since words are 8 bytes wide, the bottom 3
($$log{2}{8}$$) bits of an address are unused, and the address bus can get away
with not even having those bottom three lines.

Since RAM is built to operate on evenly spaced, or *aligned*, words, but the CPU
is capable of working with byte-level addresses, requests for *unaligned* memory
gets penalized. Suppose the CPU wants a 32-bit number stored at address `0x1C`:
it issues a request for address `0b_0001_1100`, but the bottom three bits are
discarded and so RAM acts on the word `0b_0001_1000` (`0x18`). When the CPU
receives that word, it knows to ignore the low four bytes and only use the high
four. This requires that the CPU *shift* the word down by 32 bits so that it is
working with a number at the correct power of 2.

Now imagine that a 32-bit value is stored at `0x10` and a 64-bit value is stored
at `0x14`. In order to access the 64-bit value, which runs from `0x14` through
`0x1B`, the CPU must request word `0x10` into one register and shift down, then
request word `0x18` into another register, shift up, and merge the two. This
takes far more time and space, and so most compilers will decide to skip the
four bytes `0x14` through `0x17`, and store the 64-bit value in the full word
`0x18`-`0x1F`.

Efficient memory usage requires that variables be properly aligned according to
their sizes, and this comes into play significantly in low-level programming.

#### Bulk Storage

RAM is great, but requires constant power supplies to preserve its stored values
(dynamic RAM slowly leaks charge; electrical science is just rude like that),
and there’s only so much of it. Even though 64-bit CPUs, which have 48-bit
addressing capability (it’s a weird topic; I’ll address it later), can access a
horrific amount of RAM, very few computers have the space or power necessary to
fill that.

So hard drives, solid state drives, magnetic tapes, and CD-ROMs provide an
extremely dense, unpowered storage solution. The only problem is they are
horribly, horribly slow. My 7200 RPM hard drives have a median lookup time of
10 milliseconds. Modern desktop CPUs run in the GHz order, which is **ten**
**million times** faster (GHz is $$10^{-9}$$ seconds, 10ms is $$10^{-2}$$ sec).

My hard drives are 4TB apiece, which puts them at more than two orders of
magnitude larger than my RAM space, but that doesn’t quite compensate for the
seven orders of magnitude they’re behind on speed.

On a CPU which can only run one program at a time, accessing the hard drive is
a crippling blow to performance. Fortunately, since hard drives can operate
autonomously once told to access a certain address, the CPU can issue a request
and go back to working on other things until that request completes.

When CPUs decide they need to ask RAM or bulk storage for data, they usually
stop doing whatever task required that transaction and pick up some other task
instead. This is called *multitasking* and is one of the more important features
of modern operating systems.

### I/O

What good is a computer that can’t talk to the outside world, where we live? If
we can’t put in data for it to work on, and it can’t put out results, there’s
not much point in having it work.

So all computers have some form of input and output capability. Even embedded
devices, like the computers that sit inside robot parts and cars and satellites,
receive data from the environment and can control other devices like motors or
radios or screens.

#### Display

The simplest (not really; it’s actually quite complex to implement, but simplest
from a user’s perspective) output device is a monitor. The computer prints text
to the screen, and the user reads it.

Computers can also print things (the first computers were connected directly to
typewriters, which is why our text encodings look like they do), or make noise
through speakers, but the quintessential form of computer to human communication
is the display.

#### User Input

Humans give data to the computer through a keyboard (and also a mouse). At first
computers were given input by directly manipulating electrical switches, but
this was tedious and required speaking the computer’s language.

Remember how I said the first generation of computers was connected to
typewriters? In truth, electric typewriters were cut in half (metaphorically)
and the computer was sandwiched between, so that instead of the typewriter’s
keyboard going to the typewriter’s printer, the computer sat between them and
read from the keyboard and wrote to the printer.

That happened in the ‘60s. Nearly sixty years later, and that interface has
barely changed; the command line is still present in all computers and pretty
much impossible for a programmer to ignore.

#### Networking

The most revolutionary I/O device is, by far, the networking card. With this,
computers can communicate with each other and exchange data and share work,
without having to be in the same case, room, or building.

## Interrupts

There are two ways a CPU can check on the outside world: perpetually ask the
world what its status is, or wait for the world to poke it.

The former, called a poll loop, is terrible, but simple.

The latter, called *interrupt*- or *event*- based programming, is awesome, but
complicated.

Basically, the CPU dangles certain wires to the outside world and, when those
wires change state, cause an immediate *context switch* in the CPU to a special
function called an *interrupt handler*.

A context switch means the CPU pauses what it was doing, loads new instructions,
and starts working on those.

The interrupt handlers are typically hard-coded addresses in instruction memory
that hold a value; that value is the address of the respective handler function.

Interrupt handlers must be fast, self-contained, and simple, because while a CPU
is in interrupt-mode, *no other interrupt can be serviced*.

> Somewhat. Most processors implement ranked categories of interrupt, and while
> in any given interrupt mode, no lesser-priority interrupt can preëmpt, but
> higher-priority interrupts generally can. This is generally considered
> unpleasant, so almost all interrupts have the same priority and thus execute
> sequentially rather than contentiously.
{:.bq-warn .iso7010 .w012 role="complementary"}

The interrupt handler does something (usually informing the OS of what happened
so the OS can do work at its leisure) and exits, at which point the CPU goes
back to what it was doing as if nothing happened.

This is how most I/O happens, since the CPU can’t possibly know ahead of time
when input signals will appear.

Interrupts can be attached to many devices, like keyboards or networking or
sensors, or most importantly, ***timers***.

All complex programs, and by complex I mean *all of them*, use timers to
schedule actions. The timer goes off, an interrupt occurs, the CPU gets new
information, and life goes on.

____

I encourage you to look up or ask me about any of these topics that catch your
interest; I’m happy to go on at length about them, but I do mean *at length*.

And next up is assembly language, and thence into actual programming, which is
the domain about which I actually want to talk and you, probably, actually want
to read.

> I interviewed at Space Dynamics Laboratory on 2016, Nov 4. Shortly after I
> published this article, I got my hire letter, so I moved from Michigan to Utah
> and went to work. This was my first job after college, and the transition from
> unemployment to industry, followed by the real-world effects of the new
> administration, derailed the rest of this series.
>
> Oops.
{:.bq-safe .iso7010 .e016 role="complementary"}
