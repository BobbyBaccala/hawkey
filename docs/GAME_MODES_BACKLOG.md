# Game modes workstream

Owns mode logic, player data, saves, menu functionality and measured simulation
performance. Graphics, lighting, models and animation remain with the separate
presentation agent. Do not work through docs/BACKLOG.md's presentation queue.
Read current remote commits and PRs each run; preserve concurrent changes.

Branch: codex/game-modes. Initially based on prototype/skating-puck-lab at
8255b0b209fe2bc87f883ed317389f63490d94c1 because main contains only a README.
Review this as a stacked PR against that prototype; retarget after its merge.
Never merge automatically. Reconcile new prototype commits before integration.

## Ordered increments

- [x] Offline CSV import with stable IDs, explicit identity/provenance, estimated
  rating labels, deterministic JSON and failure-safe writes.
- [ ] Complete fictional two-team roster fixture; native validated JSON loader;
  match consumes stable IDs instead of hard-coded identities; regression tests.
- [ ] Menu roster selection and return-to-menu flow for Play Now/Practice using
  existing title UI; no empty GM/Career buttons advertised as playable.
- [ ] Versioned GM/Career save envelope with validation, backup, migration and
  interrupted-write tests, plus settings persistence independent of career saves.
- [ ] GM vertical slice: new league, schedule, simulate/play game, standings,
  advance day, save and resume. Deterministic seeds and recorded results.
- [ ] GM contracts/free agents/trades with budgets and eligibility rules; then
  scouting uncertainty, draft, development, staff and owner objectives.
- [ ] Career vertical slice: generated minor player, practice objective, game,
  development review and persistent season stats; then junior/pro advancement,
  contract opportunities, NHL milestones and historical records.
- [ ] Player/team editor with validation and undo; per-save roster snapshots.
- [ ] Reviewed real professional/junior source adapters and identity ledger;
  methodology/calibration for estimated ratings; no fabricated verified ratings.
- [ ] Baseline profiling of frame time and season simulation; optimize measured
  bottlenecks and compare identical workloads before/after.

## 2K research applied to this design

Official primary sources reviewed 2026-10-20:

- [NBA 2K26 MyNBA/MyGM](https://newsroom.2k.com/news/endless-possibilities-await-as-mynba-levels-up-in-nbar-2k26):
  team-specific offseason scenarios, owner goals/budgets, roster/draft editing,
  persistent championship banners and selectable simulation depth.
- [NBA 2K26 MyPLAYER builder](https://newsroom.2k.com/news/nbar-2k26-myplayer-builder-delivers-all-new-animation-glossary-scouting-reports-and-build-by-badges-for-increased-customization):
  explicit build strengths/weaknesses, requirements and specialization goals.

Hockey adaptations (design proposals, not implemented): rebuilding/contending
owner objectives with consequences; staff/scouting specialties; transparent
player archetypes with achievable practice goals; persistent records and jersey
retirement; optional roster/draft customization; clear speed/depth choices for
season simulation. These are useful documented features, not evidence that 2K
is objectively the best. Do not copy proprietary code/assets or tie development
to paid currency. A reliable playable season comes before cinematic narrative.

## Progress log

2026-10-20 — Inspected remote branches, open PR #1, development/backlog notes,
current match code and roster schema. Added standalone importer and fictional
example. Eleven Python tests pass, including duplicate identity rejection,
provenance, NaN/infinity, malformed rows, deterministic order and failed-write
preservation. CLI imported two fictional players successfully. No visual files
or existing scripts modified. Godot executable is absent in this environment;
engine regression suites and runtime consumption remain unverified. The
presentation backlog's full-engine-test gate is unmet: keep this work draft and
require engine validation before integration. Next: native roster loading and
a complete two-team fixture, with Godot checks when a runtime is available.
