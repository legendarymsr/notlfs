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

## What notlfs is not

- **Not a replacement for LFS.** Linux From Scratch is the textbook. If you
  want to learn how Linux works from the ground up, read it.
- **Not a size competition.** If another distro is smaller, cool. Can you read
  your mail on it?
- **Not a desktop for everyone.** It's TTY-only and root-only by design. It's
  for people who live in a terminal and want a system they fully understand.

## TL;DR

I'm not chasing the smallest number. I think that whole game is cringe.
notlfs is minimal *as a means*, not as the goal. Cut duplicates, keep what
people need, and pick the smallest thing that still works properly. The goal
is a system that's lean, understandable, secure and still pleasant to actually
use.
