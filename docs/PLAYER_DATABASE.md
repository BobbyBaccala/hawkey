# Shared player database foundation

Status: offline import tooling only. The current match still builds hard-coded
rosters. No real professional/junior database or calibrated ratings are shipped.
The example is fictional, incomplete and not a match-ready lineup.

## Run

Requires Python 3.10+; no extra packages or network requests.

```sh
python3 tools/import_roster.py data/examples/fictional-roster.csv /tmp/hawkey-roster.json
python3 -m unittest discover -s tests -p 'test_roster_import.py' -v
```

Output retains the required fields of `data/roster.schema.json` version 1 and
adds database metadata version 1, league/season, explicit identity kind,
provenance and rating metadata. Godot can read the JSON with its standard JSON
parser; runtime validation and integration are the next increment. Do not
replace match rosters with the two-player example.

## CSV contract

Use the exact ordered header in `data/examples/fictional-roster.csv`.
One row per player, one team/season snapshot per file. IDs are permanent keys,
not names or jersey numbers; keep them across trades, edits and save files.
Team IDs are globally unique across leagues. Maintain a reviewed identity ledger
before combining providers. Same-source duplicate identities are rejected;
cross-provider matching deliberately requires human review.

Required identity kinds: `real`, `fictional`, `generated`. Real identities require
an HTTPS source URL, provider player ID and canonical ISO as-of date. The date
cannot be in the future. A source link records provenance; it does not prove
accuracy or permission to redistribute. Review each provider's terms and data
before adding a real dataset. Generated prospects must remain explicitly tagged.
Do not identify real children in the minor-hockey career population; use generated
players there. Junior/pro imports should only use the reviewed public dataset.

All three ratings (`speed`, `acceleration`, `agility`) are finite 0–100 numbers.
Only `estimate` is accepted; `ratings_method` is mandatory and confidence remains
`unassessed`. The importer does not manufacture skating ratings from scoring
statistics, imply that the ratings are official, or establish their accuracy.
Unknown attributes need a documented baseline methodology before import.
Future statistical ratings need season and position/league normalization,
sample-size shrinkage, calibration against held-out results, attribute-specific
sources and uncertainty. Goalie attributes require a separate model.

Malformed columns, missing values, conflicting team metadata, duplicate IDs,
invalid provenance and nonfinite ratings fail the entire import. Output is
sorted by IDs, UTF-8 and reproducible. Writes use a temporary file, flush/fsync
and replace in the destination directory, preserving the old file on failure.
This is not yet a versioned career-save system or concurrent-writer lock.

## Acceptance before runtime use

- Validate loaded JSON and references, reject unsupported metadata versions.
- Resolve active lineups/goalies by ID; never rely on array order.
- Keep mutable career/GM state separate from an immutable roster snapshot.
- Save the roster version and edits with the career/GM save.
- Test roster selection through Play Now and save/reload before exposing imports
  in the main menu. Add a complete fictional league fixture for that test.
