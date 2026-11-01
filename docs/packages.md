# Installed packages & tools

Everything here is built from source, statically, against musl. Versions are taken
from the build (`build.sh`) and the pinned source list (`files/sources.sha256`); a
few may drift as the repo evolves, so treat `files/sources.sha256` as the
authoritative list.

## Base system

| Component | Version | Notes |
| --- | --- | --- |
| Kernel | GNU Linux-libre 6.6.160-gnu | "catgirls" build, `x86_64` defconfig, no firmware, no modules |
| C library | musl | via the musl.cc x86_64 cross toolchain |
| Core userland | BusyBox 1.36.1 | static; provides sh and hundreds of applets |
| init / supervision | skalibs 2.14.4, execline 2.9.7, s6 2.13.2, s6-linux-init 1.1.3 | no s6-rc |
| Bootloader | syslinux 6.03 | isolinux (ISO) + extlinux (disk), static against musl |
| Filesystem tools | e2fsprogs 1.47.1 | static `mke2fs` for installs |

## TLS / crypto / network

| Tool | Version | Notes |
| --- | --- | --- |
| LibreSSL | 3.9.2 | TLS for curl, git, w3m, the `yt`/`tget` HTTPS helper |
| curl | 8.11.1 | |
| dropbear | 2026.94 | SSH server, key-only logins |
| iwd | 3.6 | Wi-Fi (s6 service + an fzf network picker) |
| nftables | 1.1.1 | firewall (libmnl 1.0.5, libnftnl 1.2.8) |
| tcpdump | 4.99.5 | with libpcap 1.10.5 |

## Terminal environment

| Tool | Version | Notes |
| --- | --- | --- |
| tmux | 3.5a | used as the window manager (libevent 2.1.12, ncurses 6.5) |
| fastfetch | 2.50.0 | system info, with the notlfs middle-finger logo |
| vis | 0.9 | `$EDITOR`; Lua (5.4.7) + LPeg (1.1.0) syntax highlighting, libtermkey 0.22 |
| lf | r42 | file manager (Go, CGO off) |
| fzf | 0.74.5 | fuzzy finder (Go) |
| htop | 3.3.0 | process viewer |
| ncdu | 1.20 | disk usage |
| ripgrep (`rg`) | — | fast search |
| jq | 1.7.1 | JSON |
| sc-im | 0.8.4 | spreadsheet (no Lua/xlsx) |
| calcurse | 4.8.1 | calendar / todo |

## Web, mail, chat, feeds

| Tool | Version | Notes |
| --- | --- | --- |
| w3m | 0.5.3+git20230121 | terminal web browser, HTTPS via LibreSSL |
| aerc | 0.20.1 | email client (Go); starts an account wizard |
| irssi | 1.4.5 | IRC client |
| newsboat | 2.41 | RSS/Atom reader (Rust, musl target) |

## Media

| Tool | Version | Notes |
| --- | --- | --- |
| mpv | 0.41.0 | video/audio; `--vo=drm` (framebuffer) or `--vo=tct` (in-terminal) |
| FFmpeg | 7.1 | built with VP9/Opus and TLS (libvpx 1.14.1, opus 1.5.2) |
| mpd | 0.23.17 | music daemon (ALSA), runs as an s6 service; music in `/root/music` |
| ncmpcpp | 0.10.1 | mpd client (static boost 1.83, libmpdclient 2.22) |
| ALSA | alsa-lib / alsa-utils 1.2.13 | `amixer`, `aplay` |

The mpv rendering stack also pulls in freetype 2.13.3, fribidi 1.0.16,
harfbuzz 10.1.0, libass 0.17.3, libdrm 2.4.124, and libplacebo 7.349.0, plus
Vulkan headers and libdisplay-info.

## Development & VCS

| Tool | Version | Notes |
| --- | --- | --- |
| git | 2.47.1 | over curl + LibreSSL |
| tig | 2.5.10 | ncurses git front-end |

## Fonts & misc

- DejaVu Sans Mono (2.37) + fontconfig 2.15.0 — for libass and the mpv OSD.
- Terminus (terminus-font 4.49.1) — a larger, readable console font loaded on
  tty1/tty2 via `setfont`.
- Supporting libraries: zlib 1.3.1, glib 2.82.4, libxml2 2.13.5, expat 2.6.4,
  json-c 0.18, readline 8.2, sqlite 3.47.2, bdwgc 8.2.8, fmt 10.2.1,
  fortify-headers 3.0.2, dbus 1.14.10, stfl (for newsboat).

## The `yt` YouTube script (`files/yt`)

A small shell script (not a packaged tool) that searches YouTube through
**Invidious** instances and plays results with mpv — no yt-dlp. All HTTPS goes
through `tget` (LibreSSL, certificate-verified) and mpv verifies TLS too. It falls
back across a configured list of instances (`files/yt-instances`), and
`yt --refresh` re-tests instances. See [usage](usage.md).

## Honest overlaps

Kept deliberately (BusyBox covers the basics, the dedicated tool adds something):
ripgrep vs BusyBox `grep`, ncdu vs BusyBox `du`, lf vs fzf for files, and
mpd/ncmpcpp vs mpv for audio.

## Deliberately *not* included

- **cmus, weechat** — both load core functionality as `dlopen`-ed shared-object
  plugins, which a static musl binary can't do. irssi covers IRC; mpd + ncmpcpp
  cover music.
- **GRUB, UEFI** — syslinux only, BIOS boot only.
