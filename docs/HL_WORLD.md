# HL world coverage

2026-10-20, America/Toronto. Implemented data and native exhibition integration; alpha.

The HL is the original **Hockey League**, with 32 complete 23-player clubs. The world contains **33 leagues, 643 teams and 14,745 original players**. League memberships, names, roster limits and draft rules are fictional design choices. All players are labeled fictional/generated; all ratings and potential are uncalibrated estimates.

| System | Leagues | Teams | Players | Roster per team |
|---|---:|---:|---:|---|
| HL | 1 | 32 | 736 | 23 |
| Professional farm system | 2 | 64 | 1,472 | 23 |
| North American junior | 12 | 218 | 5,450 | 25 |
| European professional | 13 | 169 | 3,887 | 23 |
| Youth U9/U11/U13/U15/U18 | 5 | 160 | 3,200 | 20 |

## Included leagues

| ID | Competition | Teams | Age range at season date |
|---|---|---:|---|
| hl | Hockey League | 32 | 18–40 |
| hda | Hockey Development Association | 32 | 18–40 |
| hdb | Hockey Development B | 32 | 18–40 |
| j-west | Western Junior Hockey | 24 | 16–20 |
| j-central | Central Junior Hockey | 20 | 16–20 |
| j-east | Eastern Junior Hockey | 18 | 16–20 |
| j-us | United States Junior Premier | 16 | 16–20 |
| j-us2 | United States Junior Development | 32 | 16–20 |
| j-us3 | United States Junior Regional | 36 | 16–20 |
| ja-pacific | Pacific Junior A | 12 | 16–20 |
| ja-prairie | Prairie Junior A | 12 | 16–20 |
| ja-central | Central Junior A | 12 | 16–20 |
| ja-ontario | Ontario Junior A | 12 | 16–20 |
| ja-quebec | Quebec Junior A | 12 | 16–20 |
| ja-atlantic | Atlantic Junior A | 12 | 16–20 |
| eu-se | Swedish Premier Hockey | 14 | 18–40 |
| eu-fi | Finnish Premier Hockey | 16 | 18–40 |
| eu-cz | Czech Premier Hockey | 14 | 18–40 |
| eu-de | German Premier Hockey | 14 | 18–40 |
| eu-ch | Swiss Premier Hockey | 14 | 18–40 |
| eu-sk | Slovak Premier Hockey | 12 | 18–40 |
| eu-at | Alpine Hockey Association | 13 | 18–40 |
| eu-fr | French Premier Hockey | 12 | 18–40 |
| eu-gb | British Premier Hockey | 10 | 18–40 |
| eu-no | Norwegian Premier Hockey | 10 | 18–40 |
| eu-dk | Danish Premier Hockey | 9 | 18–40 |
| eu-pl | Polish Premier Hockey | 9 | 18–40 |
| eu-east | Eastern European Hockey | 22 | 18–40 |
| y-u9 | Youth U9 | 32 | 7–8 |
| y-u11 | Youth U11 | 32 | 9–10 |
| y-u13 | Youth U13 | 32 | 11–12 |
| y-u15 | Youth U15 | 32 | 13–14 |
| y-u18 | Youth U18 | 32 | 15–17 |

## HL clubs

| ID | Club | Primary farm club | Secondary farm club |
|---|---|---|---|
| har | Harbor Lanterns | Kingston Ravens | Peterborough Ravens |
| sum | Summit Comets | Laval Wolves | Trois-Rivieres Wolves |
| hl-03 | Toronto Lynx | Victoria Herons | Nanaimo Herons |
| hl-04 | Montreal Voyagers | Red Deer Meteors | Medicine Hat Meteors |
| hl-05 | Vancouver Cascades | Lethbridge Badgers | Cranbrook Badgers |
| hl-06 | Calgary Embers | Brandon Pines | Regina Pines |
| hl-07 | Edmonton Auroras | Belleville Spires | North Bay Spires |
| hl-08 | Winnipeg Bison | Sherbrooke Otters | Saguenay Otters |
| hl-09 | Ottawa Sentinels | Moncton Cinders | Fredericton Cinders |
| hl-10 | Quebec City Citadels | Charlottetown Falcons | Sydney Falcons |
| hl-11 | Halifax Tides | Saint John Elks | St Johns Elks |
| hl-12 | Boston Harriers | Portland Maine Quartz | Worcester Quartz |
| hl-13 | New York Skylines | Albany Waves | Utica Waves |
| hl-14 | Buffalo Forge | Rochester Hawks | Elmira Hawks |
| hl-15 | Detroit Sparks | Grand Rapids Rooks | Kalamazoo Rooks |
| hl-16 | Chicago Gales | Rockford Cedars | Peoria Cedars |
| hl-17 | Pittsburgh Foundry | Erie Flares | Wheeling Flares |
| hl-18 | Philadelphia Keystones | Allentown Ibis | Reading Ibis |
| hl-19 | Washington Ospreys | Norfolk Flints | Roanoke Flints |
| hl-20 | Raleigh Copperheads | Durham Clouds | Greenville Clouds |
| hl-21 | Miami Sunbursts | Fort Myers Drifters | Savannah Drifters |
| hl-22 | Tampa Squalls | Orlando Beacons | Jacksonville Beacons |
| hl-23 | Nashville Chords | Knoxville Garnets | Huntsville Garnets |
| hl-24 | Columbus Kestrels | Toledo Aspens | Cincinnati Aspens |
| hl-25 | Minneapolis Frost | Duluth Whirlwinds | Fargo Whirlwinds |
| hl-26 | St Louis Archers | Springfield Missouri Cranes | Tulsa Cranes |
| hl-27 | Dallas Outriders | Fort Worth Shales | Wichita Shales |
| hl-28 | Denver Alpine | Colorado Springs Larches | Boise Larches |
| hl-29 | Seattle Evergreens | Tacoma Storms | Spokane Storms |
| hl-30 | Portland Pioneers | Eugene Moons | Bend Moons |
| hl-31 | Los Angeles Solstice | Bakersfield Peaks | Fresno Peaks |
| hl-32 | San Diego Breakers | Palm Springs Dunes | Reno Dunes |

## Data and development contract

- `data/world/league_manifest.json` explicitly enumerates every league, club ID, abbreviation, city and affiliate reference. IDs are retained when names or ordering change.
- `data/world/fictional-world.json` is the committed version-2 snapshot and the native loader default. `world.schema.json` describes its structural contract; native validation additionally checks relational and eligibility invariants.
- The two-team version-1 example remains a backward-compatibility fixture. Its original 40 IDs, names, positions, movement ratings and provenance labels survive in the world.
- Pro/euro rosters contain 23 players: 14 forwards, seven defenders, two goalies. Junior rosters contain 25: 15 forwards, seven defenders, three goalies. Youth rosters contain 20: 12 forwards, six defenders, two goalies.
- Match snapshots explicitly dress four C/LW/RW lines, three D pairs and two goalies; remaining players stay in the snapshot as reserves. Starting-goalie substitution and reserve editing remain future work.
- Each player carries a canonical birth date, nationality, handedness, height, weight, jersey number, role-specific hockey ratings, a potential estimate, and nullable HL rights ownership. Common and skater/goalie-specific skill estimates have separate provenance labels.
- Every HL team has one HDA affiliate and one HDB affiliate beneath it. References and hierarchy are validated; this is a data relationship, not a simulated loan/assignment or contract system.
- Youth routes ascend U9 -> U11 -> U13 -> U15 -> U18 -> junior. Junior routes lead to the two pro tiers/HL; European clubs provide an additional path to HL. Route references and acyclic paths to HL are validated. No automatic promotion, player growth or roster transfers are simulated yet.
- `draft_pool()` queries unowned players aged 18–20 on 2027-09-15, excluding already-owned rights. Eligibility derives from birthdays and the explicit original HL draft policy. The initial pool has 3,256 candidates. A draft selection/rights transaction, scouting uncertainty, draft picks and yearly new prospect generation are still to implement.
- Ages are checked on 2026-09-15 for the 2026-27 snapshot. Youth players have no preassigned HL rights. Youth competitions are development data and are excluded from Play Now until age-appropriate rules, rink/game formats and presentation exist.

## Player-visible integration

Play Now now filters teams by competition. All 32 HL clubs and every represented pro/euro/junior club can be selected for the existing exhibition rules. League/team selection survives rematch and Practice/menu round trips within the process. Shared exhibition rules do not establish accurate league-specific rules. Skating consumes speed; the net-shot solver now consumes shot_power. The remaining authored attributes and potential are data for future simulation. Current shared OT/shootout and controls are documented in CONTROLS_AND_TIEBREAKS.md.

## Reproduce and verify

```sh
cd /workspace/hawkey
python3 tools/generate_world.py --output /tmp/hl-world.json
cmp data/world/fictional-world.json /tmp/hl-world.json
python3 -m unittest discover -s tests -p 'test_*.py'
export XDG_CACHE_HOME=/workspace/.cache
export XDG_CONFIG_HOME=/workspace/.config
export XDG_DATA_HOME=/workspace/.local/share
godot --headless --fixed-fps 120 --path . --script tests/test_world_database.gd
godot --headless --fixed-fps 120 --path . --script tests/test_play_now.gd
```

The generator is an initial-world builder, not a career-save migration tool. It writes atomically using the importer’s tested writer. Startup reads the committed snapshot; it does not regenerate or replace existing saves. Generation is deterministic, and reordering manifest teams/leagues preserves each club/player record. Existing saves need versioned snapshots and explicit migrations before GM persistence is enabled.

## Verification checkpoint

21 Python tests passed; 20 engine suites passed and optional mocap skipped. Native world checks: 4,586 passed; Play Now navigation: 47 passed. Committed JSON reproduces byte-for-byte and passes JSON Schema/date-format validation.

See [verification/hl-world-20261020.json](verification/hl-world-20261020.json) for executed outcomes. Python tests cover reproducibility, ID/name uniqueness, complete roster/league counts, original-player preservation, affiliation ownership, all age ranges, position-specific skills, draft cutoff boundaries and routes to HL. Native tests check every team’s dressed/reserve mapping, the complete draft pool and failure-safe rejection of malformed references/versions/ages/positions/numbers/routes/ratings. Navigation tests exercise HL, farm, European and junior selection and scene transitions.

A genuine Linux software-render title capture is stored at [screenshots/hl-world-title-20261020.png](screenshots/hl-world-title-20261020.png). Human controller/feel testing, Windows/Deck, full multi-season development, progression, scouting, contracts and persistence remain open. Claude’s presentation code and both integrated presentation histories are preserved. No PR merge, release or environment publication.
