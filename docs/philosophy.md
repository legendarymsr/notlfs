# Why notlfs exists (and why I'm not an ultra-minimalist)

## I don't like ultra-minimalism

I'll be blunt: I think ultra-minimalism is cringe.

You know the scene. Distros that brag about being 3 MB. Systems that boot to a
shell with a handful of commands and nothing else. People ripping out man
pages, a usable editor, networking, or a readable font just to shave off a few
more kilobytes, then posting the number like it's a high score. "No bloat"
turned into a personality, and "minimal" stopped meaning *lean* and started
meaning *useless*.

That isn't engineering, it's a party trick. A system you can't actually live in
isn't impressive just because it's tiny. Making something small is easy; you
just delete stuff. Making something small that's still **good to use** is the
hard part, and that's the part the ultra-minimal crowd skips.

I also don't buy the purity games that come with it: refusing a tool because
it's "not suckless enough", rewriting everything in shell to avoid one
dependency, or treating any convenience as a moral failing.

## So why is notlfs minimal?

Because I wanted to prove a point: **you can build a genuinely minimal distro
that is still mostly usable.** Minimal and usable aren't opposites. The
ultra-minimal scene just acts like they are.

Size is a side effect, not the scoreboard. What minimal actually buys you is:

- **You can understand the whole thing.** One build script, one init system,
  one shell, one of each tool. When something breaks, there are only so many
  places it can be hiding.
- **Less to attack.** Every daemon, listener and library is attack surface.
  Fewer of them means fewer things to patch, audit and worry about.
- **Less to maintain.** Fewer packages means fewer version bumps, fewer
  breakages and a build you can actually keep pinned and reproducible.
- **It runs on old hardware.** A Libreboot ThinkPad or a 2013 laptop shouldn't
  need to struggle to boot a terminal.

Those are the reasons. The megabyte count is just what falls out.

## Minimal is a cost argument, not an aesthetic

Every line of code you run is a debt. It has to be read, patched, trusted and
understood when it breaks at 2 AM. That's the real case for minimal, and it's a
boring accounting argument, not a vibe.

But a missing tool is a cost too. If the system has no way to read a PDF, you
don't stop reading PDFs. You copy the file to another machine, or you install
something worse in a hurry, or you write a fragile shell hack. The complexity
didn't go away; it moved somewhere you can't see it. A distro that "has no
bloat" because it pushes all the bloat onto the user has cheated on the books.

So the question is never "is this small?" It's "is the total cost of running
this, including the cost of not having it, as low as it can be?" Ultra-
minimalism ignores the second half of that sum, which is why I call it
aesthetic vanity. It optimizes for how the system looks in a screenshot of
`du`, not for how it feels to live in.

## The rules

Every package has to pass these, roughly in order:

1. **Does someone actually need this to do real work?** If yes, it's in the
   running. "Nobody needs X" usually means "I personally don't use X".
2. **Does something already do this job?** If two tools overlap, one goes.
   This is where almost all of the actual minimalism comes from.
3. **Of the options, which is smallest *that still works properly*?** Not the
   smallest, full stop. The smallest that doesn't make you suffer.
4. **If it's a tie, usability wins.** A few MB is cheaper than a bad day.

## What that looks like in practice

These are real decisions from building notlfs, not hypotheticals:

- **`vi` and `top` were dropped, `ed` stayed.** `vis` and `htop` do those jobs
  better, so the BusyBox versions were pure duplicates. `ed` stays because it
  works when nothing else does: a broken terminal, a serial console, a script.
- **s6 over sinit.** sinit is smaller, but it can't restart a crashed service.
  A Wi-Fi daemon that dies and stays dead isn't minimal, it's broken. s6
  supervision costs a little and saves a lot.
- **BusyBox's web, FTP and telnet servers are gone.** Nobody should be running
  those, and leaving them in is attack surface for nothing.
- **mpd keeps web streaming.** It pulls in more of ffmpeg, but internet radio is
  a real feature people use. The fix for size is trimming ffmpeg to what mpd
  needs, not deleting the feature.
- **A small `yt` script instead of ytfzf + yt-dlp.** Searching via Invidious,
  picking with `fzf` and playing in `mpv` needs curl, jq, fzf and mpv, all of
  which are already there for other reasons. No Python runtime just for one
  command.
- **catgirl over irssi.** Smaller, simpler, TLS-only by default, and it fits a
  kernel called *catgirls*.
- **A real `e2fsck`, a rescue chroot script and `hwcheck`.** Rescue tools are
  exactly what you need on the worst day, so they're never the thing to cut.
- **Terminus and Tokyo Night everywhere.** A readable font and a consistent
  theme cost almost nothing and make a TTY-only system genuinely pleasant.

## Security and privacy count as usability

A system that leaks your data or gets owned isn't usable either. So notlfs ships
with an nftables firewall, LUKS2 disk encryption, kernel lockdown and hardening,
and the Intel ME and AMD PSP drivers compiled out. Tools like `hwcheck` hide
MAC addresses, IPs and network names by default. These aren't extras bolted on
afterwards. They're part of what "working" means.

## Reproducible, not ritual

Every source is pinned to an exact version and the build is deterministic, so
the same inputs give the same system. That's the useful part of the Nix/Guix
idea. What notlfs doesn't do is ceremony that slows you down without making the
result better.

## suckless: good idea, bad execution

I actually like the idea behind suckless: small programs, readable code, do one
thing well. I just hate how it's implemented, and I hate the elitism around it.

- **Config by recompiling.** Changing a colour means editing `config.h` and
  rebuilding. Then you need fifteen out-of-tree patches that stop applying to
  each other. That isn't simple, it just moves the complexity onto you.
- **Minimal on top of a mountain.** dwm brags about being under 2000 lines of C
  while running on Xorg, which is millions of lines and a protocol from 1987.
  If you really want minimal, why have a display server at all? A TTY already
  has a framebuffer, tmux tiles, and mpv plays video straight through DRM.
  That's how notlfs works, with zero lines of X.
- **Missing features as a virtue.** st has no scrollback unless you patch it in,
  and that's apparently a feature. It isn't. It's just missing.
- **The attitude.** "If you can't patch C you shouldn't use our software" isn't
  a philosophy, it's gatekeeping. Good tools should be simple to use, not just
  simple to read.

notlfs takes the good half: small tools, no duplicates, code you can follow.
It configures them with normal config files, and it doesn't tell anyone they're
doing Linux wrong.

## If you can't understand it, you don't own it

You can pay for a machine and still not own it. Ownership means you can answer
"what is this computer doing, and why?" without trusting a vendor's word for
it. On most systems, nobody can answer that. Not the user, not the distro
maintainers, often not even the people who wrote the parts.

notlfs is built so one person can hold the whole thing in their head: one
build script, one init, one shell, every service a short s6 run file you can
read in a minute. That's not a nostalgia thing. A system you can't reason about
is a system you can only hope about, and hope isn't a security model.

This is also why I don't want magic. No auto-generated config, no daemon that
"helps" by rewriting files behind your back, no layers whose only job is to
manage other layers. If something happens, there should be a file that says
it happens.

## Root only, on purpose

notlfs runs as root, and I'm not going to apologize for that.

Multi-user permissions were designed for shared machines: a university
mainframe, a server with many accounts. On a laptop with one human, the thing
worth protecting is *your* data in *your* home directory, and that's exactly
what a normal user account already has full access to. Malware running as you
can read your mail, your keys and your browser profile without ever touching
root. The separation protects the system binaries, which you can reinstall in
ten minutes, and leaves the irreplaceable stuff wide open. That's backwards.

The usual counterargument is "defense in depth", and it's fair as far as it
goes. But on a single-user box, `sudo` mostly trains you to type your password
whenever something asks. That's a ritual, not a boundary. Real boundaries on a
personal machine are encryption at rest, a firewall, a small attack surface,
kernel lockdown, and not running software you don't trust. notlfs does those.

The flip side is responsibility. Root-only means the system won't stop you from
doing something stupid. I think that's the honest deal: it's your machine, so
it's your call, and your mistake. If you want a system that protects you from
yourself, use one. That's a legitimate choice. It's just not this one.

## Privacy is a default, not a feature

A feature is something you turn on. If privacy is a feature, most people never
get it, because most people never change defaults. So in notlfs it's simply how
things are: disks are encrypted on install, swap is encrypted with a key that
dies at shutdown, updates come over Tor, there's a RAM-only amnesic mode, a
panic key that drops the keys and powers off, and tools hide addresses by
default.

I want to be honest about the threat model, because privacy talk is full of
overclaiming. notlfs protects you well against a stolen or seized machine that
is powered off, against casual network snooping, and against an update server
lying to you. It helps against someone grabbing a running laptop if you hit the
panic key in time. It does **not** protect you against a targeted attacker who
has already owned your hardware, against someone watching you type your
passphrase, or against you running hostile code as root. Anyone promising more
than that from a distro is selling something.

## Trust: the real hard problem

Every system is a pile of trust. The question is how small and how visible the
pile is.

Updates are signed with an Ed25519 key (signify format) and checked before anything is
unpacked, and they're fetched over Tor so the mirror doesn't learn who you are.
A tampered update gets refused, not "warned about". The build is pinned and
reproducible so anyone can check that the published system actually comes from
the published source, instead of trusting me.

Below the OS, things get worse. Intel ME and AMD PSP are whole computers inside
your computer, running closed code with more privilege than your kernel. notlfs
compiles out their drivers, but that only stops Linux from talking to them; it
doesn't turn them off. The honest fix is hardware that can run libre firmware,
like Libreboot or Canoeboot on older ThinkPads, with ME neutered or absent.
That's why notlfs cares so much about running well on old machines: right now
the most trustworthy laptops you can buy are often ten years old.

notlfs also ships no firmware blobs. The tradeoff is real: some Wi-Fi cards and
GPUs simply won't work without them. I'd rather say "this card needs a closed
blob, add it yourself if you accept that" than quietly bundle code nobody can
read and call the system trustworthy.

## Freedom over convenience (mostly)

Free software matters because it's the only kind you can actually audit, fix
and keep. Convenience is how people get talked out of that: the proprietary
driver that "just works", the app that only runs with an account, the service
that's free because you are the product. Each one is a small trade, and the
trades add up to not owning your computer.

But I'm not a purist about it either, and that's the same point as the rest of
this document. Freedom that makes the system unusable just sends people back to
the unfree one. So notlfs takes the free option by default, makes the
convenient option possible if you choose it knowingly, and never hides which is
which.

## Why not just use LFS, Alpine or Gentoo?

All three are good, and notlfs borrows ideas from each. None of them is what I
wanted.

**LFS** is a book, not a distro. It teaches you how to build a system, then
leaves you with one you have to maintain by hand forever, with no opinions
about security, updates or what to ship. notlfs is the opinions.

**Alpine** is the closest in spirit: musl, BusyBox, small. But it's a general
distro built for containers and servers, with a package manager, thousands of
packages and the usual multi-user setup. It's minimal as a base for other
things; notlfs is minimal as a finished thing.

**Gentoo** gives you total control, and charges you for it in compile time and
endless USE flag decisions. Control is great, but making every user rediscover
the same sensible defaults is just pushing work downhill. notlfs makes the
decisions once, writes down why, and lets you change them.

## What notlfs is not

- **Not a replacement for LFS.** Linux From Scratch is the textbook. If you
  want to learn how Linux works from the ground up, read it.
- **Not a size competition.** If another distro is smaller, cool. Can you read
  your mail on it?
- **Not a desktop for everyone.** It's TTY-only and root-only by design. It's
  for people who live in a terminal and want a system they fully understand.
- **Not a package ecosystem.** There's no repo of thousands of packages. If
  you need lots of software that isn't here, a bigger distro will serve you
  better, and that's fine.
- **Not a security product.** It raises the bar a lot, but it's a hardened,
  encrypted personal system, not a guarantee. Read the threat model above.

## TL;DR

I'm not chasing the smallest number. I think that whole game is cringe.
notlfs is minimal *as a means*, not as the goal. Cut duplicates, keep what
people need, and pick the smallest thing that still works properly. The goal
is a system that's lean, understandable, secure and still pleasant to actually
use.
