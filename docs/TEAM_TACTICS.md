# Team tactics

During a match, press **Esc → Team Strategies**. Select either club and choose its
six systems. Changes apply on resume. Native keyboard/focus navigation is supported;
physical-controller feel and match balance still need human playtesting. Choices
survive rematches and scene changes within the process; they are not yet written
into GM saves or restored after quitting the application.

| Category | Choices | Effect |
|---|---|---|
| Offensive zone | Cycle, Overload, Crash the net | Wide passing support, strong-side concentration, or multiple net-front targets, with point safety |
| Defensive coverage | Protect the slot, Tight point, Man coverage | Compact middle coverage, higher coverage of points, or separate goal-side marks away from the puck threat |
| Forecheck | 1-2-2, 2-1-2, 1-3-1 | One pressure player plus different support/safety layers; 2-1-2 sends a second player higher |
| Breakout | Wide support, Center swing, Stretch | Different outlet widths/depths while the carrier exits the defensive zone |
| Power play | 1-3-1, Umbrella, Overload | Separate point, flank, bumper/net-front stations; the carrier's nearest station is left vacant |
| Penalty kill | Box, Diamond, Pressure | Lane/crease protection, diamond spacing, or nearest-player pressure; three-skater PK falls back to a triangle |

The pure `scripts/team_tactics.gd` planner works in attacking coordinates, mirrors
on end changes, and returns target/role/phase for each active player. The match
feeds actual legal manpower from MatchState rather than interpreting a line
change as a penalty. Bench/hopping/penalized players are excluded. The controlled
player is included in team assignments but never moved by the AI. Existing bench
and board-hop handling is preserved.

Possession selects offensive support, breakouts or defensive/forecheck jobs;
manpower selects special teams automatically. Support holds behind the attacking
blue line during controlled entries. Targets stay inside the rounded rink and
recovery can reach behind the net. Three-/four-skater transitions retain a safety
instead of using five-forward station assumptions. Forecheck support ranks exclude
the pressure player so a defenseman pursuing the puck does not remove a safety.

Carrier decisions use physical opponent distances and pass/shot lane checks.
Breakout carriers seek open outlets; under pressure or with a blocked shot they
can pass to a clear teammate. Shorthanded carriers seek a forward outlet or clear
up ice when no useful outlet is available. Passes, shots and clears act on the
same puck through existing release functions. AI movement uses the same skating,
stamina, stun and collisions; targets do not teleport players or award possession.
Assignments are available as `match.tactical_plans` and actor metadata for further
inspection. The AI planner is for on-ice matches, not the aggregate GM/Cup simulator.

## Evidence and limits

- [Coaching menu](screenshots/tactics-coaching-20261021.jpg): real native pause UI.
- [Special-teams inspection](screenshots/tactics-special-teams-20261021.jpg): real
  arena/players placed at actual planner stations, with temporary inspection labels.
  This is explicitly staged, not a live-play quality claim.
- `tests/test_team_tactics.gd`: all 18 choices alter assignments; legal target
  bounds, end reversal, manpower/bench distinction, entry support, behind-net
  recovery and reduced-player safety.
- `tests/test_tactics_match.gd`: native UI/team independence, actual skating,
  human control preserved, bench/penalty exclusions, PP/PK activation and expiry,
  blocked lanes, actual breakout pass and shorthanded clear.
- Run/capture provenance: `verification/team-tactics-20261021.json`.

This is a functional first tactical layer, not a completed AAA AI system. Further
work includes phase/pursuer hysteresis, sustained cycle rotations, rehearsed set
plays, richer opponent-specific adaptation, coach/club profiles, persistent GM
coaching plans, and longer human/controller tuning. Man coverage is a lightweight
assignment heuristic rather than a full optimized switching/communication model.
No hardware performance or networked determinism claim is made. Production/tests
use Godot 4.6.3; the diagnostic llvmpipe screenshots use official 4.6.2, consistent
with the existing renderer workaround. No new plugin or paid asset is needed.
