# Playable milestones

Updated 2026-10-20. This is the short contributor-facing roadmap; the detailed
[feature audit](ALPHA_FEATURE_AUDIT.md), [mode backlog](GAME_MODES_BACKLOG.md) and
[production directive](MASTER_PRODUCTION_DIRECTIVE.md) retain the full scope.
Every milestone needs a usable loop and evidence, not just a menu entry.

| Milestone | Current state | Acceptance target |
|---|---|---|
| A readable, responsive hockey game | Play Now, Practice, shared shots/passes, OT/shootout and original presentation are partial/functional slices | Human controller/keyboard playtests; consistent physical responses; readable puck and UI; full rule/tactic scenarios |
| Trustworthy project workflow | Native/Python runner, pinned Godot and GitHub check workflow implemented | Run the same command locally and on CI; preserve failed logs; explicit skips; no silent script exceptions |
| A deeper GM season | 32-club regular season; world browser; free agents/contracts; junior scouting; team rates/game records | Shared played/simulated player-stat ledger → league/player/goalie leaders and history; manual roster/line management |
| A functioning offseason | Planned; terms persist but no rollover/expiry yet | Verified dated financial rules, draft/pick ownership, AI transactions, playoffs, contract expiry and replenished prospect supply; multi-year invariants |
| Meaningful player development | Original youth/junior/farm/European data; progression/Career missing | Saved minor/junior practice-game-review loop; coaching, health, usage and opportunity affect development transparently |
| A polished distributable build | Not release-ready | Export/resource/font checks, representative GPU performance, audio/human playtests, settings/device recovery, notices and owner-approved distribution |

## Next concrete simulation task

Implement one authoritative per-game player-stat ledger shared by played and
simulated games. Preserve stable identities; separate shootout attempts from
ordinary player goals; reconcile player/team totals; save/resume without duplicate
credit. Only then expose player/goalie leaders, splits, history and records.
Do not manufacture individual statistics from final scores after the fact.

## Branching serves work

Keep the current mode and presentation workstreams. Use focused feature/fix
branches when a real task starts; integrate reviewed changes while retaining
both histories. A branch count is not a measure of game quality. The highest
value work remains game feel, reliable simulation and visible playable depth.

Exact NHL 26/HLM 26 feature and current CBA research still needs official web
access. Current HL contracts/cap are a simplified original preset; see
[GM operations](GM_OPERATIONS.md). Full AAA parity is a long-term target.
