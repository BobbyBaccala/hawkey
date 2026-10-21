# GM front office: current scope and next milestones

2026-10-20 owner-requested continuation on `codex/game-modes`, draft PR #2.
Original implementation; Claude's presentation work through prototype aa2e25d
is retained. This is an alpha increment, not AAA parity or a complete CBA.

## Playable increment

Open **GM Season → Front office** from an existing/new season.

- **Free agents:** 64 additional original adult professionals, positional filters,
  estimated ability, salary/term requests and editable offers. Meeting the request
  accepts immediately; this is not negotiation or competing AI bidding.
- **Contracts:** every initial HL player has an original generated contract
  (736 total). See annual salary, stored term and dressed/reserve status. A signing
  updates payroll, organization browsing, automatic depth, scheduled-game actors
  and subsequent simulation strength. Stable IDs persist through resume.
- **Team statistics:** all 32 clubs; games, points, GF/GA, goal difference,
  per-game scoring/conceding, points percentage, home/away wins and team shutouts.
  Sort by points, scoring rate, conceding rate, difference or shutouts.
- **Season records:** highest-scoring games or largest winning margins, derived
  from saved finals with stable-ID tiebreaks. These are single-season results,
  not all-time player records.
- **Junior scouting:** 2,727 eligible North American junior prospects in this
  initial world; search, pagination, three assignments per league day, reports
  after advancing the day. Reports show preliminary speed, shot accuracy (or
  goalie reflexes) and potential ranges. Assignments and reports survive saves.
  This is a first scouting loop, without regional staff, travel or repeated
  observations. The existing roster room still exposes full estimated ratings;
  a hidden-information career mode is not claimed.

All new offers/assignments save through the isolated checkpoint worker. Live
state changes only after validated staged save/atomic replacement succeeds.
Duplicate clicks, open played-game handoffs and pending results are guarded.
Failure retains the previous roster, budget and disk checkpoint. Closing the page
joins the finite worker. Snapshot copying still occurs on the main thread;
this does not eliminate every hitch or reduce the underlying disk latency.

## Explicit HL alpha contract policy

The versioned preset currently uses a **$104M ceiling**, **$1M minimum**,
**$20.8M maximum individual annual salary**, **one-to-five-year flat contracts**
and **50 organization contracts**. These are provisional HL design values,
not a newly verified statement of the 2026–27 NHL rules. Initial salaries/terms
are fictional deterministic estimates, not actual players' contracts.

All organization contracts count at full annual value. There is currently no
cap floor, daily cap accrual, retained salary, buried relief, bonuses, LTIR,
entry-level/RFA/arbitration rules, buyouts, no-move/no-trade clauses or real CBA
assignment/waiver logic. Automatic positional depth selects 23 players and dresses
20; others are reserves without a simulated farm assignment or waiver process.
Term is persisted but cannot yet expire because offseason/rollover is missing.
The cap preset and these simplifications are visible on the actual pages.

The immutable 643-club world remains unchanged. Management is a validated overlay
with a fixed original market and a replay-validated transaction ledger. Legacy
GM saves without management are upgraded deterministically **in memory**; only an
explicit successful subsequent save writes it. A future unknown/corrupt management
version fails validation rather than resetting the economy. JSON integer/float
round trips compare finite numeric values without coercing strings or booleans.

Scouting jobs reference eligible saved-world identities, cannot duplicate a
prospect or exceed three jobs per day, and cannot reference future days. Reports
are deterministically derived from those observations; reloading does not reroll.

Team rates and records come from actual saved fixture finals. Shootout game finals
include the deciding goal, as the existing standings do. We do **not** invent
player goals/assists, goalie save percentages, shots or special-team rates from
final scores. Those need a consistent per-game event/statistics ledger shared by
played and simulated games, followed by player/team history and record screens.

## Research status and broad feature target

Official-site requests made this run:

| Entry point | Result | What is established |
|---|---|---|
| https://www.ea.com/games/nhl/nhl-26 | Proxy CONNECT 403 | No NHL 26 page content read this run |
| https://hockeylegacymanager.com/ | Proxy CONNECT 403 | No HLM 26 feature list read this run |
| https://www.nhl.com/news/nhl-nhlpa-announce-team-payroll-ranges-for-next-3-seasons | Proxy CONNECT 403 | No cap/CBA announcement verified this run |

The following is an **original coverage roadmap based on the owner's request**,
not an attributed list of features verified in NHL 26/HLM 26. The existing
BENCHMARK_CATALOGUE.md records earlier research separately; it does not substitute
for the requested edition-specific research. Official feature lists and the
current NHL/NHLPA CBA must be read before asserting exact feature/rule parity.
No proprietary code, branding, player likenesses or recordings imported.

| Area | Current status | Next acceptance milestone |
|---|---|---|
| World, feeders, juniors, Europe, youth | Functional original data; youth browse-only | Eligible transfers/development across saved seasons |
| Schedule, standings, play/sim, save/resume | Functional single HL regular season | Calendar/rest days and league-specific formats |
| Free agency and contracts | Functional defined HL alpha subset | Offers/counteroffers, competing AI needs/budgets, renewals |
| NHL-based financial rules | Partial provisional HL preset; verification pending | Verified dated cap/floor/CBA policy, variable salaries, bonuses, clauses, ELC/RFA/UFA/arbitration |
| Roster management | Partial automatic depth | Manual lines, active/reserve/farm assignments, eligibility/waivers, injuries/IR/LTIR |
| Transactions | Free-agent signings only | Trades, picks, retention, buyouts, transaction history UI and anti-exploit tests |
| Scouting | Functional one-day junior reports | Regional staff/budgets, repeated observations, reports dashboard and uncertainty calibration |
| Draft | Eligible pools/browsing only | Pick ownership, order/lottery, live draft, AI selections, rights ledger |
| Player development | Estimated potential only | Nonlinear age/usage/coaching/health model, training, injuries and prospect replenishment |
| Statistics | Team finals/rates and game-record lists | Event-backed player/goalie/special-team stats, splits, histories and league leaders |
| Postseason and long-term history | Missing | Seeded brackets, valid series, rollover, awards, records, retirement and legacy |
| Staff/organization | Missing | Coaching/scouting roles, systems, budgets and owner objectives |
| Editors/customization | Missing | Validated undoable editing, custom leagues/expansion, export/import with stable references |
| Career | Missing | Original minor/junior player, practice/game/review, roles/contracts and persistent progression |
| Gameplay | Partial; see ALPHA_FEATURE_AUDIT.md | Full rules/tactics/goalie/physics scenarios, remaining controls and physical playtests |
| Practice/presentation/audio | Partial | More drills, context crowd/announcements, replay/intermission/results depth |
| Accessibility/platform/online | Partial local preferences; online missing | Remapping/device recovery, human tests, export/performance and separately scoped networking |

First next engineering target: authoritative played/simulated player-stat ledger,
then player leaders/history pages; drafted rights and multi-season eligibility
must share that foundation. Full franchise parity requires many further tested
increments, not extra empty buttons.

## Verification and genuine JPEGs

`tests/test_gm_management.gd` covers offers, exact cap deltas, signed lineup,
reference/ledger corruption, JSON save/resume, older-save initialization, failed
writes, duplicate guards and native pages. `tests/test_gm_scouting.gd` covers
eligibility, capacity/duplicate/future references, next-day observations, goalie
skills, report persistence, search and actual assignment saves. Existing save,
season, roster/navigation, checkpoint and full-game regressions remain required.
Final results: `verification/gm-operations-20261020.json`.

`tools/capture_gm_office.gd` renders real native Godot pages in a throwaway ten-day
season under `build/`, signs one player, and captures market/contracts/statistics/
records/scouting as JPEG. No real user save is touched. Images are UI progress,
not new 3D gameplay renders or proof of consumer GPU performance. The cloud 3D
renderer and physical controller feel remain unverified. No additional plugin
was needed for the implemented Godot functionality.


Final combined build: preserved prototype 040ef91 bench animation/numbers via
merge 6b9b818; 36 engine suites pass, optional mocap skipped, 24 Python tests pass.
Management 160 checks and scouting 2,755 checks passed in the integrated build.
Capture source tree is the front-office increment (85bff90); subsequent bench
integration does not change these native UI pages.
