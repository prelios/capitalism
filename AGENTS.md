# Capitalism: contributor instructions

## Sources of truth and scope

- Read [functional_spec.md](functional_spec.md) before changing rules. Read the assigned GitHub issue, its parent epic, and blockers for scope and acceptance criteria: [v1 roadmap](https://github.com/prelios/capitalism/milestone/1).
- Explicit current user decisions take precedence over older documentation. The current spec takes precedence over prototype code, comments, and historical simulation results. Issue instructions do not silently override accepted rules; flag unresolved contradictions that affect the task.
- The confirmed decisions below supersede stale spec passages until [issue #8](https://github.com/prelios/capitalism/issues/8) reconciles them. Thereafter keep the spec authoritative and remove redundant transitional notes:
  - Boredom-driven instability naturally contracts the market; no snapshot-equilibrium detector or arbitrary scored cutoff ends a v1 match.
  - Acquisition leaving one survivor wins immediately by monopoly, before any pending crash.
  - A crash leaving zero survivors ends in Global Economic Meltdown (working name), with **no winners**.
  - Otherwise, acquisition while stable starts instability; acquisition while unstable resolves the pending crash. Crash bankruptcies do not queue another crash; the market returns to stable.
  - Final boredom policy/presentation and warning duration remain configurable playtest decisions, not settled constants.
- v1 is one local human versus multiple fair AIs. Prioritize a complete four-player experience while preserving the 4–10-player design range. Networking is v2; suit powers, event decks, and token currency are outside v1.
- Implement the assigned issue and necessary prerequisites only. Keep the project runnable between steps; do not implement all future architecture while doing technical cleanup. Resolve routine implementation choices autonomously within the accepted design.

## Godot and game architecture

- The Godot project is in `godot/`. Use the project's Godot 4.x version (`project.godot` currently declares 4.7); do not upgrade the engine or switch renderer as incidental cleanup.
- Prefer typed GDScript, small methods, explicit return types, and existing naming/formatting conventions. Do not add frameworks, plugins, or global autoloads without a concrete task need.
- The model owns authoritative state, validation, turn order, market transitions, and endings. The controller requests decisions and manages pacing. UI and AI submit intent; neither directly mutates hands or executes duplicate rules.
- Prefer `RefCounted` for runtime domain data/policies, `Resource` for configuration, and `Node`/`Control` for scene behavior. Manage Node teardown explicitly; avoid reference cycles and accidentally sharing mutable Resource state across matches.
- Keep headless simulation and interactive play on the same rules path. Interactive orchestration must yield while awaiting offers, repayments, or paced AI actions; do not block the main thread with a whole-match loop.
- Use explicit pending-decision state and stable player/card IDs as that architecture is introduced. Validate ownership, phase, actor, target, and distinct repayment cards before mutation; reject invalid actions without partial changes.
- Signals announce facts; they do not execute required rules. Match declarations to emissions/listeners, emit resolved facts after atomic changes, and expose snapshots sufficient to redraw UI. Guard delayed callbacks and listeners against restart/finished matches.
- Fair bots and UI receive public information plus the local player's own hand. Opponent cards and total hand values are private. Keep privileged Optimal agents explicitly simulation-only, and keep full-hand debug output out of player-facing logs.
- Query/helper methods must not mutate authoritative arrays. Use match-owned seeded randomness for reproducible tests as the rules engine is refactored.
- Build this tabletop UI with reusable `Control` scenes, containers, anchors, and a shared theme. Support large acquired hands, resizing, and keyboard focus. Keep presentation timing separate from market/turn timing; avoid unnecessary per-frame polling.

## Verification

- Inspect existing test/run tooling first; do not claim a suite exists before it is added. Follow the assigned issue's acceptance criteria.
- From the repository root, basic import/parse verification is `godot --headless --path godot --editor --import --quit`. If `godot` is not on PATH, discover the installed binary (on this Mac: `/Applications/Godot.app/Contents/MacOS/Godot`). Inspect output as well as exit status for script errors.
- Run relevant headless regression checks for rule changes. Add focused tests for fixed bugs and observable invariants: card ownership/conservation, valid repayment, fixed-seat traversal, crash removal, outcome precedence, and no actions after completion.
- Use deterministic scenarios/seeds. A simulation turn cap is a diagnostic failure, never a victory condition. Do not adjust expectations to preserve behavior that contradicts the spec.
- For UI changes, run the game and exercise the changed interaction, including restart when relevant. Headless import alone does not verify playability. Documentation-only changes need diff/link review, not game tests.
- Report what changed, checks actually run, and remaining failures or limitations. Distinguish pre-existing failures from regressions; never claim unperformed checks passed.

## Git workflow and local commits

- **Granular local commits are authorized as part of implementation; do not ask for permission for each commit.** Commit completed, coherent changes with their relevant tests/docs rather than one large end-of-task dump. Normal filesystem/tool approval requirements still apply.
- Inspect `git status` and existing diffs before editing. Preserve user changes and unrelated work; stage explicit files or hunks, not an indiscriminate `git add .`.
- Review the staged diff and run the relevant checks before each commit. Keep commits buildable where practical; do not hide known failures behind a success claim.
- Use concise imperative messages, optionally including the issue number, e.g. `Fix clockwise turn selection after bankruptcy (#10)`. Include commit hashes in the completion report.
- Use `codex/` when a new branch is needed. Do not rewrite existing commits, discard unrelated changes, or change branches unnecessarily.
- Local commit permission does not authorize pushing, merging, publishing, or closing GitHub issues. Do those when explicitly requested or already authorized for the current task.
- Keep `.godot/`, temporary logs, generated builds, and credentials out of commits. Preserve Godot source identity files such as `.gd.uid` when relevant to the change.
