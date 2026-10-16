# OpenNOW for Decky Loader

A [Decky Loader](https://decky.xyz) plugin that runs OpenNOW from Steam Game Mode on the Steam Deck and other SteamOS devices.

## What it does

- **Quick Access panel.** A slim launcher: whether OpenNOW is ready, running, signed out or has an update; Launch, Return to and Close OpenNOW; and the five most recent games you added, one press each. A Stream settings row shows the current resolution, frame rate and bitrate and opens the full-screen page.
- **Full-screen page.** Steam's sidebar layout with Add games, Stream (resolution, frame rate, bitrate, codec, HDR, Steam Deck identity, Steam Big Picture mode), Install, Library and About.
- **Play on OpenNOW.** Adds a button next to Steam's Install/Play button on the library page of every game on GeForce NOW, installed or not. On Steam games the button matches by Steam app ID. On non-Steam shortcuts it matches by title. Pressing the button creates a Steam shortcut for that game and streams it.
- **Add games.** Searches the public GeForce NOW catalog and adds any game to your Steam library with its artwork. Each shortcut starts OpenNOW with `--launch-app-id`, so the game goes straight into a session.
- **Install and update.** Installs the official OpenNOW Flatpak from the latest GitHub release. Updates are offered when a newer release exists.

Game Mode only shows apps that Steam starts, so the plugin always launches OpenNOW through Steam shortcuts.

## How it finds OpenNOW

The plugin checks these locations in order:

1. A path you chose under **Settings → OpenNOW location**.
2. The Flatpak `io.github.opencloudgaming.OpenNOW`, user installation first, then system.
3. The newest `OpenNOW*.AppImage` in `~/Applications`, `~/AppImages`, `~/Downloads`, `~/Desktop`, `~/.local/bin` or `~`.
4. `/usr/bin/opennow-qt` from the `.deb`.

Stream settings go to the same `settings.json` that the app reads. That file is `~/.var/app/io.github.opencloudgaming.OpenNOW/config/OpenNOW` for the Flatpak and `~/.config/OpenNOW` for other installs. OpenNOW's core owns the file while the app runs, and the plugin detects this through the core's `core.lock` in `/proc/locks`. While the app runs, the settings are read-only in the panel. The plugin writes the file the same way the core does: an atomic replace that keeps a `.bak` copy, and every key the plugin doesn't edit stays untouched.

## Develop

Requirements: Node.js 22 and Python 3.11. Run all commands from `decky/`.

```sh
npx pnpm@9 install
npx pnpm@9 run typecheck
npx pnpm@9 run build
npx pnpm@9 run test
npx pnpm@9 run package   # writes out/OpenNOW.zip
```

To install a build on a device, copy `out/OpenNOW.zip` to the device. Then install it from Decky's settings: **Developer → Install plugin from ZIP file**.

The backend lives in `main.py`. Its logic lives in `py_modules/opennow_decky`, which has no Decky dependency, so `tests/` exercises it directly. The frontend in `src/` uses Steam's own components from `@decky/ui`.
