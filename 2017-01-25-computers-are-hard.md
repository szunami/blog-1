---
title: Computers Are Hard
date: 2017-01-25
tags:
- computers
- personal
category: misc
summary: >
  A brief, evergreen note about why sometimes you can’t read my website. Posting
  it on that website was, perhaps, foolish.
---

For as long as I can remember, I’ve had a penchant for doing things myself where
possible, rather than relying on other people to do that work for me. This is a
somewhat unproductive trait to have in today’s society, where specialization and
internetworking are king, but it’s certainly an excellent avenue for education.

I blame my dad for this; we grew up on a rural homestead in Minnesota, and did
our own maintenance on the buildings. Dad is a cabinetmaker, among his other
skills, and so we had a fair amount of time in the woodshop making furniture,
and in the barn turning lumber into usable wood, and in the field growing trees
to harvest for their lumber.

That habit has carried over into my studies as well; I like digging around in
the guts of a system to see how it works, and I prefer making things myself to
using solutions made by other people. This isn’t a universal trait – just as we
didn’t manufacture our own tools in the shop, I don’t build everything from the
ground up – but where I can do things myself, I like to.

This website is a decent example of both sides of this coin. The site proper is
compiled by [Middleman][1], an excellent site generator for which I have written
no code whatsoever, and I use [jQuery][2], a large JavaScript library, for a
fair amount of the functionality on the page (such as the category manipulation
in the sidebar). However, I wrote all the HTML and CSS by hand, as well as some
of the scripting for which I couldn’t find solutions I liked.

> Note from the future: the Middleman app slowly grew more and more brittle,
> which slowed down my willingness to put up with it when writing new content.
> I eventually scrapped it entirely in favor of a new implementation.
{:.bq-safe}

I also host this on one of my own machines that I manage myself, including the
actual operating system (Arch Linux is my preferred flavor), security, and DNS.

Or at least, I used to.

I live in Utah now, but my server stayed behind in Michigan. One of the side
effects of doing things oneself is that when things inevitably break, you’re the
responsible party.

Something went wrong on my server, half a country away, and it shut down. In the
past, I’ve used my parents as on-site support, but from what I saw going wrong
before I lost contact, I don’t think I’ll be able to do that this time.

I tried to continue self-hosting, from my apartment in Utah, but Comcast’s
routers are significantly less friendly to this than AT&T’s are. I struggled for
a few days, gave up, and am now violating my principles and renting a small
server instance from DigitalOcean.

I don’t get very much traffic other than robots, but from watching the server
logs I can see that I’ve definitely inconvenienced some real humans during this
time. The rented server isn’t running quite perfectly either, and I’m still
working out those problems (which is hard to do from memory; I was not very
good about backing up my server to a machine I actually had on hand).

So for the small handful of people who came across me while broken, sorry.

Computers are hard. It’s okay to offload work to other people who are more
qualified or able than you.

That said, I have learned exactly nothing from all this and plan on going back
to pure self-hosting as soon as I get a local machine and a cooperating router
with which to do so.

After all, it’s not a real hobby if it never goes wrong!

[1]: https://middlemanapp.com
[2]: https://jquery.com
