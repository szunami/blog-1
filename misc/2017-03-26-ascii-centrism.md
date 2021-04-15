---
title: ASCII-Centrism
tags:
- computers
- language
summary: >
  An article about a small, small subset of problems with using software tools
  that have ASCII- and/or English- only syntax elements.
---

If you’re reading this, I presume you know what [ASCII][1] is, but if not, it’s
the letter-to-number mapping commonly used in American programming to display
our alphabet, punctuation, and some other characters. It’s one of the earliest
character encodings (it’s designed to drive typewriters, back when those were
the interface used for computing) and won out over [EBCDIC][2] as the standard
encoding used … in America.

This was fine when 7 bits was enough for anybody and we had neither the fonts
nor the inclination to draw more symbols than could fit on a keyboard.

> Yes, 7 bits. ASCII defines 128 characters, from 0x00 to 0x7F. The first stage
> of ASCII extension used the upper 128 characters, but everyone made their own
> table to put there so we wound up with the concept of “code pages” and you
> couldn’t mix between them and it was awful.
>
> Also, we **still** have email programs alive today that panic when seeing text
> with the high bit set, because they were written for standard ASCII and
> nothing more.
{:.bq-info .iso7010 .m001 role="complementary"}

This is not an article about how we finally moved beyond ASCII (the short
version is: the [Unicode Consortium][3] is defining a single table whose goal is
to map all characters in all writing systems to numbers called code points, and
the [UTF-8][4] encoding is the One True Way to implement this; stop using other
things, *Windows*); I just wanted to provide some backstory.

So when C, one of the ancestors of basically all modern programming, was being
built, it was written with ASCII being the only serious encoding around, which
was fine, at the time. It was written in America, by and for Americans, and
ASCII has American right in the name. C adopted sigil conventions from its own
immediate ancestor, [BCPL][5], popularizing the use of English’s many different
grouping characters – `()`, `[]`, `{}`, `<>`, `'`, `"` – for different semantic
meanings that have continued essentially unchanged in C’s descendants today.

This is good; using words such as `begin/end` to denote blocks instead of `{}`
is a recipe for disaster, and it permits complex arrangements to be made with
minimal line noise.

> Fun example using all of them:
>
> ```rust
> fn foo<T: Show>(bar: [T; 5]) { println!("Bar: '{}'", bar); }
> ```
>
> Good luck doing that with words instead of punctuation glyphs.
>
> > Ironically, this website is hosted in Elixir, which uses `do`/`end` block
> > delimiters…
> {:.bq-safe role="complementary"}
{:.bq-info .iso7010 .m004 role="complementary"}

This is all well and good, until we look at strings. I take many, many issues
with C strings and will complain at length about them some other time; for now I
just want to talk about how text is placed in a source file.

In C, the single quote `'` (U+0027) surrounds a single character. In C’s ASCII,
this is equivalent to a signed, 8-bit, integer. The values `'A'` and `65` are
identical. Single quotes permitted working with text as numbers with no special
weirdness in place. The double quote `"` (U+0022) surrounded “C strings”, which
are actually arrays of ASCII numbers with a zero byte secretly slapped on the
end. This leads to fun confusion where `'A'` is of type `char` (8 bits wide) and
has the value 65, whereas `"A"` is a pointer (as wide as your CPU) of type
`char*` and has some value pointing into the compilation output, and at the end
of the pointer is the sequence `[65, 0]`.

The distinction between single and double quotes is essentially just a language
quirk that one must learn as part of learning the language; I’m not here to
complain about that either.

Look at the quotation marks I’m using in my normal text. Rather than using
straight single quotes “'” and double quotes ‘"’, I am using the paired, fancy,
curved quotation marks one sees in word processors.

If you’ve ever tried to copy code samples between a programming environment and
a word processor, you’ve no doubt run into errors when the parser reached the
fancy, non-ASCII, not-part-of-the-grammar, quotation marks.

Programming is a world-wide, supposedly modern, phenomenon, yet in many ways
we’re still hobbled by past assumptions and restrictions. Only recently have
languages branched out from ASCII in their grammar (the iconic example being
“emoji as valid identifiers” in Swift and other Unicode-aware parsers) and
process (for example, Rust mandates that all source files and `String` values
are UTF-8), yet the grammars have not expanded similarly.

We can now declare variables such as `résumé` or `😭`, but we still can only
wrap text in `'` and `"`. Non-English Latin languages use accented characters,
which are only recently not compiler errors; non-Western scripts such as Arabic
or Chinese are even less supported: consider the language [Qalb][6], which
contains no English text in its grammar, has the GitHub URL
[`https://github.com/nasser/---`][qalb], and still uses ASCII quotes for string
literals.

English isn’t the only language with quotation marks that aren’t valid syntax,
however. French uses « and » as its double quotes, and ‹ and › as its single
quotes. There are more, and more esoteric, quotation marks that can be found on
Wikipedia, but I don’t know much about them and would prefer to avoid putting my
foot in my mouth over them.

This isn’t 1970. The English character set is more than 128 characters, and the
world has more character sets in it than just English.

It’s past time to move beyond ASCII as an encoding, and UTF-8 is making
excellent progress at supplanting it. It’s also time to move beyond ASCII as an
alphabet.

Permit using `‘’ “” ‹› «»` as quotation marks in syntax grammars. That’s what
they mean (and to make parsing easier, there’s even a Unicode character property
“Quotation_Mark” that groups all, not just these, marks for easy and
future-proof processing). There will be fewer problems moving text between word
and code processors. There will be fewer international quirks for people and
text that aren’t a subset of English. There might even be benefits for those of
us who are: imagine being able to use specific quotation marks to control
[string interpolation][7] instead of the hacks currently present, such as `@{}`,
`#{}`, `$()`, `$<>`, and all the other permutations that are essentially just
Frankeinstein abuses of unused sigils and ASCII-acceptable paired group markers.
Or imagine not having the name [`Robert '); DROP TABLE Students; --`][8]
ruin your life because [code and data mixed too freely][9].

Written language is a big place. Let’s not restrict ourselves to one small part
of it simply because of accidents of history. The world is bigger than the US.
The languages available are bigger than ASCII. They shouldn’t be kept as
second-class citizens in our tools just because the ancestors of computing
didn’t think of them.

[1]: https://wikipedia.org/wiki/ASCII
[2]: https://wikipedia.org/wiki/EBCDIC
[3]: https://wikipedia.org/wiki/Unicode_Consortium
[4]: https://wikipedia.org/wiki/UTF-8
[5]: https://wikipedia.org/wiki/BCPL
[6]: http://nas.sr/%D9%82%D9%84%D8%A8/
[7]: https://wikipedia.org/wiki/String_interpolation
[8]: https://www.xkcd.com/327/
[9]: https://wikipedia.org/wiki/SQL_injection
[qalb]: https://github.com/nasser/---
