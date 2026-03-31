# AntiIdle

A lightweight macOS menu bar app that prevents your system from going idle by simulating user activity in the background.

## Features

- **7 configurable action types** — each independently enabled with its own rate
  - Mouse Jitter (invisible 1-2px micro-movements)
  - Visible Mouse Movement (configurable radius: small/medium/large)
  - Keep-Alive Clicks
  - Burst Clicks (10-500 rapid clicks per burst)
  - Drag Gesture
  - Scroll Drag
  - Shift Keypress
- **Per-action rate control** — events per minute (EPM) for each action
- **Work schedule** — restrict activity to specific hours and weekdays only
- **Global hotkey** — toggle with Cmd+Shift+K
- **Idle detection** — only acts when no real user input is detected
- **Sleep/lock aware** — auto-pauses on sleep or screen lock, resumes on wake
- **Colored status icon** — green eye (active) / grey slashed eye (paused)
- **Start on login** support
- **Persistent settings** — all configs saved across restarts

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission (prompted on first launch)

## Build

```bash
# Build release binary
swift build -c release

# Create .app bundle
./scripts/bundle.sh
```

The bundled app is output to `build/AntiIdle.app`.

## Install

1. Run `./scripts/bundle.sh`
2. Copy `build/AntiIdle.app` to `/Applications`
3. Launch and grant Accessibility permission when prompted

## Usage

AntiIdle runs as a menu bar icon (eye). Click it to:

- **Toggle** activity on/off
- **Actions** — configure which actions are enabled and their rates
- **Schedule** — set active hours and weekday-only mode
- **Recent Actions** — view activity log

## License

MIT
