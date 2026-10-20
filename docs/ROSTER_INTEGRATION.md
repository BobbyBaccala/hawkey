# Fictional roster / Play Now checkpoint

2026-10-20, America/Toronto. Alpha; no release-readiness claim.

## Implemented scope

- Harbor Lanterns and Summit Comets: 20 original players each, four C/LW/RW lines, six defenders, two goalies. Fictional IDs and names; deterministic estimated ratings, explicitly uncalibrated and unassessed. CSV regenerates the committed JSON using `tools/import_roster.py` with no packages or network.
- `scripts/roster_database.gd` validates JSON, schema and metadata versions, globally unique player IDs, team IDs, text fields, position coverage, finite 0–100 ratings and estimate metadata. Missing/malformed/unsupported input fails with an error and preserves any previously loaded snapshot. Runtime currently accepts fictional/generated identities only. The offline importer can hold provenance for reviewed real identities; that does not authorize native use or redistribution.
- Native loader builds isolated match snapshots in line/pair order, independent of JSON ordering. Actors and starting goalies carry stable `player_id` references; identity handoffs update those references. Existing local numeric line/penalty indices remain snapshot-local, not database IDs. Speed ratings drive existing skating; acceleration/agility and goalie differentiation are not newly calibrated or connected by this increment. Backup goalie is data coverage, not a goalie substitution UI.
- Play Now selects distinct home/away teams; HUD, event messages, scoreboard, on-ice names and goalies consume the selected snapshot. Selection survives rematch and menu/practice round trips during the process. No disk-persistent preset is claimed.
- Final results show score/shots and rematch/menu controls. Practice exposes a return-to-menu button. Existing rules remain fixed: three 20-minute periods at prototype time scale; tied regulation ends as an explicitly labeled draw. No uniform, rule, lineup or starting-goalie editor is advertised.

## Reconciliation and ownership

Integrated prototype `b2e58d7477e9b778ef6b7bdfb4fe2cf7d406655c` and Claude goalie branch `796fe0fd0d44e4f0d97ca55d89703090974dd446` through local history merges into `codex/game-modes`. Both changelog entries retained in the one docs/BACKLOG.md conflict. No presentation implementation was rewritten; new mode integration is limited to match/HUD/lab navigation and data/state interfaces. PRs were not merged and public availability was not changed.

## Reproduce validation

Godot 4.6.3 stable official, Python 3, Linux. Default home data/cache paths are unwritable in this cloud instance; set:

```sh
cd /workspace/hawkey
mkdir -p /workspace/.cache /workspace/.config /workspace/.local/share
export XDG_CACHE_HOME=/workspace/.cache
export XDG_CONFIG_HOME=/workspace/.config
export XDG_DATA_HOME=/workspace/.local/share
godot --headless --path . --editor --import --quit
python3 -m unittest discover -s tests -p 'test_*.py'
for test in tests/test_*.gd; do
  godot --headless --fixed-fps 120 --path . --script "$test" || exit "$?"
done
```

The CSV's `.import` selects Keep: it is input data, not a Godot translation table. Installation/startup instructions are also saved in the environment configuration draft. Saved configuration is distinct from publication; this run does not establish restoration in a fresh task.

## Evidence and limits

Machine-readable results: [verification/roster-play-now-20261020.json](verification/roster-play-now-20261020.json).

11 Python importer tests passed. Native loader: 44 checks passed. Play Now scene/navigation: 27 checks passed, including duplicate selection rejection, side swap/reload, stable IDs, line handoff, results, clean rematch and Practice return. Engine regression: 19 executed suites passed; `test_mocap.gd` reports skipped because optional local clips are absent. These include rink/board, gear/clipping, stride/save selection, puck flight, controller synthetic events, match state, match loop and navigation. No physical controller, Windows, Steam Deck or human feel validation.

Actual [title](screenshots/play-now-title-20261020.png), [match](screenshots/play-now-match-20261020.png) and [results](screenshots/play-now-results-20261020.png) captures were rendered and inspected on Xorg dummy + Mesa llvmpipe, OpenGL compatibility, 1440×900. `tools/capture_play_now.gd` captures live scenes into ignored `build/` outputs. Its final-result capture deliberately advances the match clock for UI inspection; it is not a completed human-played match. Compatibility emits expected unsupported Forward+ effects/V-Sync warnings. No performance claim from software rendering.

Git read/push uses existing platform authentication. The GitHub GraphQL API returned Forbidden for `gh pr view 2`; PR metadata editing/retargeting is not verified. PR #2's Git head was verified equal to the original mode branch before development. Keep the PR draft; review and merge remain outside this run.

Next: versioned atomic saves/settings and saved roster snapshots, then persistent GM vertical slice. Broader Play Now rules/lineup/goalie setup and human navigation/controller playtests remain open.
