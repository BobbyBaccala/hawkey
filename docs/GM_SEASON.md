# HL General Manager season alpha

2026-10-20. Branch codex/game-modes, existing draft PR #2. This is a playable
single regular season, with original fictional players and estimated ratings.

Choose **GM Season** from the title, select an HL club and start a season, or
continue the existing local slot. A new season asks before replacing that slot.
The dashboard shows league standings, your record/rank, scheduled opponent and
recent results. Play your scheduled fixture or simulate one complete league day.
After playing, simulate the rest of that day to advance. Every change autosaves;
Save & return to menu also writes a checkpoint. All 32 clubs have one game per
league day, 31 home and 31 away, one fixture in each venue against each opponent.
There are 992 fixtures and 62 league days; this compact alpha calendar is not a
real professional schedule with travel, rest days or an 82-game slate.

The controlled club always occupies the first match/HUD side, including away
fixtures; the final is mapped back to the schedule's home/away sides. It uses the
career's roster snapshot, not a fresh copy of the bundled world. Returning before
the final leaves the fixture unplayed. Completed fixtures cannot be replayed or
counted twice. Failed final saves show **RESULT NOT SAVED** on the results screen;
returning to GM retries the pending result. The session blocks advancement while
that result remains unsaved. Pending in-memory results cannot survive process
termination after an unsuccessful write; the previous valid on-disk save remains.

Standings award two points for a win and one for an OT/shootout loss. Tiebreaks are
points, regulation wins, goal difference, then stable club ID. This is the stated
HL alpha preset, not complete real-league playoff qualification rules. Offline
simulation uses fixture-local SHA-256-derived seeds and bounded scoring chances
based on estimated team shot accuracy/goalie reflexes, with a small home modifier.
Tied simulated regulation goes to OT or SO and adds one deciding goal. It is an
original coarse simulation, not calibrated against real hockey or a substitute
for match-engine physics. Playing a fixture leaves other clubs' deterministic
results unchanged. No hidden controller/physics advantages are added.

The save embeds all 643 clubs and 14,745 players, their identity/provenance,
feeder links and estimated development profiles. Those are persistent data;
contracts, trading, scouting, drafting, actual development, injuries, playoffs,
awards, next-season rollover and multi-season simulation remain unimplemented.
At day 62 the mode displays final standings and disables further advancement.
Career mode remains unimplemented; no empty Career button was added.

## Persistence and preferences

The one local slot is `user://gm/slot-1.json`; its previous validated version is
`.bak`. Godot's `user://` resolves to the application data folder on the host.
Preferences live separately at `user://settings.json` and currently include only
match camera and stick dead zone (5–40%). They apply to Play Now/GM matches;
Practice consumes the saved dead zone. Full remapping, sensitivity, audio,
accessibility and presentation settings remain future work.

`save_store.gd` uses a version-2 envelope containing serialized JSON payload and
SHA-256 corruption check. Typed mode/settings validators run before staging and
on readback. A sibling `.tmp` is flushed, read back and validated; a valid current
file is retained via a staged backup before the staged primary is atomically
renamed into place. A corrupt primary never replaces a valid backup. Orphaned
staging files are ignored. Reading a recovered backup reports recovery without
silently overwriting the damaged file. Unsupported envelope versions block both
fallback and overwrite to protect saves from a newer build. Version-1 envelopes
are validated and migrated in memory; the next explicit save writes version 2.
The checksum detects accidental damage, not tampering/authenticity.

The implementation is synchronous and copies/validates the complete world. Cloud
software rendering and snapshot work do not establish consumer frame times or
production save latency. OS rename/flush behavior was exercised on Linux only;
there is no directory-fsync guarantee or proven protection against every hardware
power failure. Windows, Steam Deck, physical-controller feel and release packaging
remain untested. No save deletion/cloud sync or release feature is implied.

## Verification and actual engine images

Focused tests exercise save faults/recovery/migration/settings, a complete seeded
season and actual title → settings → GM → scheduled match → results → GM → resume.
The final evidence file is [verification/gm-season-20261020.json](verification/gm-season-20261020.json).
Screenshots are real 1440×900 Godot renders. Dashboard day 14 is staged by simulating
13 league days; it does not represent human-played games. Capture paths are isolated
under ignored build output, never the user's real season/settings.

- [Club setup](screenshots/gm-setup-20261020.png)
- [Opening day](screenshots/gm-opening-20261020.png)
- [Standings after 13 simulated days](screenshots/gm-standings-20261020.png)
- [Independent preferences](screenshots/gm-preferences-20261020.png)

The default cloud Mesa llvmpipe renderer crashed with SIGILL before capturing both
the arena and a standalone 2D page. The supported alternate Mesa `softpipe` driver
rendered these mode pages successfully using OpenGL compatibility; no 3D render or
hardware performance claim is made from this run. Reproduce with `DISPLAY=:9
GALLIUM_DRIVER=softpipe ... godot --rendering-method gl_compatibility --audio-driver
Dummy --script tools/capture_gm.gd`, plus the writable XDG paths in setup guidance.
