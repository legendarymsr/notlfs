# Why notlfs exists

Let's get this out of the way: I'm not an ultra-minimalist. I think the
"my distro is 4 MB and boots to a shell with three commands" scene is
cringe. Shaving off every last kilobyte until the system can't do anything
useful isn't an achievement, it's a party trick.

notlfs exists to prove a different point: you can build a genuinely minimal
distro that is still **mostly usable** day to day.

## What that means in practice

- **Small, but not crippled.** It's musl + BusyBox and TTY-only, but you can
  still edit code, use git, browse files, read mail, chat on IRC, watch video,
  listen to music, SSH around and get on Wi-Fi.
- **No duplicates.** Every tool earns its place. If two tools do the same job,
  one of them goes. That's where the minimalism comes from, not from
  removing things people actually need.
- **Usable over tiny.** If something makes the system meaningfully nicer to
  live in (a readable console font, a decent theme, a real `e2fsck`), it stays,
  even if it costs a few extra megabytes.

Minimal is a means, not the goal. The goal is a system that's lean, easy to
understand, and still pleasant to actually use.
