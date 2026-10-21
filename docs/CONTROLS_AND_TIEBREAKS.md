# Interface, net shooting and tie-break checkpoint

2026-10-20, America/Toronto. Alpha, locally integrated on codex/game-modes / PR #2.

## What changes for the player

The title, selectors, focus states, score bug and event surfaces use a consistent
navy/teal palette, rounded panels, restrained borders and licensed bundled regular
and bold fonts. A matchup card previews the selected home/away clubs. Arena text
uses the same font family; existing arena geometry, lighting, equipment and animation
work is retained. Jersey numbers render as integers. The menu camera hides overhead
rigging so the scoreboard does not cut into the screen edge.

Shots now select a point inside the attacking goal mouth, independent of the
skater's facing. A small net reticle shows the selected placement in Play Now.
Shots are free rigid-body trajectories: goalkeeper saves, posts, screens, physical
contacts and air drag still affect the result. Net targeting is not a guaranteed goal.
Passing and clearances remain directional.

| Input | Action |
|---|---|
| Left stick | Skate; on a shot, horizontal selects shooter's left/right and up selects high |
| Neutral left stick | Centre of the net |
| RT / R2, with possession | Hold for pass strength; release to pass (12–24 m/s bounded profile) |
| RT / R2, without possession | Switch player on press; release cannot turn into a pass |
| Right stick flick up | Wrist shot |
| Right stick down, then flick up | Fixed slap-shot profile |
| Right stick sideways | Existing stickhandling |
| Mouse position + left click | Net placement and immediate wrist shot |
| Alt + left click | Slap shot |
| RB / R1 | Saucer pass with possession; poke check without possession |
| Right-stick flick, opponent possession | Body check; does not shoot |
| B / ○; X / □ | Forward line; defence pair |
| L3 | Hustle |
| Right click | Keyboard/mouse pass |
| View / Back | Toggle controls overlay |

Wrist/slap profiles use the player's estimated `shot_power` value, with bounded
launch speeds and a ballistic height solution for the selected net point. The old
shot charge-to-power curve is removed; only passes gain strength while held. Other newly authored hockey ratings remain future
simulation data unless separately connected. There is no claim of calibrated shot
realism, production slap-shot animation, or tested physical-controller feel.
Practice shares the same shot solver and controller adapter, including trigger
hysteresis/deadzones and disconnect clearing; Play Now also shows the net reticle.

## Original HL exhibition tie-break policy

- Three 20-minute regulation periods at the existing prototype clock rate.
- A tied third period leads to an intermission and five-minute sudden-death overtime.
- Overtime is three-on-three with a defender represented on each side. Penalty
  differences add skaters to the advantaged side (4v3 or 5v3), never below three.
- A goal ends overtime immediately. Penalty expiry returns directly to the derived
  strength. Whistle-delayed 4v4/5v5 normalization and full league/CBA exceptions are
  not implemented by this increment.
- A tied overtime starts a playable shootout: one shooter and the opposing goalie,
  home controlled by the player and away controlled by the existing skating/goalie AI. A dedicated camera frames the complete shooter and net with a safe screen margin on both sides.
- Three attempts per side, early clinch when mathematically decided, then paired
  sudden-death rounds. The opponent receives its matching attempt before a lead in
  sudden death wins. Shooters rotate through distinct dressed skater IDs before reuse.
- Each attempt has a real-time 20-second limit, stops on a physical goal or resolved
  miss, and accepts one shot. The shot flight uses the shared puck mechanics. Rebounds
  can continue into the net briefly; the player cannot take a second shot or reattach
  possession after releasing. Complete referee enforcement of all shootout skating
  violations remains future work.
- The attempt ledger records team, stable player ID and conversion. Attempts do not
  inflate match shots/player goals. The winning side receives exactly one deciding
  game-score goal. Results identify OT/SO decisions and show shootout conversions.
- Pause freezes the attempt timer. Rematch creates fresh match/tie-break state while
  retaining the selected clubs. All selectable leagues currently use this shared
  exhibition preset; accurate individual European/junior rules are not claimed.

## Research status

The owner requested EA NHL-style left-stick shot placement and consultation of EA
references when resolving issues. The attempted official reference was
https://help.ea.com/en/articles/nhl/nhl-26/controls/ . The current runtime proxy denied
the CONNECT request (HTTP 403) before the page could be read; the URL/page contents
and edition-specific controls were not verified. The existing benchmark catalogue
records older research separately.

The owner supplied the NHL 23 PS4 controls URL:
https://www.ea.com/able/resources/nhl/nhl-23/ps4/controls . The direct fetch was
blocked (CONNECT HTTP 403). The owner then provided seven readable in-game controls
screenshots (2026-10-20 15:23–15:25 filenames, two batches), which are the actual
visual reference reviewed for the mapping correction. Their Skill Stick tables
show LS movement/shot/pass aim, RS shooting/dekes, R2 passing/defensive switching,
R1 saucer/poke, L3 hustle, circle/square line changes, L2 vision control, L1 modifiers,
and contextual faceoff/defensive/advanced deke actions. The screenshots do not
independently establish the edition of the depicted build; NHL 23 PS4 identifies
the supplied URL. No page content was fetched or claimed verified.

The implemented subset above replaces the earlier R2-shot/R1-pass layout in both
Play Now and Practice. Resting at neutral for 150 ms cancels a right-stick backstroke; passing through
neutral during a continuous slap gesture preserves it. Pause, loss of
possession and disconnect cancel armed match passes. Practice uses the same bounded
pass strength and saucer loft. D-pad line controls remain a prototype extension.
The shown advanced dekes, protection/bracing, vision control, stick lifts, blocks,
manual directional switching, faceoff grip/timing/gestures, desperation double taps
and detailed line-selection menus remain unimplemented. R3 stopping was removed
from the controller mapping to avoid conflicting with the reference; keyboard
braking remains available. These screenshots guide original mechanics, not a claim
of complete EA feature or controller-feel parity.

Saved additive environment allowlist requirements: `help.ea.com`, `www.ea.com`,
`media.contentapi.ea.com`. Saving the draft does not activate runtime access. Review
and save the environment network settings before the official lookup can be retried.
No unverified EA implementation details, assets, code or exact-control-parity claims
are used here. The controls and HL rules above are original implementations of the
owner's requested behavior, and this research prerequisite remains explicit.

## Validation and captures

21 Python tests and 23 engine suites passed; optional mocap playback skipped. Net shooting: 132 checks passed; overtime/shootout: 75 checks passed, including the final camera-framing correction; navigation: 47 checks passed.

Final executed results are in [verification/polish-shooting-tiebreaks-20261020.json](verification/polish-shooting-tiebreaks-20261020.json).
Focused checks cover ballistic goal-plane targeting from multiple positions at both
ends and every corner; actual free-puck crossing; sideways facing; mouse press/release;
controller quick shots, no held charge/repeat, slap gesture, Practice and disconnect;
regulation/OT/final transitions; OT manpower; shootout early clinch, equal sudden-death
attempts, stable IDs, timeouts, duplicate rejection, no second shot, goalie ownership,
actual home and AI attempts, stat separation and pause.

Genuine engine captures from `tools/capture_polish.gd` show the title, match, overtime,
shootout and results. The capture tool advances clocks and supplies deterministic
attempt outcomes for UI inspection; these are not recordings of a human-completed
match. Linux Xorg dummy / Mesa llvmpipe / OpenGL compatibility only. Controller tests
use synthetic events. Windows, Steam Deck, hardware controllers, human feel and
production performance remain unverified.

Fonts are unmodified DejaVu Sans files distributed under their included licence in
`assets/fonts/LICENSE.txt`. They load on the main thread through `FontFile.data` and
use Keep import metadata, after this Godot build crashed in parallel font importing.
The supported runtime loader was tested; no artifact/TLS verification was bypassed.
Future export presets must include the raw font files; no packaged export is claimed.

Screenshots: [title](screenshots/polish-title-20261020.png), [match](screenshots/polish-match-20261020.png), [overtime](screenshots/polish-overtime-20261020.png), [shootout](screenshots/polish-shootout-20261020.png), [results](screenshots/polish-results-20261020.png).

## Concurrent net integration

Claude's prototype `b5a292a7a66d339640b513eaee2e1e16b0e88bc2` arrived during
this run and is reconciled in the mode branch. Its net geometry, shader, padding
and ripple implementation are retained. The net material is marked absorbent so
its restitution subtracts from the puck material instead of adding energy; this
prevents the new higher-trajectory shots from rebounding back out of the net.
The goal-net test now explicitly selects neutral/centre aim to isolate back-net
containment/ripple under the new shot controls. All original containment, scoring,
ripple and decay assertions are retained. Initial integration failure and focused
rechecks are recorded separately in the verification JSON.


## Screenshot-guided control validation

Eight focused engine suites passed after the control correction: controller, net
shooting (135 checks), overtime/shootout (75), match, match loop, Play Now (47),
Practice and goal net. Initial fixture failures and final rechecks are recorded in
[verification/skill-stick-20261020.json](verification/skill-stick-20261020.json).
These are synthetic/headless checks; physical-controller feel remains untested.
