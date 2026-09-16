# Capitalism

This repository contains the Godot 4.7 simulation baseline for the local
card-game prototype. It currently starts and runs an automated simulation;
the playable human interface is deferred to a later epic.

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
```

The first command launches the automatic simulation. The third command runs
the deterministic Epic 0 regression and smoke checks, reporting its fixed
seeds and failing with a nonzero status when an assertion fails.
