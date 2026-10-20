# Shared player database foundation

Status: native version-2 HL world loading, with 32 HL clubs and complete farm,
North American junior, European and youth rosters: 643 teams / 14,745 original
players. See [HL_WORLD.md](HL_WORLD.md) for the exact manifest, roster sizes,
development/draft metadata, executed validation and remaining GM work. The
version-1 two-team example remains supported as a regression fixture.

## Run

Requires Python 3.10+; no extra packages or network requests.

```sh
python3 tools/generate_world.py --output /tmp/hl-world.json
cmp data/world/fictional-world.json /tmp/hl-world.json
# Legacy CSV authoring example:
python3 tools/import_roster.py data/examples/fictional-roster.csv /tmp/hawkey-roster.json
python3 -m unittest discover -s tests -p 'test_roster_import.py' -v
```

Output carries schema version 1 and database metadata version 1, league/season,
identity kind, provenance and estimate metadata. The offline importer permits
partial datasets for authoring; `data/roster.schema.json` and the native loader
define the stricter complete fictional Play Now contract. Partial or real-identity
imports are not automatically eligible for native match loading.

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

## Runtime acceptance and remaining work

- [x] Validate loaded JSON and references, reject unsupported metadata versions.
- [x] Resolve stable player/goalie identities; build explicit position-based local line slots.
- [ ] Keep future mutable career/GM state separate from an immutable roster snapshot.
- [ ] Save the roster version and edits with the career/GM save.
- [x] Test fictional team selection through Play Now, rematch and menu/practice round trips.
- [ ] Add save/reload acceptance before exposing external imports in the main menu.
