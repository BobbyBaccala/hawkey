# Production coordination

Updated 2026-10-20 14:02 America/Toronto. Assignments are not completion evidence.

| Owner | Active task | Branch | Affected systems | Dependencies | Integration | Last verified build |
|---|---|---|---|---|---|---|
| Codex | Interface polish, net-targeted controller shots, playable OT/shootout | codex/game-modes | HUD/fonts, match/Practice/input, match state, tests and captures | Native Godot 4.6.3 verified; EA lookup blocked pending network settings | Tested and locally integrated; PR #2 pending review; no merge/release | 21 Python tests; 23 engine suites; OT/SO 75 checks; shots 132; navigation 47; genuine renders |
| Claude/separate presentation agent (owner-reported) | Graphics/lighting/models/gear/animation | prototype/skating-puck-lab observed; confirm ownership before edits | presentation assets, skater visuals, arena lighting, HUD styling | Shared scene and match interfaces | Prototype observed at 28fb10b; runtime not inspected here | Unknown in this session; do not infer from assignment |

## Coordination protocol

Read latest branch heads, open PRs, instructions and this record before edits.
Refresh branch without losing either parent's changes. Current mode branch is
based on prototype 8255b0b; prototype has advanced to 28fb10b. Do not copy stale
local match/visual scripts over it. Keep gameplay changes minimal and inspect
interfaces with presentation. Branch progression must use expected-head leases.
No automatic merge or release. Keep implementation, testing and integration
states distinct. Update this file with an actual build/commit when verified.

## Historical execution checkpoint (superseded below)

Current blocker: local executor reports no usable execution environment. GitHub
reads/writes work, so source audit/documents can be preserved. No new gameplay
code or tests executed in this session. First follow-up: restore execution,
reconcile latest prototype, run relevant baseline checks, then complete fictional
rosters and native validated loading. Do not fabricate a build or screenshot.

## 2026-10-20 12:50 refresh

Presentation prototype now 4c9ab2a, with source-visible stride and goalie save selection changes. Do not overwrite match.gd when adding roster loading. Codex task this session: current-edition benchmark research, audit corrections, precise acceptance requirements; affected docs/BENCHMARK_CATALOGUE.md, ALPHA_FEATURE_AUDIT.md, GAME_MODES_BACKLOG.md and COORDINATION.md. Dependencies: execution workspace + Godot, reconciliation of newer prototype. Integration remains draft PR #2. Last engine-verified build remains unknown in this session. No tests rerun and no build artifact created.

## 2026-10-20 14:02 America/Toronto — executed roster/Play Now checkpoint

Owner: Codex. Branch: codex/game-modes / existing draft PR #2.
Task: complete original rosters, native validation, Play Now selection/results/rematch/navigation.
Affected systems: data/examples, roster schema, scripts/roster_database.gd, match.gd,
match_state.gd, broadcast_hud.gd, lab.gd (Practice return only), tests, capture tool and mode docs.
Dependencies: Godot 4.6.3 and writable XDG paths now verified; no application secrets required.
Integration: preserved prototype b2e58d7 and separate Claude goalie-gear 796fe0f through
history merges (471cb7e and f3dc54b); mode implementation 2ab6020 plus final checkpoint changes.
Both ownership streams retained; Claude continues to own graphics/lighting/models/gear/animation.
No PR merge or release. GitHub API metadata access denied; Git refs accessible.
Last verified build: current integrated source under Godot 4.6.3, 11 Python tests,
44 native roster checks, 27 navigation checks; full engine result and rendered evidence
in ROSTER_INTEGRATION.md. Headless checks do not validate human feel or hardware.
Next checkpoint: versioned atomic saves/settings with recovery and roster snapshots;
broader Play Now setup and human/controller testing remain open.

## 2026-10-20 — full fictional world checkpoint

Owner: Codex. Branch codex/game-modes, existing PR #2. Task expanded by owner (2026-10-20 14:25 America/Toronto):
32 HL rosters plus professional farm, youth, North American junior and European coverage.
Affected: data/world manifest/snapshot/schema, generator, native roster loader,
match selection guard, title league filter, native/Python/navigation tests and mode docs.
Claude presentation files unchanged. Remote heads checked before edits; inherited
prototype b2e58d7 and goalie-gear 796fe0f are retained.
Integration: complete league-filtered exhibition data; no new GM mode advertised.
Verification: 21 Python tests, 20 engine suites passed; optional mocap skipped.
4,586 native world checks and 47 navigation checks passed. Exact outputs in
verification/hl-world-20261020.json;
rendered title inspected. Future GM needs persistent world snapshots, draft/rights
transactions, schedules, progression, injuries, contracts and new yearly prospects.
Youth competitions are currently data-only. No PR merge, release or publication.

## 2026-10-20 — interface / shooting / tie-break checkpoint

Owner: Codex, by explicit owner request to polish fonts/corners and add OT/shootout
and net-targeted controller shooting. Branch codex/game-modes, existing PR #2.
Affected systems: match state, net shot solver, controller adapter, match/Practice
integration, HUD/menu theme, bundled licensed fonts, arena_dressing.gd text font/filter
(two lines only), regression suites, captures and mode documentation.
Claude's models, gear, lighting and animation implementation retained; remote heads
checked before edits (prototype b2e58d7, goalie branch 796fe0f unchanged).
Actual final test/build evidence: verification/polish-shooting-tiebreaks-20261020.json.
No PR merge/release. EA reference lookup blocked by current egress; additive required
domains saved but not activated. Next: official control verification after access,
human/controller feel pass, complete rule exceptions, then saves/GM season loop.

Late reconciliation: new prototype b5a292a (goal frame/mesh/ripple) was fetched,
inspected and merged at c7f3485, retaining both goalie-gear and net changelog entries.
Only the net collision material's energy absorption was corrected; geometry and
shader remain Claude's. Explicit centre aim added to the net test fixture; its
containment/ripple assertions retained. Final net/shot/OT tests rerun after correction.


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
