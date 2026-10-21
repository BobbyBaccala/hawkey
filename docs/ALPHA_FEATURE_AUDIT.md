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
| Overtime/shootout | Validated (shared HL prototype preset) | Sudden-death 3v3 OT, playable three-round/paired sudden-death shootout; see CONTROLS_AND_TIEBREAKS.md | Rules/phase flow/HUD | League-specific tie resolution and final result exactly once | Tied regulation, sudden death, shootout, playoff variants |
| Empty net/timeouts/late tactics | Missing | No management flow identified | Goalie substitution and coach policy | Legal pull/return, timeout limits, score/time-aware risk | Late-game and delayed-penalty cases |
| Match statistics/results | Partial | Score, shots and simple event displays | Event ledger and player IDs | Accurate player/team stats, period summary, final report/rematch | Reconcile event ledger, score and displayed totals |
| Team tactics/difficulty | Partial | Selectable zone/forecheck/breakout/PP/PK planner and lane-aware carrier decisions | Sustained rotations, adaptation and gameplay tuning | Distinct forecheck/breakout/coverage/PP/PK decisions within fair physics | Formation scenarios, assignments, difficulty comparisons |
| Player ratings/tendencies | Placeholder | Loaded fictional speed estimates drive skating; acceleration/agility and goalie model integration/calibration remain open | Roster loader and rating model | Attributes affect measured outcomes; uncertainty transparent | Attribute isolation and held-out calibration tests |
| Signature abilities | Missing | No original trait system identified | Ratings/event hooks | Explicit trigger/effect/limits/counterplay/UI; no guaranteed outcomes | Trigger boundaries, counterplay and balance tests |
| Roster data/import | Validated (original league-world data/exhibition slice) | Version-2 HL world: 33 leagues, 643 teams, 14,745 players; complete rosters and reference/age/rights validation; league-filtered Play Now. Version-1 fixture retained; see HL_WORLD.md for final checks | Native validation and complete fixture | Stable IDs and tagged identities/estimates reach match without broken references | Invalid imports plus native end-to-end roster selection |
| Real professional/junior data | Missing | No reviewed licensed dataset shipped | Permission/provenance/identity ledger | Reviewed adapters, as-of/season/source and documented rating estimation | Identity reconciliation and source/version audit |
| Editors | Missing | No in-game player/team editor identified | Validation, undo and snapshot saves | Edit players/teams/lines/equipment safely and persist changes | Invalid reference, undo, import/export and old-save cases |
| Save/settings persistence | Partial (defined GM persistence slice tested) | Atomic validated versioned slot, backups/recovery, envelope migration; independent camera/dead-zone preferences; see GM_SEASON.md | Schema/migrations and session state | Atomic writes, backup/recovery, validation, independent settings | Interrupt/corrupt/migrate/restore tests |
| GM season loop | Functional (single HL regular-season alpha) | New 32-team league, 62-game balanced schedule, deterministic sim/play, standings, advance and save/resume; see GM_SEASON.md | Rosters and saves | New league -> play/sim -> standings -> advance -> save/resume | Seeded complete season with resumed state equivalence |
| GM transactions/finance | Partial (tested HL alpha market) | 736 initial contracts, 64 original free agents, cap/term checks, saved signing/depth/match integration; simplified policy; GM_OPERATIONS.md | Season loop and league rules | Legal budget/cap/roster transactions; AI values needs/window/replacements | Illegal transaction rejection and trade-exploit cases |
| GM scouting/draft/development | Partial (tested junior scouting slice) | 2,727 eligible NA juniors, three daily observations, next-day preliminary reports; draft/development missing; GM_OPERATIONS.md | Player histories and eligibility | Uncertain scouting; non-linear age/usage/health/context progression | Multi-season roster, scoring, prospect and finance invariants |
| GM playoffs/history/legacy | Partial (single-season game record lists only) | Saved highest-scoring games/largest margins; playoffs, all-time player history and awards missing | Schedules and event/stat ledger | Valid postseason and durable awards/records/retirement | Multi-season bracket and record reconciliation |
| Career journey | Missing | No original-player minor/junior/pro career identified | Saves, league eligibility and development | Create -> minor practice/game -> review -> opportunity; later tier progression | Saved vertical slice then multi-year eligibility/legacy tests |
| Career trust/progression | Missing | No coach trust/skill development choices identified | Career events and role model | Teamwork/positioning rewarded; selfish padding not dominant | Compare balanced/defensive/selfish play scenarios |
| Equipment art/customization | Partial | Imported gear and original kit; visual owner active | Asset fit, equipment IDs and saves | Correct fit/animation, usable edits and persistent cosmetics | Clip/pose reviews and equipment save/load; specialist approval |
| Arena/presentation | Partial | Broadcast HUD, multiple cameras, arena/lighting work active | Presentation owner and menu interfaces | Readable puck/text, coherent menus/intermissions/results/replays | Actual render review and full navigation playtest |
| Audio/crowd/chants | Partial | Original 33-cue procedural on-ice bank, bounded spatial routing/priority/pause and saved effects volume; crowd remains visual cutout foundation; HOCKEY_AUDIO.md | Original/licensed audio assets and event priorities | Varied context-aware spatial layers; chants respond without constant peaks | Mix/priority/event coverage and human listening tests |
| Input/controller | Partial | Keyboard/mouse and mapped gamepad adapter; radial deadzone/disconnect code | Settings/remap and physical devices | Rebind/sensitivity/deadzones, correct prompts, hot-plug recovery | Synthetic checks plus physical controller sessions |
| Accessibility | Partial | Persisted reduced-motion fixed view/flash suppression, optional puck indicator, explicit preferences focus loop, volume/dead zone; no full compliance/remapping claim; DEVELOPMENT_RESEARCH.md | Settings and UI ownership | Text/puck cues, hold/toggle, reduced motion, audio/subtitles as needed | Accessibility checklist and user testing; feature-by-feature evidence |
| Performance | Partial | Reproducible cloud GM CPU profile identifies snapshot I/O/validation as a main-thread stall; league-day saves moved to data worker; no consumer/render FPS claim | Runtime and representative hardware | Published workload/hardware/frame-time and sim-throughput baseline | Full-match profiling with repeatable seeds; before/after evidence |
| Multiplayer | Missing | No local/online multiplayer system identified | Separate authority/input/network design | Explicit local acceptance first; online separate scoped production stream | Multi-device/local ownership then latency/authority tests if authorized |
| Build/platform/release | Partial (tested Linux check pipeline; distribution pending) | Checksum-verified Godot installer, shared full/smoke runner, JSON/JUnit logs and GitHub workflow; 39 engine suites/31 Python tests pass locally; hosted CI not yet observed | Working runtime, CI, target hardware and rights inventory | Reproducible installable build, notices, recovery and platform checks | Clean-machine Windows build/playtest; official platform requirements |
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

## HL world expansion — 2026-10-20

The current snapshot expands to 32 HL clubs, 64 farm clubs, 218 junior clubs, 169 European clubs and 160 youth clubs. Player development profiles and draft-pool queries are implemented data; multi-season GM/Career, player development/scouting simulation and draft transactions remain Missing. Youth match gameplay remains unimplemented and hidden from Play Now. Full scope and evidence: HL_WORLD.md.

## Interface/shooting/tie-break checkpoint — 2026-10-20

Shared HL exhibition OT/shootout and net-targeted wrist/slap controls implemented and tested. Menu/HUD and arena fonts bundled; interface corners, focus, selectors and matchup preview revised and genuinely rendered. UI/presentation remains Partial against production goals. Physical-controller feel, full shootout skating violations, whistle-based OT normalization, league-specific rules, human evaluation and release gates remain open. Exact tests/captures and blocked EA source verification: CONTROLS_AND_TIEBREAKS.md.


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


## 2026-10-20 — persistent HL GM regular-season slice

Codex, codex/game-modes / PR #2. Preserved prototype ed82395 (Claude's goal-net
realism, goal celebrations and hockey stops) via history merge 0bc173b, resolving
script conflicts by retaining both goalie blade clearance and stop reach, and both
roster and celebration imports. New game-mode/persistence scripts, native settings
and GM scenes, match handoff/results and title entries; no new art/animation work.
Implemented a 32-club/62-game season with deterministic fixture simulation,
standings, played-game recording, full-world save snapshots and independent camera/
dead-zone preferences. Save staging/backup/recovery/migration and failure rollback
are exercised; unsupported saves protected. Full scope/gaps: GM_SEASON.md.
Current tests/captures: verification/gm-season-20261020.json. Native mode renders use
Mesa softpipe after default llvmpipe SIGILL; arena graphics are not validated by
these captures. No PR merge/release/public availability change.
Next: physical-controller/human feel, save latency and cross-platform durability,
then richer calendar/playoffs/transactions/draft/development/multi-season rules.


2026-10-20 continuation — Added saved-world Roster room: all 643 clubs/14,745
players, organization affiliation/rights filter, 3,256 age/rights-eligible draft
candidates, league/team/name/position search, paginated rows and full player cards.
Youth data remains browse-only; no drafting/development/transaction claims.
Native browser checks: 3,274, including byte-equivalent season preservation,
page/focus recovery and real dashboard round trips. Captures and scope: GM_SEASON.md.


Final integrated checkpoint — Preserved prototype 3c97c3e overhead-camera fixes
and 3c324a4 skate/stick improvements as well as ed82395 celebration/net/stops.
Thirty engine suites passed; optional mocap skipped; 21 Python tests passed.
Final controller recheck passed after separating stick dead zone from trigger
activation. Evidence and intentional failed-write diagnostics are recorded in
verification/gm-season-20261020.json. Roster/prospect pages were rendered and
inspected; a full 3D softpipe title capture timed out without a usable image.
No 3D quality/performance or hardware-controller approval is implied.


## 2026-10-20 — realism/audio continuation

Owner: Codex, codex/game-modes / PR #2. Owner requested sustained improvement
toward a realistic title; no unattended scheduler is available, so no work between
active turns is claimed. Preserved prototype 3c324a4; presentation source untouched.
Added 33 original procedurally authored audio samples, spatial bounded event pool,
shot/pass/contact/stop/check/whistle/horn routing, saved volume/mute and backward-
compatible preferences. HOCKEY_AUDIO.md gives exact coverage and human-listening gaps.
Runtime/quality evidence: verification/realism-audio-20261020.json. Actual preference
UI captured with Mesa softpipe; full arena still aborts in the current llvmpipe
runtime. A 128-bit diagnostic probe passed but did not establish a working game
renderer; no fresh 3D photo or fixed-renderer claim. No PR merge/release.
Next: human listening/mix iteration, more skating/crowd event layers, renderer
native crash diagnosis, then remaining realistic controls/rules and GM systems.


## 2026-10-20 — source-backed usability/performance increment

Codex, codex/game-modes / PR #2, preserved prototype 3c324a4. Reviewed five official
Godot 4.6 documentation sources at b10b7ed, not blocked public/XAG pages. Added
preferences focus neighbors, reduced-motion camera/menu/banner/goal-flash behavior
and optional black/white puck cue in match/Practice. Measured ~5.6 s full snapshot
backup save versus ~13 ms season simulation; moved UI day checkpoint to isolated
data worker with duplicate guards and failure preservation. Genuine JPEG before/
after/in-progress/completed captures; see DEVELOPMENT_RESEARCH.md and verification
/research-implementation-20261020.json. No new plugins needed, no art/animation
replacement, no PR merge/release. Full 3D renderer/hardware comfort remain open.


Final research integration — Preserved aa2e25d seated benches/penalty boxes via
history merge 58fd6df. 34 engine suites passed and optional mocap skipped; 24
Python tests passed. Accessibility recheck: 31 assertions; checkpoint: 10.
Isolated snapshot-worker remeasurement: ~105 ms main-thread launch, ~5.75 s
overall (copy hitch and total save latency remain explicit). JPEGs are actual
native UI captures, not gameplay renders. See DEVELOPMENT_RESEARCH.md.

## 2026-10-21 — helmet equipment review

Equipment art/customization remains **Partial** overall. Reference-guided helmet
construction is implemented and tested (99933f1): lower crown, horizontal vents,
clear ear frames and retention hardware; approved visor preserved. Genuine native
neutral/arena JPEGs and checks: HELMET_REFERENCE_REVIEW.md and
verification/helmet-reference-20261021.json. Authored anatomy, customization/save
coverage, distance LODs/hardware performance and specialist review remain open;
this is not release-ready equipment art.

## 2026-10-21 — mode expansion and collar repair

Knockout Cup and standalone Shootout are **Functional** bounded modes, implemented
and tested through actual scene/results/return paths. Cup has a separate validated
atomic save, seeded eight-club bracket, mixed play/simulation, champion and retry/
backup recovery. Shootout uses existing real on-ice attempts and rematch. Neither
implements GM playoffs, Career or online play; those remain missing/partial as
above. Equipment art remains **Partial**: collar/neck guard fit and the matching
cloth trim shader are repaired, not release-ready anatomy. See GAME_MODES.md and
verification/collar-cup-20261021.json for exact checks and genuine JPEG provenance.

## Team tactics checkpoint — 2026-10-21

Six selectable tactical categories now affect actual on-ice AI targets and puck
decisions. See TEAM_TACTICS.md for scope, screenshots, evidence and remaining
advanced behavior. This improves the partial tactics row; it does not complete
AAA-level AI, simulator tactics or persistent GM coaching.

## Goalie equipment/motion checkpoint — 2026-10-21

Goaltending remains **Partial**. Added Compatibility atlas-filter artifact repair,
flatter pad construction/binding, goalie leather finish/tangents, eased drop/save
motion, no-clip shuffle fallback and regulation contact-gated catcher fold with
frozen-puck follow through the whistle. Mask/hinge/anatomy and post/recovery work
remain open. GOALIE_EQUIPMENT_POLISH.md distinguishes actual engine inspection
captures, tests and remaining limitations; no AAA goalie realism claim.

## Owner-corrected goalie construction — 2026-10-21

Removed detached hinged thigh rises; production pads are continuous full-length
shells with boot coverage and matching contacts. Measured adult mitt/web resized;
physical pocket gate follows it. Blade/paddle/shaft share a solid visible heel.
GOALIE_PROPORTIONS.md supersedes earlier pad-folding descriptions. Goalkeeping
remains Partial; fresh external reference access was blocked, and dimensions are
measured original targets rather than a verified manufacturer replica.
