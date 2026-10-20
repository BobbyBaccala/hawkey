# Alpha feature and quality-gap audit

Updated 2026-10-20 14:02 America/Toronto. Executed roster/Play Now slice validated under Godot 4.6.3; see ROSTER_INTEGRATION.md. The broader table below began as a source-only audit; unchanged rows remain provisional and are not promoted by passing engine checks.

Inspected prototype head `28fb10bc46c32b9c4d04f57d318a04bcce83d7c6`, match.gd, match_state.gd, broadcast_hud.gd, controller_input.gd, lab.gd and MATCH_STATUS.md. Mode branch head before audit: `ea38194d58a23ea73448edb14cf7fa98af26ff50`. main remains README-only. Older status docs describe v0.6 and may lag presentation work; current code takes precedence. No feature is marked release-ready. Missing means not identified in inspected sources, not proof from an exhaustive executed build.

Definitions: Missing = no implementation identified; Placeholder = stand-in; Partial = incomplete behavior; Functional = complete usable scope; Validated = acceptance evidence recorded for a specific build; Release-ready = production gates met. Work stages Planned/In progress/Implemented/Tested/Integrated/Release-ready are separate from quality status. Prior Python test results do not validate engine integration or gameplay quality.

| Feature | Status | Evidence/current implementation | Dependencies | Desired behavior and acceptance | Verification required |
|---|---|---|---|---|---|
| Play Now setup | Partial | Fictional home/away selection, distinct-team guard, results and rematch validated; full rules/lineup/uniform/goalie setup remains open | Roster loader, setup model | Select teams/sides/uniforms/rules/lineups/goalie; rematch retains preset | Menu-to-result-to-rematch integration and manual play |
| Menu and navigation | Partial | Play exhibition, Practice, Controls, Quit; pause/restart/camera | Scene/session routing | Every supported mode returns to menu without leaked state; unavailable modes honest | Navigate all paths with mouse/keyboard and controller |
| Practice | Partial | Separate laboratory and shared simulation | Drill state/objectives | Free skate plus resettable shooting/passing/breakaway drills with feedback | Reset and scoring scenarios; manual instructions check |
| Authoritative match state | Partial | MatchState owns phase, score, period, clock and minors | Rules configuration and stable player IDs | Single event path updates state/HUD/stats exactly once | Deterministic transitions and duplicate-event tests |
| Skating and edge control | Partial | Velocity model, burst/brake, procedural movement | Movement/animation coordination | Momentum-consistent turns, stops, pivots and skating differentiation | Recorded scenario measurements plus human feel review |
| Puck/stick and airborne shots | Partial | CCD puck; stick assistance; charge/elevation controls | Calibration and contact scenarios | No teleport/tunneling; believable lifted shots/rebounds and physical receiving | Flight, post, board, possession and frame-rate scenarios |
| Passing/receiving/deflections | Partial | Assisted pass/saucer and support target logic | Contact and tactical ownership | Moving receivers handle passes; interceptions/deflections follow shared physics | Pass lane, pressure, saucer and deflection fixtures |
| Checking/contact | Partial | Poke/check separation and stun | Contact model and animation owner | Mass/angle/balance/legal contact with believable recovery and board response | Glancing/board/high-relative-speed cases and visual review |
| Goalkeeping | Partial | Angle/depth, prediction, butterfly/cover/contact logic; newer prototype adds choose_save/set_save for glove/blocker/body/pad reaches | Goalie AI and animation/equipment owner | Tracking/screens/posts/rebounds/save selection explain saves/goals | Repeatable screened/low/high/post/rebound exploit tests |
| Lines/fatigue | Partial | 4 forward lines, 3 pairs, fatigue and actor bench handoff | Persistent lineup IDs and role data | Legal swaps and fatigue across game, bench and saved lineup | Repeated swaps, penalties, stale IDs and save/load |
| Faceoffs | Partial | Timed reset positions; no full contest | Rules and input contest | Legal location/participants and skill-driven drop outcome | All restart types and input timing scenarios |
| Penalties/special teams | Partial | Timed/queued minors and power-play release | Configurable rules and tactical AI | Delayed/coincidental/major rules, legal manpower and appropriate tactics | Penalty chronology and strength transition fixtures |
| Offside/icing | Missing | Not implemented per inspected match and status | Rink line references, rules event interface | Whistle/exemption/location correct at high puck speeds | Boundary sweeps and exemption scenarios |
| Overtime/shootout | Missing | MatchState explicitly ends tied third period as draw | Rules/phase flow/HUD | League-specific tie resolution and final result exactly once | Tied regulation, sudden death, shootout, playoff variants |
| Empty net/timeouts/late tactics | Missing | No management flow identified | Goalie substitution and coach policy | Legal pull/return, timeout limits, score/time-aware risk | Late-game and delayed-penalty cases |
| Match statistics/results | Partial | Score, shots and simple event displays | Event ledger and player IDs | Accurate player/team stats, period summary, final report/rematch | Reconcile event ledger, score and displayed totals |
| Team tactics/difficulty | Partial | Primary pursuer, support lanes and simple pass/shot choices | Tactical state and debug intentions | Distinct forecheck/breakout/coverage/PP/PK decisions within fair physics | Formation scenarios, assignments, difficulty comparisons |
| Player ratings/tendencies | Placeholder | Loaded fictional speed estimates drive skating; acceleration/agility and goalie model integration/calibration remain open | Roster loader and rating model | Attributes affect measured outcomes; uncertainty transparent | Attribute isolation and held-out calibration tests |
| Signature abilities | Missing | No original trait system identified | Ratings/event hooks | Explicit trigger/effect/limits/counterplay/UI; no guaranteed outcomes | Trigger boundaries, counterplay and balance tests |
| Roster data/import | Validated (fictional Play Now slice) | Version-1 native validated loader, complete two-team original fixture, stable IDs and Play Now integration; 44 native and 27 navigation checks passed | Native validation and complete fixture | Stable IDs and tagged identities/estimates reach match without broken references | Invalid imports plus native end-to-end roster selection |
| Real professional/junior data | Missing | No reviewed licensed dataset shipped | Permission/provenance/identity ledger | Reviewed adapters, as-of/season/source and documented rating estimation | Identity reconciliation and source/version audit |
| Editors | Missing | No in-game player/team editor identified | Validation, undo and snapshot saves | Edit players/teams/lines/equipment safely and persist changes | Invalid reference, undo, import/export and old-save cases |
| Save/settings persistence | Missing | No versioned game-save system identified | Schema/migrations and session state | Atomic writes, backup/recovery, validation, independent settings | Interrupt/corrupt/migrate/restore tests |
| GM season loop | Missing | No persistent league/schedule/standings mode identified | Rosters and saves | New league -> play/sim -> standings -> advance -> save/resume | Seeded complete season with resumed state equivalence |
| GM transactions/finance | Missing | No contracts/trade/free-agent economy identified | Season loop and league rules | Legal budget/cap/roster transactions; AI values needs/window/replacements | Illegal transaction rejection and trade-exploit cases |
| GM scouting/draft/development | Missing | No prospect/draft/development simulation identified | Player histories and eligibility | Uncertain scouting; non-linear age/usage/health/context progression | Multi-season roster, scoring, prospect and finance invariants |
| GM playoffs/history/legacy | Missing | No persistent playoffs/awards/records identified | Schedules and event/stat ledger | Valid postseason and durable awards/records/retirement | Multi-season bracket and record reconciliation |
| Career journey | Missing | No original-player minor/junior/pro career identified | Saves, league eligibility and development | Create -> minor practice/game -> review -> opportunity; later tier progression | Saved vertical slice then multi-year eligibility/legacy tests |
| Career trust/progression | Missing | No coach trust/skill development choices identified | Career events and role model | Teamwork/positioning rewarded; selfish padding not dominant | Compare balanced/defensive/selfish play scenarios |
| Equipment art/customization | Partial | Imported gear and original kit; visual owner active | Asset fit, equipment IDs and saves | Correct fit/animation, usable edits and persistent cosmetics | Clip/pose reviews and equipment save/load; specialist approval |
| Arena/presentation | Partial | Broadcast HUD, multiple cameras, arena/lighting work active | Presentation owner and menu interfaces | Readable puck/text, coherent menus/intermissions/results/replays | Actual render review and full navigation playtest |
| Audio/crowd/chants | Placeholder | Synthetic event sounds and cutout crowd foundation | Original/licensed audio assets and event priorities | Varied context-aware spatial layers; chants respond without constant peaks | Mix/priority/event coverage and human listening tests |
| Input/controller | Partial | Keyboard/mouse and mapped gamepad adapter; radial deadzone/disconnect code | Settings/remap and physical devices | Rebind/sensitivity/deadzones, correct prompts, hot-plug recovery | Synthetic checks plus physical controller sessions |
| Accessibility | Missing | No complete accessibility settings flow identified | Settings and UI ownership | Text/puck cues, hold/toggle, reduced motion, audio/subtitles as needed | Accessibility checklist and user testing; feature-by-feature evidence |
| Performance | Partial | 120 Hz physics; no current measured hardware baseline | Runtime and representative hardware | Published workload/hardware/frame-time and sim-throughput baseline | Full-match profiling with repeatable seeds; before/after evidence |
| Multiplayer | Missing | No local/online multiplayer system identified | Separate authority/input/network design | Explicit local acceptance first; online separate scoped production stream | Multi-device/local ownership then latency/authority tests if authorized |
| Build/platform/release | Partial | Godot project exists; no build verified in this session | Working runtime, CI, target hardware and rights inventory | Reproducible installable build, notices, recovery and platform checks | Clean-machine Windows build/playtest; official platform requirements |
| Benchmark catalogue | Partial | 2K25/26 primary references in modes backlog; EA catalogue incomplete | Fresh official edition/platform sources | All benchmark categories cited and translated into original requirements | Source/edition/platform review; no unsupported current-edition claims |

## Historical dependency decision (superseded by executed checkpoint)

The user priority order puts crashes/save loss/navigation first. No crash has been reproduced in this session because execution is unavailable. The highest available mode dependency is a native roster loader plus complete fictional two-team snapshot, then Play Now team selection/return navigation and versioned saves. Do not edit Claude's animation/lighting/gear files to pursue this stream. Reconcile prototype changes since branch base before any gameplay edit. Engine absence is a validation blocker, not permission to claim new code works.

## Historical gap and next checkpoint

No new player-visible improvement or build artifact this session. Audit/coordination are Implemented documents, not implemented modes. Last locally reported evidence is the preceding importer run's 11 passing Python tests at ea38194; none rerun now. Current execution tool returns `No usable execution environment is available`. No new screenshots, gameplay tests, packaging or performance numbers exist for this audit.

Next active execution: obtain working workspace; sync current branch and prototype changes; locate/install authorized Godot runtime; run existing relevant regression suites; create complete fictional fixture, strict native loader and failure-path tests; connect only after executed checks. Keep PR #2 draft until integration verified. Continue official EA edition/platform benchmark research independently of code execution.

## Source refresh — 2026-10-20 12:50 America/Toronto

Prototype advanced to `4c9ab2abbdf68299cc855b118e03260a5dfdd458`. Compared commits since 28fb10b: Claude added stride/arm-clearance and goalie save-selection/pose work, new test_stride/test_goalie_saves and capture tools. Current match source calls choose_save and set_save based on predicted crossing. Goalkeeping remains Partial; absence of save selection is superseded. No independent engine test, visual inspection or quality approval in this session. Existing docs/MATCH_STATUS.md may lag these additions. Benchmark coverage expanded in BENCHMARK_CATALOGUE.md using current NHL 27 primary material; platform and historical distinctions explicit. Runtime unavailable, no new gameplay implementation.

## Executed checkpoint — 2026-10-20 14:02 America/Toronto

Current runtime and terminal work. Reconciled prototype b2e58d7 and Claude goalie-gear
796fe0f. Complete original rosters, native failure-safe validation, stable actor IDs,
Play Now side selection/results/rematch and Practice return are implemented and tested.
See ROSTER_INTEGRATION.md for test scope and actual rendered captures. Work stage:
Tested and locally Integrated, review pending. No release-ready feature claimed.
Play Now and navigation remain Partial against the full production target; native
fictional roster loading alone is Validated for its defined acceptance slice.
The previous no-runtime blockers above are historical. Next dependency is atomic
versioned saves/settings and snapshot preservation before persistent GM/Career work.
