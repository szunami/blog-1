---
title: What’s With the Diæreses
date: 2020-03-05
tags:
- personal
summary: >
  There are more things in language and orthography, Horatio, than are dreamt of
  in your ASCII encoding.
---

You may have noticed in my other writing, such as [commit messages](af5ee02),
that I use a diæresis on vowels, such as “coöperate” or “reärranging”. This is
not a common pattern in written English today – the only word commonly spelled
in this manner is “naïve”, and even it is often spelled with only one tittle[^1].

This habit is not the “metal umlaut” – the practice of putting umlauts over
vowels to look cool or (European) exotic, like the metal band Mötley Crüe or the
ice cream company Häagen-Dazs. It is an explicit recognition of the fact that
the English spoken language has more than five vowel sounds, but only five vowel
characters.

In English, when two vowels neighbor each other, they form a diphthong, and the
spoken sound is understood to be neither of their individual sounds, but a
different vowel, generally “in between” them. However, this runs into trouble
when a different English practice mixes with the diphthongs: concatenation.

English uses the Germanic principle of modifying words by attaching a prefix or
suffix stem to them. Anyone can act on their[^2] own initiative, but to act in
response to external stimulus, they *re*act. However, the word “react” does not
rhyme with “reach”, even though they differ only in their final consonant (which
is a digraph, not a diphthong – the “h” after a consonant forms a consonant
cluster, representing a phoneme that is neither a diphthong nor a hiätus). The
“re” prefix, while not a word, is an independent stem that fluent speakers know
does not merge with the root word it modifies.

When spoken, the words “reäct” and “naïve” and “coöperate” do not flow from the
first vowel smoothly into the second; rather, the speaker transitions abruptly,
and the two vowels are in separate syllables. The diæresis (not an umlaut) marks
explicitly that the word uses a hiätus rather than a diphthong. This may appear
to be mere pedantry, but it does have important disambiguation properties!

Consider the following two sentences:

> The worker coop (pronounced `/kuːp/`) was full of bustling activity.
>
> The worker coop (pronounced `/koʊˈɒp/`) was full of bustling activity.

These sentences are context-sensitive, in that you must know details about
*which* “worker coop” is being described here to know whether <del>the word is
coop as in cubicle farm or coop as in employer-owned</del> <ins>it contains
chickens or socialists (credit to Manish Goregaokar)</ins>.

Placing a diæresis on the second “o” of the second “coop”, making it “coöp”,
removes this context-sensitivity, and presents an unambiguöus[^3] sentence to
the reader.

I, like [the *New Yorker*], use the English diæresis to favor clarity and
unambiguïty in language, and to reject the sociëtal trend that reduces the
expressiveness of the alphabet and compresses the language into fewer and fewer
orthographic symbols.

> If you would like to join me, the character `U+0308 COMBINING DIAERESIS` can
> be typed on Windows by first [enabling a registry key][hex] and then typing
> <kbd><key>ALT</key> <key>+</key> <key>3</key> <key>0</key> <key>8</key></kbd>
> (hold down <kbd><key>ALT</key></kbd> with your left hand, and type
> <kbd><key>+</key><key>3</key><key>0</key><key>8</key></kbd> on the numpad with
> your right. No numpad? Copy it from Wikipedia). On macOS, type your vowel and
> then <kbd><key>Option</key>+<key>u</key></kbd>. And on Linux (GNOME and Qt
> windows, at least),
> <kbd><key>Ctrl</key>+<key>Shift</key>+<key>U</key></kbd> followed by
> <kbd>308 <key>Space</key></kbd>.
>
> Just long-press the letter on a phone keyboard.

The advance of the emoji as a modern ideögraphic language is a case study in the
human desire for disambiguäted glyphs and tolerance for a combinatorial
explosion of orthographic space. If we felt the need to expand the emoticon
“`:p`” into two different glyphs in order to distinguish between 😋 and 😛, then
we can add a small handful of letter modifiers (and letters! Note that I’ve been
using the ligature “æ” instead of the diphthong “ae” to spell the word
“diæresis” for this whole article[^4]) into our writing system.

My aims to reïntroduce þe θorn and θeta letters as disambiguätors for þe two
pronuncations of the digraph “th” (and spell “digraph” as “digraf”) can wait.

\[^1\]: Furthermore, the noun form “naïveté” has been moving towards “naivety”,
losing both diacritics *and changing its pronunciation as a result*.

\[^2\]: Roses are red; violets are blue. Singular-they is older than
singular-you.

\[^3\]: Yikes.

\[^4\]: There is not a diæresis over the “æ” in the word “diæresis” because that
vowel sound is a diphthong, not a hiätus.

[af5ee02]: https://github.com/myrrlyn/bitvec/commit/af5ee020ef1617251710dab64986a99fa377cb22
[hex]: https://ix23.com/windows-how-to-enter-unicode-characters-via-the-keypad/
[the *New Yorker*]: https://www.newyorker.com/culture/culture-desk/the-curse-of-the-diaeresis
