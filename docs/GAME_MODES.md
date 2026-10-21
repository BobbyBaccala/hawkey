# Playable modes — 2026-10-21

| Mode | Current playable scope | Remaining work |
|---|---|---|
| Play Now | League/team selection, actual roster match, results/rematch, OT/shootout | Rule exceptions and richer setup |
| GM Season | Saved 32-team HL regular season, played/simulated fixtures, management pages | GM playoffs, offseason/rollover, trades, draft/development and player stat ledger |
| Knockout Cup | Eight HL clubs, seeded draw, quarterfinals/semifinals/final, play or simulate, saved champion | Other field sizes, series formats and richer trophy presentation |
| Shootout | Standalone three-round contest, early clinch/sudden death, actual shooter/goalie play, results/rematch | Custom formats; physical-controller feel review |
| Practice | Shared skating, passing and shooting laboratory | Scored drills and coaching feedback |

Career/Be-a-Pro-style progression, online/team play and a separate full GM
postseason are not implemented. A Cup is not a substitute for GM playoffs; no
placeholder buttons advertise those unfinished modes.

## Enter and play

Title → **More modes**. Choose your Cup club and a draw number, then start a cup;
starting again asks before replacing the existing cup slot. With an active Cup,
the bracket and play/simulate actions appear first. Setup and Shootout choices
remain reachable by scrolling. Mouse, keyboard and native focus navigation work;
physical gamepad testing remains open.

Play the next Cup fixture with your selected club whenever it appears; otherwise
you control its home club. All games use the actual match scene, rosters, gameplay
and exhibition tie-break rules (3v3 OT, then shootout). The on-ice controlled club is displayed first; scores are mapped back into the
fixture’s home/away order on saving. The Cup does not claim continuous playoff OT. Simulating records aggregate scores only; it does not
invent player-event statistics. Play/simulate the remaining fixtures after your
club is eliminated to finish the bracket. The seventh result determines a saved
champion; advance buttons then disable.

Shootout uses independent home/away selectors and rejects duplicate clubs. It
starts directly with one shooter and the opposing goalkeeper using existing
on-ice net aiming, skill-stick mechanics and AI attempts. Rematch resets the
contest; returning to the hub/menu clears event routing. It does not change Cup
or GM results. No separate persistent Shootout career/history is claimed.

## Save safety and simulation

Cup slot: `user://cup/slot-1.json`, kind `knockout-cup`, using the existing
checksummed atomic SaveStore envelope and `.bak` recovery. GM remains in its own
slot/schema. Cup state stores the draw, world-file fingerprint and a result log;
loading validates unique eligible clubs, score/decision types, sequential fixture
IDs and replay-derived winners. A changed roster-world fingerprint is rejected.
The loaded world is read-only and never regenerated or changed by these modes.

New Cup/result changes are made on a candidate and committed to the live Cup only
after a verified save. A failed played-result save retains the previous live
bracket and the pending score for a retry from the hub. Simulation, resume and
replacement are blocked while that score is pending. Invalid/duplicate results
cannot advance the bracket. Closing the application before retrying an unsaved
pending result can lose that result; the previous disk save remains intact.

Simulation is deterministic for a saved draw/fixture and uses a simplified speed-
strength/chance model with an explicit OT/SO tie-break. This is an alpha aggregate
simulator, not a calibrated NHL scoring model. No fictional player box scores are
inferred from final scores. Only HL clubs are exposed in these new mode selectors.

## Collar and helmet work in the same checkpoint

`7b19bac` raises the jersey neckline and makes its notch shallower, thins its rolled trim and replaces
the tall flared plastic guard with shorter matte fabric. Its upper endpoint now
uses the posed bind frame, avoiding the old world-up offset stretching it during
a skating lean. `e2f564e` shares jersey_profile.gd between geometry and cloth shader.
A real arena close-up exposed the old deep-V colour mask still painting a large
contrast bib; a rendered-pixel regression now checks team-colour chest versus a
narrow white trim band, with the old profile as a detected negative control.
Helmet panel trim now uses the matte joint material rather than a bright painted
wire. Approved visor geometry/material are unchanged. Broader anatomy/gear polish
remains partial.

## Evidence

- [Collar baseline](screenshots/collar-baseline-quarter-20261021.jpg) / [final](screenshots/collar-final-quarter-20261021.jpg)
- [Arena collar close-up](screenshots/collar-modes-arena-closeup-20261021.jpg)
- [Title with More modes](screenshots/collar-modes-title-20261021.jpg)
- [Cup bracket](screenshots/cup-opening-20261021.jpg) / [semifinals](screenshots/cup-semifinals-20261021.jpg) / [champion](screenshots/cup-champions-20261021.jpg)
- [Standalone Shootout](screenshots/shootout-ready-20261021.jpg)

All are direct Godot 4.6.2 llvmpipe viewport JPEGs. Neutral collar stages use the
same lights/cameras at 960×960; the baseline renders the original `385f02a` visual
script while the old material was still active. Final native UI/arena captures are
1440×900. Cup image scores are explicitly simulated in an isolated demonstration
slot; Shootout is frozen at setup. Arena close-up is a staged model inspection in
the actual scene, not a normal gameplay camera. No generation or image retouching.
Production and CI remain Godot 4.6.3; hardware FPS/Forward+/export review is open.

Verification: `verification/collar-cup-20261021.json`. The broad run, Claude merge
rechecks and final shared-profile/GPU repairs are recorded separately rather than
claiming one atomic final-state run. Source integration preserves Claude through
`85fd791`; CL-20261021-002 acknowledged earlier helmet/strap notes without claiming
a visual review. CX-20261021-008 replies with these changes and remaining gaps.
No PR merge, game release, new plugin or purchased asset was required.
