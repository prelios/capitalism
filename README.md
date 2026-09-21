# Capitalism

This repository contains a Godot 4.7 local four-player card-game prototype:
one human player and three fair AI opponents. The rules model is authoritative;
the table shows public information while keeping opponent hands private.

## Requirements

- Godot 4.7.2 (the project declares the Godot 4.7 feature set).
- A desktop build of Godot.
- Godot 4.7.2 export templates when creating distributable builds. Install
  them from **Editor > Manage Export Templates**.

## Run and verify

From the repository root on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/regression.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/controller_integration.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/table_layout.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/human_ui_flow.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/trade_presentation.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/match_end_flow.gd
```

The first command launches the playable 1920×1080 table. You are Player 1:
select one card and a living opponent, then confirm the offer. When defending,
select any subset whose displayed total meets the offered value and confirm.
Use the result panel to fast-forward after elimination or begin a new match.

The remaining commands import the project and run deterministic domain,
controller, table, human-decision, and result/rematch checks. Each exits
nonzero on failure. The UI tests cover the deterministic edge cases that a
single manual match might not reach: overpayment, acquisitions, simultaneous
bankruptcy/meltdown, and last-acquisition monopoly.

## Build desktop playtest packages

The committed export presets target Windows x86-64, universal macOS (Intel and
Apple Silicon), and Linux x86-64. After installing the matching Godot 4.7.2
export templates, build all three from the repository root:

```sh
./scripts/build_desktop_exports.sh
```

Set a filename version or build only selected targets when useful:

```sh
VERSION=0.2.0 ./scripts/build_desktop_exports.sh windows macos linux
GODOT_BIN=/path/to/godot ./scripts/build_desktop_exports.sh linux
```

The script writes sendable archives and `SHA256SUMS` to `dist/`:

- `capitalism-with-cards-<version>-windows-x86_64.zip`
- `capitalism-with-cards-<version>-macos-universal.zip`
- `capitalism-with-cards-<version>-linux-x86_64.tar.gz`

You can also run **Build desktop playtest packages** from the repository's
GitHub Actions tab. A manual run or a pushed `v*` tag imports and tests the
project, builds all three packages with the pinned Godot version, and keeps
them as a downloadable workflow artifact for 30 days.

The macOS playtest export uses Godot's built-in ad-hoc signature. Downloaded
builds therefore require the tester to Control-click the app and choose
**Open** the first time. Windows may similarly show a SmartScreen warning for
an unsigned executable. Eliminating those warnings requires platform-issued
code-signing certificates and, on macOS, notarization; signing credentials do
not belong in this repository. Linux testers should extract the `.tar.gz` so
the executable permission is retained, then run `CapitalismWithCards.x86_64`.

## Current usability notes

- Every trade uses individually tuned target, offer, repayment, midpoint,
  arrival, and hand-update beats; spectator fast-forward removes them.
- Public seats use a clock layout for the full 4–10-player range, with the
  human at 6 o'clock and extra space reserved around the local hand.
- The start menu offers either play-based market pressure (qualitative
  feedback) or a time-based market. The latter visibly counts two full rounds
  without an elimination before starting the normal instability warning.
