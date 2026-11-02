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

notlfs is small because it's careful, not because it's starving:

- **It does real work.** It's musl + BusyBox and TTY-only, but you can edit
  code, use git, manage files, read mail, chat on IRC, watch video, play
  music, SSH around, get on Wi-Fi and rescue a broken install.
- **No duplicates.** This is where the minimalism actually comes from. Every
  tool earns its place, and if two tools do the same job, one goes. Cutting
  duplicates is good taste. Cutting things people need is just self-harm.
- **Usability wins ties.** A readable console font, a proper theme, a real
  `e2fsck`, a working pager: if it makes the system meaningfully nicer to live
  in, it stays, even if it costs a few megabytes.

## TL;DR

I'm not chasing the smallest number. I think that whole game is cringe.
notlfs is minimal *as a means*, not as the goal. The goal is a system that's
lean, understandable, and still pleasant to actually use.
