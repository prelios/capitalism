# Capitalism

This repository contains a Godot 4.7 local four-player card-game prototype:
one human player and three fair AI opponents. The rules model is authoritative;
the table shows public information while keeping opponent hands private.

## Requirements

- Godot 4.7.2 (the project declares the Godot 4.7 feature set).
- A desktop build of Godot. The initial development target is macOS; other
  desktop export targets have not yet been validated.

## Run and verify

From the repository root on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/regression.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/controller_integration.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/table_layout.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/human_ui_flow.gd
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

## Current usability notes

- AI turns use a short readable delay; spectator fast-forward removes it.
- The table favors four-player desktop readability. Layout validation for the
  full 4–10-player range is planned for the next epic.
- Market pressure currently shows the provisional completed-turn countdown;
  final presentation/tuning remains a playtest decision.
