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
- [x] Complete fictional two-team roster fixture; native validated JSON loader;
  match consumes stable IDs instead of hard-coded identities; regression tests.
- [x] Menu roster selection and return-to-menu flow for Play Now/Practice using
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
- [x] Fictional HL (32 clubs), professional/junior/European/youth roster coverage.
- [ ] Calibrate estimated ratings and progression; no fabricated verified ratings.
- [ ] Real source adapters only for explicitly licensed datasets, with identity ledger.
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

2026-10-20 12:28 America/Toronto — Adopted owner's alpha-to-AAA production directive; added 38-category source audit and coordination table. Scheduled task instructions updated. Inspected latest prototype 28fb10b, which is newer than this branch base. Execution workspace is unavailable: no new gameplay code, tests, render or build claimed. Keep prior importer test evidence distinct. Next: restore execution, reconcile prototype, implement native roster loading and complete fictional fixture. See MASTER_PRODUCTION_DIRECTIVE.md, ALPHA_FEATURE_AUDIT.md and COORDINATION.md.

2026-10-20 12:50 America/Toronto — Execution remains unavailable (no usable execution environment). Read branches/PRs/directive/coordination/backlog/audit, compared latest Claude commits, confirmed choose_save/set_save source integration and preserved ownership. Added current NHL 27 benchmark catalogue with original acceptance scenarios and historical NHL 25 distinctions. No code/tests/build/screenshots produced. Next unchanged: restore execution, reconcile prototype 4c9ab2a or newer, complete fictional fixture and native roster loader, run relevant engine checks before integration. Research can continue independently; task not fully blocked.

2026-10-20 14:02 America/Toronto — Execution restored on Godot 4.6.3; reconciled prototype b2e58d7 and Claude goalie-gear 796fe0f without discarding either history. Implemented complete 40-player fictional fixture, strict failure-safe native loading, stable actor identities, team selection, dynamic team labels, results/rematch and Practice/menu round trip. Native 44 checks and navigation 27 checks passed; 11 Python tests passed. See ROSTER_INTEGRATION.md for broader engine evidence, captures and limitations. Work stage: Tested/locally Integrated; PR review pending. Next: atomic versioned saves/settings, then GM loop.

2026-10-20 — Expanded to 33 original leagues, 643 complete clubs, 14,745 players; 32-team HL, two professional farm tiers, 12 North American junior circuits, 13 European leagues and U9/U11/U13/U15/U18. Added complete skill/development profiles, farm links, birthday-based draft pool and explicit youth routes. Native version-2 validation and league-filtered Play Now implemented; youth remains data-only pending age-appropriate mechanics. See HL_WORLD.md and verification/hl-world-20261020.json. GM seasons, rights transactions, progression, save snapshots and annual prospect replenishment remain open.

2026-10-20 — Owner-requested polish, shooting and tie-break increment: bundled
licensed typography, consistent menu/HUD surfaces and previews, net-targeted shots
with left-stick placement and separate fixed wrist/slap profiles; Practice shares
the shooting/controller path. Added sudden-death 3v3 overtime and a playable
three-round/sudden-death shootout with stable attempt IDs and separated statistics.
Rules remain the explicit shared HL exhibition preset. See CONTROLS_AND_TIEBREAKS.md
and final verification evidence. Full referee/CBA exceptions, hardware feel, annual
GM simulation and persistent saves remain open. Official EA lookup blocked by runtime
network policy; exact EA control parity is not claimed.

Late integration: preserved prototype b5a292a goal-net/ripple update. Corrected net material energy absorption for new shots; verified net containment/ripple, shooting and shootout behavior after reconciliation.


## 2026-10-20 — owner-supplied Skill Stick correction

Owner: Codex, codex/game-modes / PR #2. Read both batches of seven owner-supplied
controls screenshots; web URL remains proxy-blocked. Integrated Claude prototype
e457c43 (backlog-only changes), preserving all existing presentation work.
R2 now arms/releases a bounded-strength pass with possession and switches without
possession. R1 selects saucer/poke; RS shoots with possession or a reachable loose
puck and checks with another carrier. Circle/square change forward lines/defence
pairs; L3 hustle retained. Controller R3 brake removed to avoid reference conflict.
Practice uses the same pass strength, real saucer loft and RS shooting. Pending
match passes cancel on pause, possession loss and disconnect. Brief neutral crossing
preserves slap gestures; neutral rest cancels windup. HUD help updated.
Implemented subset only: advanced dekes, vision/protection/blocks, stick lifts,
manual switching and faceoff gesture systems remain open, not advertised as working.
Executed evidence: verification/skill-stick-20261020.json; physical hardware untested.
No release/PR merge. Next: human controller feel and remaining contextual mechanics,
then persistent saves/GM season dependencies from the ordered backlog.
