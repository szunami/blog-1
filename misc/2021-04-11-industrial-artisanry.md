---
title: Industrial Artisanry
subtitle: Individual Craftwork in the Autofactory Era
tags:
- craftwork
- economy
summary: >
  I’ve thought a lot about the effects of industrial production on our material
  circumstances, especially since everyone in my family is an artisan of some
  kind. Here are some reflections on that.
---

## Introduction

I want to talk about the dynamics of individual handwork and mass-manufacture
process and the way they affect our behaviors in modern society.

So first I’m going to talk about websites.

## Web Publishing

I’m a big believer in web programming. My very first creative endeauvours with
the computer were making very bad HTML pages in Microsoft Office® FrontPage™️
in elementary school. While I attempted to take Java™️ and C++ courses in high
school, I didn’t really start programming until late 2013, when I learned [Sass]
to write the stylsheet for a subreddit I liked.

Web programming is cool because the best way to convince a person that they’re
doing useful work is to show them something, then have them do stuff and watch
it change in response to their actions. Command-line programs just don’t have
the same level of engagement, and desktop graphical programming has a lot more
boilerplate and required components. But to make a website, you can just write
some stuff down in a file, drag it into Firefox™️, and see it live.

So I’ve always liked making websites, and ever since I started programming in
earnest I’ve always wanted to build my own as much as possible rather than just
toss some documents onto a host somebody else controls and let them control the
formatting.

### My First Website

I started out by cobbling together a single-page application from some HTML
partials and JavaScript. I actually got pretty far into having a functional,
though by no means flawless, single-page site that could serve a handful of
pages and weird resources. This was 2014, so at the time, I pretty much just
used it for my *Elder Scrolls* fanfiction. I still have the source code on a
temporarily-dead machine and hopefully I’ll be able to resurrect it. Most of its
content is superseded but there were two projects in particular that I want
back.

### My Second Website

After I got out of university, I had a bunch of free time on my hands, what with
being a household boyfriend and unemployed, so I built a new website out of the
[Ruby] language [Middleman] framework. It was a nice experience to start, and I
liked the fact that it let me use different layouts for different regions of my
site, which I was not able to easily do in other competitors. I wanted to
continue hosting my *Elder Scrolls* fanfic on a subsection that had a distinct
visual format from the landing pages and blog, which could share a look. So I
set it up, and gradually added features as my needs grew.

However, it was hampered somewhat by being a loosely-bound pile of Ruby and
began showing environmental differences between my local machines and the actual
web host. I didn’t put in the effort to learn how to correctly bundle and
package Ruby applications for deployment, so I started writing locally, then
pulling the contents to the host and rebuilding the site on it, and then I…
stopped writing.

The complexity surrounding the procedure of turning Markdown into HTML was a
friction that, as it accumulated, eventually stopped me from publishing on my
own platform when I had a much easier platform perpetually at my fingertips.
Twitter has a much more limited publishing featureset — only plain text and
images — but there is no barrier to creation and the enforced short-snippet rule
makes it easy to have conversations about specific aspects of a writing by being
able to refer to only the topical part.

So I started using Twitter to hold my long-form thoughts, as well as my more
casual conversations. And now a lot of my longer-form writing is buried in the
mire. I plan to recover it from my archive eventually but in the meantime, it’s
essentially forgotten.

### My Third Website

I eventually got frustrated enough with the concept of having my website frozen
in time with a steadily growing pile of drafts, and Twitter’s ease of riffing
from snippets only works if you can *find* the snippets, and its historical
search is not good, so I sat down and decided to aggressively rebuild my site,
this time focusing on a strict separation of content and presentation.

> At time of writing, I currently have (not counting this post) 18 other draft
> articles in various stages of completion, from late 2017 to late 2020. I also
> have 4 partially-complete drafts for the [oeuvre] section.
>
> I probably won’t ever be able to pick any of them up, let alone finish them.
> The most insulting is one that says “I was talking with my friend about this
> topic and suddenly inspiration struck”, and nothing else.
>
> Don’t save drafts. Publish or discard; you won’t be coming back to them.
{:.bq-warn .iso7010 .w011 role="complementary"}

Over the past three-ish weeks (initial commit was 2021-03-16), I built the
application currently serving this out of the [Phoenix] framework in [Elixir].
Not having to reïnvent the wheel for HTTP service and HTML rendering is
wonderful; my primary application logic is a custom Markdown processor to render
the source documents and some HTTP filtering to be more aggressive about
skipping the work when the site is unchanged (which is most of its time).

I was able to do this quickly because I have been doing presentation work for
eight years and back-end for five. While the work was certainly snapping
together parts that other people made with only a little bit of original work
myself, the assembly itself is still semi-skilled labor that people with less
practice or dedication would not be able to do as quickly or as well.

And the end result is at *best* comparable in visual output to plug-and-play CMS
services. Honestly, this probably could’ve just been a Tumblr skin. Perhaps even
should’ve! This site is flatly read-only, and I do want to have some amount of
interaction with my audience. But the important thing is that it’s up, I’m happy
with the presentation, and the decoupling of the presentation daemon from the
text content means that I can update the *text* by tossing Markdown files on the
filesystem, decoupled from the program logic actually driving HTTP traffic.

### Twitter

The contrast of all this work is, as I discussed above, my Twitter usage. I have
minor social interaction on it basically every day, write threads vaguely once a
week, and essay-length threads vaguely once a month. A lot of that is because
Twitter provides access to a great deal of source material, and when something
kicks off inspiration, I can immediately start writing.

But I can write faster and in more detail on my laptop, with an actual keyboard,
than on my phone, which is where I primarily do my reading, and I’m perfectly
capable dual-wielding them when I have a point I want to make.

So for me, I derive more personal happiness and satisfaction from the work I’ve
done personally in order to create the environment and presentation that I
specifically want, but I objectively get a lot more writing *done*, not to
mention scattered for reading, on a bland mass-market product I can’t use to do
anything other than post plaintext messages. Worse is better.

## Kit Furniture

I’m not a one-trick pony; I know how to do more than one craft. I build
furniture as well as websites. Or at least *built*; that present tense is going
to be intellectually dishonest until I make my own desk.

Chances are if you’re reading this you’re the kind of computers nerd who has
built, or at least *could build*, your own web presence beyond merely picking a
CMS and putting text on it.

Did you build any of your furniture? I didn’t. Nearly everything in my house is
store-bought; if not by me, then by the person from whom I did buy it. (I did
inherit some bookcases from grandma that, actually, Dad and I originally made
and gave to her.)

Furniture is *really* hard to build. It’s slow, requires expensive material and
even more expensive capital. You can offset some of those costs by getting a
membership at a local workshop or makerspace or community college. And if you
make a mistake, the material is probably unusable for anything else. And IKEA
has a box with what you want in it, folded for transport, and all you need to do
is unfold it and put it in your house.

Everyone who has any of the furniture my family built loves it. It’s beautiful;
Dad got a degree in cabinetry and put a lot of pride into his work. We made very
good furniture and construction. It’s better-looking and better-lasting than its
commercial peers.

But each piece took months to build. We worked on our basement for five years to
take it from empty to finished. And we couldn’t sell any of our furniture,
because it cost hundreds or thousands of dollars of lumber and we didn’t even
bother clock-punching for Dad’s skilled labor.

My brother makes some ornamental furniture as a hobby. He estimates that the
jewelry stand he gave his girlfriend would have a break-even price — materials
and a $20/hr wage (well below rate) — of $300. It’s $65 at IKEA.

## Clothing

I can’t make clothing. But Mom has been knitting for over a decade, and has
gotten *very* good at it. She made her own dress to match the theme colors of
my brother’s high school. She routinely makes sweaters — I have five — and gives
them to people just to keep herself entertained.

They take two weeks if she’s focused and putting in a workday. They cost $400 in
yarn and, again at $20/hr, which is again well below rate, $160 in wage. The
market equivalent is $90 at JCrew.

## The Destruction of the Artisanal Economy

I’m making some pretty bold claims that are easily rebutted by the words “etsy
dot com”. There clearly is a functioning market for individual craftwork. I even
bought my plague masks from Etsy! But for most people on it, it’s a side gig,
not a primary income, and it’s *certainly* not a significant fraction of the
general commodities market.

It’s undeniable that the industrial economy has enormous material, social, and
environmental costs. I am not going to defend the incorporated industrial system
at any point. However, it is also undeniable that the manufacture — is that even
the right word? While human hands are still important in the labor, that
importance is monotonically decreasing. It is undeniable that the autofacture of
mass-market commodities results in faster, cheaper, more materially efficient
production of each individual item than the equivalent artisanal production, for
roughly buyer-equivalent quality.

> This is a good thing. It is not morally possible to argue that mass-market
> autofacture must be halted until you genocide the planet’s population back to
> 1850 levels, and *that* is not morally permissible either. Population degrowth
> is fine but the lead time and decline rate are not going to get us there
> before the planet is inhospitable in 2150.
{:.bq-harm .iso7010 .f005 role="complementary"}

I have long believed that one of the overarching goals of human civilization is
to decrease the amount of human labor expended on survival and allow an increase
of human labor spent on recreation. Additionally, the standard of what
constitutes “survival” steadily increases over time, just as goods and services
in the market trend to migrate from luxury to commodity and then to necessity.

> We have observed this happen in most of our lifetimes: Internet access and
> smartphones have saturated the post-industrial societies in thirty and
> fourteen years, respectively; what was once a luxury reserved for academia or
> the economic aristocracy has become a critical aspect of infrastructure and a
> necessary tool to daily interaction.
{:.bq-safe .iso7010 .e007 role="complementary"}

So I firmly, though critically, support the concept of mass-market autofacture.
It represents yet another step in the technological advancement of human
civilization and an increase in the quality of life for everyone who is able to
make use of it. The fact that it is currently implemented on immiseration and
destructive practices is a consequence of our political and economic structures,
but is not an inherent requirement of the technology or the marketplace.

## What Happens to Craftworkers

There’s a great snippet of the movie *I, Robot* (2004) delivered by Will Smith’s
character that’s stuck with me ever since I saw it:

<div class="youtube">
<div>
<iframe width="560" height="315" src="https://www.youtube.com/embed/ROeaIv-5jwo" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
</div>

> I got an idea for one of your commercials. We can see a carpenter, making a
> beautiful chair. And then one of your robots comes in, and makes a better
> chair, twice as fast. And then you superimpose on the screen: “USR: shittin’
> on the little guy”.
>
> —Del Spooner

This is a succinct and imprecise, but not inaccurate or generally wrong, summary
of what industrial enhancement and tooling automation has done to the economics
of supply. Artisanry cannot compete on scale, speed, efficiency, or cost against
industry. Industry is a better supplier of market goods and services in every
measure *of that marketplace*. I am, again, continuing to ignore the negative
externalities as an aspect of implementation that we could (and must) change,
but have not yet chosen to significantly do so.

But you’ll note that in absolutely none of my essay so far have I ever said the
words “industry makes products that people like more than artisanry”. Because,
well, it doesn’t. In basically any niche where you have an artisan and an
autofactory competing, the autofactory might be cheaper, or it might be
technically better (if we’re lucky, both), but there’s an ineffable *je ne sais*
*quoi* about artisanal work that often just makes people happier than
autofactured competitors do. It’s been true of every niche where I’ve used both
forms of production. I suspect you agree. I’m not saying artisanal work is
*inherently* or *universally* better — humans are quite capable of producing
garbage on their own — but nevertheless it remains an aspect of the good that
autofacture just doesn’t match. Maybe it *can’t*, or maybe it just chooses not
to in service of other goals. I don’t know, and more importantly, I don’t care.

Because I’m not here to talk about improving industrial process.

### The Joy of Good Work

I can only speak for myself and my family members here and while I am
generalizing to the human condition, I freely acknowledge that I am doing so as
an indicator that I don’t think we’re unique; the only statement that is
universally applicable is that none others are.

But we (myself and my family specifically, and people in general, sure) don’t
continue to work on our projects for the economic value of them. As I’ve laid
out above, there isn’t a market for them that is economically viable! Sure there
are buyers, but the cost disparity between existence, production, and
consumption is severe enough that it severely restricts how much activity can
actually take place here.

We do it because it’s fun.

Because we like it. Making things makes us happy, and using things other people
have made makes us happy, and hopefully using the things we’ve made makes other
people happy.

Who cares whether it’s “market-competitive” or “optimized” or “scalable” or
whatever. We’re not doing this to be in a market. It’s just a thing we enjoy and
incidentally also has utility.

And this, morally, *cannot* be restricted to the domain only of those who are
economically able to do it as a hobby and have their survival assured by other
means. Rather, we should assure the survival and comfort of everyone; artisanal
work will follow after as people seek out things to do. This is not to say that
everyone must have some form of sponsored hobby! We have already established
that artisanry *on the broad scale* doesn’t matter economically. There’s no
requirement that people do work if they don’t want to. We do what brings joy,
for those people for whom that is hobby-work, they’ll do it without a
threatening motivator.

If you want to have accessible commodities, you move towards autofacture. We
have done so, and it’s good. And if you want to have nice commodities, you
sponsor artisans to live comfortably and let them figure things out from there.
This already happens, in a market biased against it. People want to do this. We
are limited by a system that requires us to sell labor for sellable purposes in
order to even strive to live in the comfort we want to have, so the notion of
doing work that does not financially or materially contribute to this becomes an
inaccessible luxury.

So what happens to the craftworkers is not the question.

## What Happens to Us

The question is what happens to all of us. This has always been the question,
from the very first day that the first human being produced more resources with
their labor than they needed to survive.

And the answer is socialism. We produce a surplus of resources for everybody who
exists. We require a steadily diminishing amount of labor directed to meeting
the basic standards of comfort.

We need to stop hoarding the surplus. We need to dismantle the command economy
that uses survival, let alone comfort, as prods to shape people into satisfying
the whims of oligarchs and aristocrats.

Industrial autofacture did not kill artisanal craft. It has been, and will
continue to be, a profound enabler of it! The smothering of small-scale
craftwork is a wound inflicted by people making choices, not a consequence of
technological advancement.

Roll your own website, or ask somebody who likes doïng that to make you one.
Make your own clothes, or ask somebody who likes doïng that to make you some.
Grow your own food, etc. Create and share joy in the things you like, and fall
back to the baseline sea of available commodities for things you don’t care as
much about personalizing. And organize for a world where doïng so doesn’t
detract from survival.

[Elixir]: https://elixir-lang.org/
[Middleman]: https://middlemanapp.com/
[Phoenix]: https://www.phoenixframework.org/
[Ruby]: https://ruby-lang.org/
[Sass]: https://sass-lang.com/
[oeuvre]: /oeuvre
