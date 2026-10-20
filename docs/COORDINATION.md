# Production coordination

Updated 2026-10-20 12:28 America/Toronto. Assignments are not completion evidence.

| Owner | Active task | Branch | Affected systems | Dependencies | Integration | Last verified build |
|---|---|---|---|---|---|---|
| Codex | Adopt production directive; provisional source audit; next native roster loading | codex/game-modes | docs/MASTER_PRODUCTION_DIRECTIVE.md, docs/ALPHA_FEATURE_AUDIT.md, docs/GAME_MODES_BACKLOG.md, docs/COORDINATION.md; importer/data/tests from prior commit | Working execution environment, Godot runtime, current prototype reconciliation | Draft PR #2; no merge/deploy | No engine build verified this session; prior 11 Python importer tests at ea38194 |
| Claude/separate presentation agent (owner-reported) | Graphics/lighting/models/gear/animation | prototype/skating-puck-lab observed; confirm ownership before edits | presentation assets, skater visuals, arena lighting, HUD styling | Shared scene and match interfaces | Prototype observed at 28fb10b; runtime not inspected here | Unknown in this session; do not infer from assignment |

## Coordination protocol

Read latest branch heads, open PRs, instructions and this record before edits.
Refresh branch without losing either parent's changes. Current mode branch is
based on prototype 8255b0b; prototype has advanced to 28fb10b. Do not copy stale
local match/visual scripts over it. Keep gameplay changes minimal and inspect
interfaces with presentation. Branch progression must use expected-head leases.
No automatic merge or release. Keep implementation, testing and integration
states distinct. Update this file with an actual build/commit when verified.

## Execution checkpoint

Current blocker: local executor reports no usable execution environment. GitHub
reads/writes work, so source audit/documents can be preserved. No new gameplay
code or tests executed in this session. First follow-up: restore execution,
reconcile latest prototype, run relevant baseline checks, then complete fictional
rosters and native validated loading. Do not fabricate a build or screenshot.

## 2026-10-20 12:50 refresh

Presentation prototype now 4c9ab2a, with source-visible stride and goalie save selection changes. Do not overwrite match.gd when adding roster loading. Codex task this session: current-edition benchmark research, audit corrections, precise acceptance requirements; affected docs/BENCHMARK_CATALOGUE.md, ALPHA_FEATURE_AUDIT.md, GAME_MODES_BACKLOG.md and COORDINATION.md. Dependencies: execution workspace + Godot, reconciliation of newer prototype. Integration remains draft PR #2. Last engine-verified build remains unknown in this session. No tests rerun and no build artifact created.
