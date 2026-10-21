# Contributing to Hawkey

Hawkey is an alpha Godot hockey simulation. Start with the smallest playable
improvement you can verify. Tests establish behavior, not realistic feel or AAA
visual quality; both still need human review.

## Run and check

Use Godot **4.6.3 standard edition** and Python **3.10+**. Open `project.godot`
and press F5, or run `godot --path .`. There is no npm install or required plugin.
The automated check workflow is currently verified on Linux; Windows/macOS
validation and exported-game checks remain open.
On Linux x86_64, `bash tools/ci/install_godot.sh` installs the checksum-verified
engine under ignored `build/tools/bin`; then pass `--godot build/tools/bin/godot`.

```sh
python3 tools/check_project.py --suite smoke
python3 tools/check_project.py --suite all --workers 2
```

The runner checks the engine version, imports resources sequentially, runs engine
suites with bounded concurrency, and runs Python unittest discovery. Logs,
`results.json` and `junit.xml` go in `build/checks/`. Each process has a timeout.
A GDScript exception fails the check even if Godot exits zero. Optional mocap is
reported as skipped when its local clips are absent; required suites cannot skip.
Some save-failure tests deliberately write to an unwritable `/proc` location;
expected diagnostic lines do not override the suite's actual assertion result.

For a quick targeted check, use
`godot --headless --fixed-fps 120 --path . --script tests/test_match.gd`.
On restricted cloud workspaces, use writable XDG cache/config/data paths as
recorded in the environment startup guidance. The runner isolates its own XDG
paths under its output directory. It does not delete user seasons/settings.

## Branches and review

| Branch | Responsibility |
|---|---|
| `codex/game-modes` | Current combined development build, game modes/data/rules/saves |
| `prototype/skating-puck-lab` | Presentation work: models, gear, lighting, animation |
| `main` | Reviewed baseline; currently does not contain the complete playable branch |
| `chore/project-quality` | Focused infrastructure/repository-quality review branch |

Use short-lived branches for concrete work, such as `feature/player-stat-ledger`
or `fix/pass-cancel`. Create them from the intended current integration head,
link the task, and send a focused PR. These are naming examples, not empty remote
branches. Read [coordination](docs/COORDINATION.md) before touching shared files;
fetch current heads and preserve other contributors' changes. Do not replace a
newer script with an older whole-file copy. PR merge/release remains a separate
owner-reviewed action; no automatic merge or deployment is configured.

## Where changes belong

- `scripts/match.gd`, `match_state.gd`, `controller_input.gd`: on-ice orchestration,
  match rules and input; test both match and Practice when changing shared input.
- `scripts/roster_database.gd`, `data/world/`: validated immutable source world;
  generated/estimated profiles stay labeled. Never regenerate a saved career.
- `scripts/gm_season.gd`, `gm_management.gd`, `gm_scouting.gd`: saved simulation,
  contracts/depth and scouting. Preserve stable identities and migration behavior.
- `scripts/save_store.gd`, `gm_checkpoint_job.gd`, `gm_session.gd`: validated atomic
  storage and worker/session boundaries. Workers cannot touch scene/GPU state;
  failed transactions must retain the live state and prior valid save.
- `scripts/gm_*.gd`, `mode_ui.gd`, `interface_font.gd`: native mode UI and typography.
- Arena, visual, kit and shader files: coordinate with the presentation owner.

## Definition of a reviewable change

Explain the player's problem and resulting behavior; list meaningful checks and
remaining limits. Add focused regression coverage for important rules, identity,
economy or save failures. Low-impact reversible presentation tweaks generally
need existing checks and actual visual review rather than implementation-shaped
tests. Attach genuine engine screenshots when appearance changes; mark staged
scenarios and reused captures. Documentation is excluded from Godot asset scanning with `docs/.gdignore`;
keep runtime resources in the project asset/data directories.
Keep generated saves, caches and raw third-party
motion clips out of commits. Include source/license notices for added assets.

Use the [feature audit](docs/ALPHA_FEATURE_AUDIT.md) and [roadmap](docs/ROADMAP.md)
to distinguish planned, partial and working features. Record verified scope and
handoff notes in coordination. Avoid empty buttons or unsupported feature claims.
