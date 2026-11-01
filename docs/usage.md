# Usage basics

## Booting

Boot `out/notlfs.iso` (BIOS only), or boot a disk you installed to with
`notlfs-install`. In QEMU you can just use the included scripts:

```sh
./run.sh        # serial console + tmux (default); Ctrl-A X quits QEMU
./run.sh gfx    # also opens a QEMU window: tmux on tty1, a root shell on tty2
DAY=1 ./run.sh  # boot into the Tokyo Night Day (light) theme
```

The console logs straight into a root shell (there's only root, no password) and
comes up in tmux. There's a `day` boot entry in the ISO/extlinux menu too, which
boots with `notlfs.theme=day` on the kernel command line.

## tmux as the window manager

tmux is configured to act like a small tiling WM. The Alt-key binds work with no
prefix; `Alt+?` shows the full list (it comes from `/etc/motd`):

| Key | Action |
| --- | --- |
| `Alt+Enter` | new pane (auto-tiles master/stack like dwm) |
| `Alt+h/j/k/l` | focus left/down/up/right |
| `Alt+Shift+h/j/k/l` | swap panes |
| `Alt+Ctrl+h/j/k/l`, or `Alt+r` then `hjkl` | resize |
| `Alt+1..9` | switch workspace |
| `Alt+Shift+1..9` | send pane to workspace |
| `Alt+q` | close pane |
| `Alt+f` | fullscreen (zoom) |
| `Alt+Space` | next layout |
| `Alt+t` | re-tile |
| `Alt+d` | fzf launcher popup |
| `Alt+e` | lf (file manager) |
| `Alt+b` | w3m |

The classic tmux prefix (`Ctrl-B`) still works too: `Ctrl-B %` splits side by side,
`Ctrl-B "` splits top/bottom, and the mouse works.

## Theme switching (dark / day)

Every TUI tool uses ANSI color indices, so swapping the 16 VT colors re-themes the
whole system live. Use the `theme` command:

```sh
theme          # print the current theme
theme night    # Tokyo Night (dark) — the default
theme day      # Tokyo Night Day (light)
theme --apply  # re-apply the saved theme
```

The choice is applied live and persisted (to `/etc/notlfs-theme`). The Day theme
also makes a few readability tweaks automatically — it darkens "bright black" so
dim text stays readable, drops ncdu's yellow-on-cyan bar, and removes some bold/
colored styling in aerc and ncmpcpp that would wash out on a light background.
mpv's OSD colors (the only place using hex rather than ANSI indices) are rewritten
to follow the theme.

## The `yt` YouTube script

Search YouTube through Invidious and play with mpv — no yt-dlp, all HTTPS
certificate-verified:

```sh
yt                 # prompt for a search term
yt lofi beats      # search and pick a result with fzf, then play in mpv
yt --refresh       # re-test Invidious instances and save the working ones
# env: YT_INSTANCES="host1 host2"   YT_QUALITY=360  (max video height)
```

It walks a list of Invidious instances (`/etc/yt-instances`, overridable) until one
answers, shows results in an fzf picker, then streams the chosen video through mpv.

## Email, IRC, SSH

- **Email:** `aerc` — on first run it starts the account-setup wizard.
- **IRC:** `irssi`.
- **Music:** `ncmpcpp` (talks to the mpd service; put music in `/root/music`).
- **Feeds:** `newsboat` (URLs in `/root/.newsboat/urls`).
- **SSH in:** dropbear listens on port 22 (key-only). Put your public key in
  `/root/.ssh/authorized_keys`; host keys are generated on first connect. Under
  `./run.sh`, the host forwards to it on port 2223:

  ```sh
  ssh root@127.0.0.1 -p 2223
  ```

- **Web:** `w3m https://example.com` (HTTPS via LibreSSL).
- **Video:** `mpv --vo=drm file` plays on the framebuffer from a real VT;
  `mpv --vo=tct file` plays inline in any terminal (serial/ssh/tmux). Try
  `mpv --vo=drm av://lavfi:testsrc`.
- **Wi-Fi:** iwd runs as a service; there's an fzf-based network picker.
