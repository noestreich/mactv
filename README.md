# MacTV

A lightweight macOS menu bar app for watching live German TV streams. Floats above all other windows — perfect as a small companion while working.

## Download

Grab the latest build (**v1.7.1**) from the [Releases](https://github.com/ty-art-ty/mactv/releases/latest) page: download `MacTV-1.7.1.zip`, unzip it, and move `TVFloat.app` to your Applications folder. The app is ad-hoc signed, so on first launch right-click it and choose **Open** to bypass Gatekeeper. Requires macOS 13+.

## Screenshots

<img src="docs/screenshot-player.png" width="640" alt="MacTV Player">

<img src="docs/screenshot-menu.png" width="320" alt="MacTV Menu Bar">

<img src="docs/screenshot-settings.png" width="640" alt="MacTV Settings">

## Features

- **26 live streams** — Das Erste, ZDF, Arte, ARD regional, and more
- **Floating window** — stays on top of all other windows (toggleable)
- **Keyboard control** — switch channels, volume, mute, subtitles, fullscreen without touching the mouse
- **Program info banner** — channel number, name and the current show (title + airtime) appear for 3 s on every channel change (EPG via the open Zapp/MediathekView API; ARD & ZDF channels)
- **EPG overview** — press `Tab` for a full list of all channels with their current show; navigate with arrows and switch with `Enter`
- **Screenshots** — press `Space` to save a PNG of the current frame into a configurable folder, under a per-channel subfolder (folder set in Settings; defaults to `~/Pictures/MacTV`)
- **Menu bar icon** — quick access to channels, show/hide, and settings
- **Settings window** — add, remove, reorder channels with custom stream URLs
- **ZDF API** — dynamic stream URL fetching for ZDF (no hardcoded URL)
- **Subtitle toggle** — enable/disable subtitles per channel

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `←` / `→` | Previous / next channel |
| `Tab` | Open EPG overview of all channels (↑ ↓ select · ⏎ switch · Tab/Esc close) |
| `↑` / `↓` | Volume up / down |
| `Space` | Save a screenshot (per-channel subfolder) |
| `1` – `9` | Jump to channel 1–9 |
| `0` | Jump to channel 10 |
| `M` | Mute / unmute |
| `U` | Subtitles on / off |
| `F` | Fullscreen on / off |
| `⌘W` | Hide window |
| `⌘Q` | Quit |

## Build

Requires macOS 13+ and Xcode Command Line Tools.

```bash
cd tv-mac
bash build.sh
```

The script compiles, bundles, and signs the app. Answer `j` at the prompt to launch immediately.

## Adding Custom Channels

Open **Settings** (`⌘,` or menu bar → Einstellungen) to add, remove, or reorder channels. Each channel needs a name and an HLS stream URL (`.m3u8`). Enable the **ZDF API** toggle for channels whose stream URL changes dynamically.
