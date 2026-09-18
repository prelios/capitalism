# Simulation baseline — Epic 5 / #31

**Run date:** 2026-09-18
**Harness:** `godot/tests/pacing_simulation.gd`
**Engine:** Godot 4.7.2
**Configuration:** 30 seeded matches each for 4, 6, and 10 players; seeds
`31,400–31,429`, `31,600–31,629`, and `32,000–32,029`; one warning turn per
survivor; boredom multiplier 10; diagnostic cap 5,000 completed turns.

The cap is a diagnostic failure, never an outcome. All 180 matches completed
without diagnostics.

## Results

| Roster | Players | Avg. turns | Monopoly | Duopoly | Meltdown | Acquisitions | Warnings / crashes | Mirror payments | Exact payments |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Fair | 4 | 48.77 | 6 | 21 | 3 | 47 | 71 / 71 | 799 | 1,099 |
| Fair | 6 | 70.97 | 4 | 23 | 3 | 100 | 114 / 114 | 919 | 1,309 |
| Fair | 10 | 123.73 | 7 | 21 | 2 | 219 | 232 / 232 | 1,248 | 2,074 |
| Privileged | 4 | 37.33 | 6 | 24 | 0 | 48 | 56 / 56 | 490 | 847 |
| Privileged | 6 | 58.80 | 13 | 17 | 0 | 95 | 118 / 118 | 734 | 1,134 |
| Privileged | 10 | 104.67 | 14 | 16 | 0 | 201 | 222 / 222 | 1,273 | 1,977 |

The fair roster cycles Random, Aggro, and Scared policies. The privileged
simulation-only roster cycles OptiHigh, OptiLow, and OptiRand policies using
explicit privileged views. It is not representative of the shipped bots.

Policy decision calls averaged 11.96–19.99 microseconds for fair rosters and
16.74–28.21 microseconds for privileged rosters on the local development host.
Those timing figures are diagnostic only; they are not portable performance
claims. The harness does record the timing and decision count for each batch.

## Interpretation and limits

- Match length increases with player count as expected. These are mechanical
  baselines, not human-session duration estimates.
- Every warning in this run resolved in exactly one crash, providing a useful
  invariant for future warning/boredom experiments.
- Fair and privileged outcome rates differ, particularly monopoly and
  meltdown incidence. Do not use privileged results to choose the shipping
  bot lineup.
- Exact and mirror payments are recorded as trade-shape signals, not as a
  quality score. Human players may intentionally overpay for strategic reasons.
- This batch does not establish whether the boredom counter is understandable,
  enjoyable, or the right presentation. Those are human-playtest questions
  deliberately deferred until after the requested visual polish.

## Reproduction

From the repository root on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/pacing_simulation.gd
```
