# Sports benchmark catalogue and original acceptance requirements

Research date: 2026-10-20. Work stage: research/design only; none of the requirements below is newly implemented. Publisher descriptions establish documented features, not independent evidence of feel, balance or quality. No copyrighted code, imagery, recordings or brands imported.

## Edition/platform/source register

| ID | Edition and platform | Primary source | Publication/access |
|---|---|---|---|
| E27G | NHL 27, PS5 / Xbox Series X/S | https://www.ea.com/games/nhl/nhl-27/news/nhl-27-gameplay-presentation | Published 2026-08-25; read 2026-10-20 |
| E27F | NHL 27 Connected Franchise, PS5 / Xbox Series X/S | https://www.ea.com/games/nhl/nhl-27/news/nhl-27-connected-franchise | Published 2026-08-12; read 2026-10-20 |
| E27C | NHL 27 Be a Pro; edition-wide help, no separate platform variant asserted | https://help.ea.com/en/articles/nhl/be-a-pro-progression/ | Page says updated one month ago; read 2026-10-20 |
| E27D | NHL 27 Be a Pro; edition-wide help | https://help.ea.com/en/articles/nhl/be-a-pro-guide/ | Page says updated one month ago; read 2026-10-20 |
| E25F | NHL 25 Franchise, PS5 / Xbox Series X/S | https://www.ea.com/games/nhl/nhl-25/features/franchise-mode | Historical reference, read 2026-10-20 |
| K26F/K26P | NBA 2K26, platform scope in linked announcements | Sources already documented in GAME_MODES_BACKLOG.md | Previously reviewed 2026-10-20; not re-read this run |

### Documented observations

E27G: EA describes team-specific playbooks, cooperative retrieval/support, defensive partner coverage, fatigue-aware changes and score/time-dependent tactical shifts. It also describes contextual broadcast direction and arena reactions, more varied contact and changes intended to constrain repeated pivot exploits. Do not infer Hawkey has comparable tracking data or copy the proprietary implementation.

E27F: The online mode documents configurable league structure, shared/custom rosters, lineup tools, trades, free-agent bids and transaction oversight. It includes standings/box scores, playoffs and offseason transitions. Online commissioner features are not evidence of a complete offline GM economy and do not establish real-world CBA accuracy.

E27C: Career documentation links performance feedback with opportunity, development and recovery choices, and skill progression. It distinguishes offense, defense and team-play feedback and describes role consequences. These are design references; Hawkey must define its own scoring and balance.

E27D: The documented career entry is the World Juniors medal round followed by draft-stock evaluation and a roster opportunity. This does not establish a playable minor-to-junior journey. Hawkey's earlier starting tiers remain an original requirement.

E25F: The historical franchise page describes a central statistics hub, playstyle changes with tradeoffs, development goals and per-year contract movement restrictions. Do not assume every historical detail carries into NHL 27 or applies to every mode.

## Original Hawkey requirements

The following are proposed measurable acceptance tests, not claims about EA internals or Hawkey implementation.

| Category | Reference | Original requirement | Acceptance evidence |
|---|---|---|---|
| On-ice movement/contact | E27G | Keep movement tradeoffs physically consistent and legal contact angle-aware | Repeated pivots cannot accelerate a player; measure glancing/board contact and inspect recovery |
| Controls | Research pending | Rebind keyboard/controller actions with independent sensitivity/deadzone settings | Changed bindings survive restart; defaults and cancel restore correctly; disconnect during shot clears charge |
| Tactical AI | E27G | Separate coach policy from five-player assignments | When a defender pinches, a support assignment covers the vacated area; seeded trace shows the cover |
| Team identity | E27G | Original carry/dump, pressure and risk profiles | Identical scenarios produce profile-specific entry decisions; differences visible in logged intent, not hidden speed boosts |
| Fatigue/late tactics | E27G | Legal fatigue-aware line selection and score/time risk policy | Trailing/leading versions of the same fixture select different policies; players/counts remain legal |
| Player differentiation | E27C; K26P | Attribute descriptions explain strengths, limits and development | Isolated rating tests change the intended outcome distributions; no guaranteed goals |
| Signature abilities | E27C as conceptual reference | Original named traits with bounded triggers and counterplay | Boundary and disabled-trait scenarios prove effect and limits; tooltips match the simulation |
| Equipment | Research pending | Stable cosmetic equipment IDs shared by match/menu/save | Save/reload preserves colors/handedness; pose sweep verifies fit; cosmetics do not modify ratings |
| Career entry | E27D contrast | Generated minor player advances through age-appropriate leagues | Eligibility and season transitions reject impossible jumps; no real children in generated starting population |
| Career feedback | E27C | Show offense/defense/teamwork components and concrete reasons | A defensively responsible low-scoring fixture can earn trust; cherry-picking cannot dominate every component |
| Career recovery | E27C | Training/recovery choices with explicit opportunity cost | Development/recovery deltas reconcile in save; reload cannot duplicate rewards |
| GM dashboard/history | E25F; E27F; K26F | One ledger feeds results, standings, player history and records | Rebuild aggregates from events and compare; sim/play/save-resume yield consistent totals |
| Contracts/trades | E25F; E27F | Data-driven restrictions, reasons for rejection and atomic transactions | Invalid contract/trade leaves every roster/budget unchanged; clause years checked against season |
| League setup/editors | E27F | Validated configuration plus immutable per-save roster snapshot | Later global edits cannot silently mutate an existing career or GM save |
| Draft/development | K26F; owner scope | Imperfect scouting and contextual development | Scouts differ within uncertainty; multi-season simulations preserve legal rosters and prospect supply |
| Practice | Owner scope; benchmark detail pending | Resettable drills using match physics | Same shot/contact scenario behaves the same in practice and match; reset clears timers and objects |
| Presentation | E27G | Context event priorities rather than repeated interruptions | Goal/penalty/save events select appropriate original sequences; no gameplay input blocked after dismissal |
| Audio/atmosphere | E27G | Original context-aware home/away crowd layers | Reactions and mix respond to score/chance/penalty events; listening test checks repetition and peaks |
| Accessibility | Research pending | Scalable text and puck cues independent of color; reduced motion | Test all mode screens at target scale; identify selected team and puck without color |
| Platform/multiplayer | E27F is console online reference only | Treat online and platform compatibility as separately scoped engineering | No compatibility claim before clean-machine/device tests; online authority/latency tests required before promise |

## Scope boundaries and next research

Current NHL 27 official sources are now distinct from historical NHL 25 and earlier 2K26 research. Still needed: official current control/accessibility documentation, equipment/customization details, practice modes, detailed statistics and platform requirements. Confirm patch-specific changes separately; no exhaustive current-feature parity claim is made. Revisit NBA 2K's current edition before treating 2K26 as current. No gameplay footage was evaluated during this run.

Engineering checkpoint remains native roster loading and a full fictional two-team fixture. Career feedback, transaction legality and tactical coverage requirements become tests when their dependent systems exist; do not add empty screens to suggest completion.

## Control-reference follow-up — 2026-10-20

Owner requested left-stick net placement and separate wrist/slap actions. Attempted
official EA Help controls page; runtime egress proxy denied CONNECT with HTTP 403.
No page content or current-edition control mapping was verified. Additive EA domain
requirements saved to environment draft; runtime access still requires settings
activation. See CONTROLS_AND_TIEBREAKS.md for the original implemented controls,
explicit tie-break policy, tests and remaining research. Do not treat these mappings
or prototype rules as an independently verified replica of EA NHL.
