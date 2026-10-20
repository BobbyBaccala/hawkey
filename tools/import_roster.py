"""Import a reviewed player CSV into Hawkey's version-1 roster JSON.

No network access, third-party packages, inferred scouting ratings or fuzzy identity
matching. See docs/PLAYER_DATABASE.md for the CSV contract and source requirements.
"""
import argparse
import csv
from datetime import date
import io
import json
import math
import os
from pathlib import Path
import tempfile
from urllib.parse import urlparse

FIELDS = (
    'player_id', 'name', 'position', 'team_id', 'team_city', 'team_name',
    'league_id', 'season', 'identity_kind', 'source_url', 'source_player_id',
    'source_as_of', 'ratings_kind', 'ratings_method', 'speed', 'acceleration', 'agility',
)
RATINGS = ('speed', 'acceleration', 'agility')


class RosterError(ValueError):
    """A row cannot safely enter the shared game database."""


def import_csv(text: str) -> dict:
    reader = csv.DictReader(io.StringIO(text.lstrip('\ufeff')))
    if reader.fieldnames != list(FIELDS):
        raise RosterError('CSV header must exactly match: ' + ','.join(FIELDS))
    teams = {}
    ids = set()
    source_ids = set()
    for line, raw in enumerate(reader, start=2):
        def fail(message):
            raise RosterError(f'Row {line}: {message}')
        if None in raw or any(value is None for value in raw.values()):
            fail('wrong number of columns')
        row = {key: value.strip() for key, value in raw.items()}
        for key in FIELDS:
            if not row[key] and key not in ('source_url', 'source_player_id', 'source_as_of'):
                fail(f'{key} is required')
        for key in ('player_id', 'team_id', 'league_id'):
            if any(c.isspace() for c in row[key]):
                fail(f'{key} must be a stable ID without whitespace')
        if row['player_id'] in ids:
            fail('duplicate player_id (one snapshot per player per database)')
        if row['position'] not in ('C', 'LW', 'RW', 'D', 'G'):
            fail('unsupported position')
        if row['identity_kind'] not in ('real', 'fictional', 'generated'):
            fail('identity_kind must be real, fictional or generated')
        # Real identity/stat sources are not evidence that a scouting rating is official.
        if row['ratings_kind'] != 'estimate':
            fail('ratings_kind must be estimate; official ratings are not supported')
        ratings = {}
        for key in RATINGS:
            try:
                value = float(row[key])
            except ValueError:
                fail(f'{key} must be numeric')
            if not math.isfinite(value) or not 0 <= value <= 100:
                fail(f'{key} must be finite and between 0 and 100')
            ratings[key] = value
        provenance = None
        supplied_source = any(row[key] for key in ('source_url', 'source_player_id', 'source_as_of'))
        if row['identity_kind'] == 'real' or supplied_source:
            parsed = urlparse(row['source_url'])
            if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
                fail('source_url must be an HTTPS source without credentials')
            if not row['source_player_id']:
                fail('source_player_id is required for sourced identities')
            try:
                as_of = date.fromisoformat(row['source_as_of'])
            except ValueError:
                fail('source_as_of must be an ISO date (YYYY-MM-DD)')
            if as_of.isoformat() != row['source_as_of'] or as_of > date.today():
                fail('source_as_of must be a canonical date no later than today')
            source_key = (parsed.hostname.lower(), row['source_player_id'])
            if source_key in source_ids:
                fail('duplicate source identity under different player IDs')
            source_ids.add(source_key)
            provenance = {'url': row['source_url'], 'player_id': row['source_player_id'],
                          'as_of': row['source_as_of']}
        team_id = row['team_id']
        metadata = (row['team_city'], row['team_name'], row['league_id'], row['season'])
        if team_id in teams and teams[team_id][0] != metadata:
            fail('conflicting team metadata or multiple seasons in one snapshot')
        if team_id not in teams:
            teams[team_id] = (metadata, {'id': team_id, 'city': row['team_city'],
                'name': row['team_name'], 'league_id': row['league_id'],
                'season': row['season'], 'players': []})
        teams[team_id][1]['players'].append({
            'id': row['player_id'], 'name': row['name'], 'position': row['position'],
            'identity_kind': row['identity_kind'], 'source': provenance, 'ratings': ratings,
            'rating_metadata': {'kind': 'estimate', 'method': row['ratings_method'],
                                'confidence': 'unassessed'},
        })
        ids.add(row['player_id'])
    if not ids:
        raise RosterError('At least one player is required')
    result = {'schema_version': 1, 'database_metadata_version': 1, 'teams': []}
    for team_id in sorted(teams):
        team = teams[team_id][1]
        team['players'].sort(key=lambda player: player['id'])
        result['teams'].append(team)
    return result


def write_atomic(path: Path, roster: dict) -> None:
    """Never truncate an existing roster when serialization or writing fails."""
    payload = json.dumps(roster, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         prefix=path.name + '.', suffix='.tmp', delete=False) as output:
            temporary = Path(output.name)
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args(argv)
    try:
        roster = import_csv(args.csv.read_text(encoding='utf-8-sig'))
        write_atomic(args.output, roster)
    except (OSError, UnicodeError, RosterError) as error:
        parser.exit(2, f'Roster import failed: {error}\n')
    print(f"Imported {sum(len(t['players']) for t in roster['teams'])} players / {len(roster['teams'])} teams")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
