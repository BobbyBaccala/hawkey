"""Build the original HL world; no real players, ratings or licensed league claims.

IDs are tied to fixed manifest IDs and player slots, never names/order/random draws.
Existing two-team identities survive. Generation v1 is an initial snapshot builder,
not a tool for overwriting career saves or regenerating players every season.
"""
from __future__ import annotations
import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'data/world/fictional-world.json'
AS_OF = date(2026, 9, 15)
DRAFT_DATE = date(2027, 9, 15)
SEASON = '2026-27'
COMMON_SKILLS = ('stamina', 'strength', 'balance', 'discipline')
SKATER_SKILLS = ('passing', 'puck_control', 'shot_accuracy', 'shot_power',
                 'offensive_awareness', 'defensive_awareness', 'checking', 'poke_check', 'faceoffs')
GOALIE_SKILLS = ('reflexes', 'glove', 'blocker', 'rebound_control', 'positioning', 'recovery', 'puck_handling')

FIRST = 'Evan Nico Arin Milo Luca Jules Dara Oren Tavi Idris Soren Perrin Remy Vian Galen Kiran Finn Bryn Alex Morgan Robin Sasha Ellis Rowan Blair Casey Devon Emery Frankie Gray Harper Indigo Jamie Kai Lane Micah Noel Oak Parker Quinn Adrian Anton Asa Avery Basil Blake Callum Cameron Cian Cora Dorian Eden Emil Enzo Ezra Felix Florian Gabriel Hugo Ilya Ira Ivan Jesse Jonah Jordan Leon Leo Logan Luka Milan Niko Noah Oliver Oscar Owen Pascal Rene Riley River Roman Ronan Rory Sam Sascha Silas Stefan Taylor Theo Tomas Tristan Uri Val Wren Yann Yuri'.split()
PREFIX = 'Alder Ash Birch Black Brook Cedar Clear Cliff Cold Crest Dawn Deep Elm Fair Fern Field Flint Frost Glen Gold Green Grey Hazel High Iron Lake Linden Maple Marsh Meadow Moss North Oak Pine Red Ridge River Rock Rose Silver Snow South Spring Stone Storm Summer Thorn Vale West White Willow Wind Winter Wolf Wood'.split()
SUFFIX = 'bank berg berry bloom borne bridge brook by cliff dale den field ford gard glen grove hall ham haven hill holm hurst lake land ley lind low mark mere mont more ness ridge rock rose shaw son sted stone strand storm ton vale view ward well wick wood worth'.split()

def age_on(birth_date: str, when: date) -> int:
 b = date.fromisoformat(birth_date)
 return when.year-b.year-((when.month,when.day)<(b.month,b.day))

def draft_eligible(player: dict, when: date = DRAFT_DATE) -> bool:
 return player['hl_rights_team_id'] is None and 18 <= age_on(player['birth_date'],when) <= 20

def rng_for(key: str) -> random.Random:
 return random.Random(int.from_bytes(hashlib.sha256(('hl-world-v1:'+key).encode()).digest()[:8],'big'))


def development_routes(leagues: list[dict]) -> list[dict]:
    routes = []
    for league in leagues:
        tier = league['tier']
        if tier == 'top':
            continue
        if league['id'] == 'hdb':
            destinations = ['hda', 'hl']
        elif tier in ('minor', 'europe'):
            destinations = ['hl']
        elif tier == 'junior':
            destinations = ['hda', 'hdb', 'hl']
        elif league['max_age'] >= 17:
            destinations = [item['id'] for item in leagues if item['tier'] == 'junior']
        else:
            next_age = {9: 11, 11: 13, 13: 15, 15: 18}[int(league['id'][3:])]
            destinations = ['y-u' + str(next_age)]
        routes.append({'from_league_id': league['id'], 'to_league_ids': destinations})
    return routes


def build_world(manifest: dict | None = None) -> dict:
    if manifest is None:
        manifest = json.loads((ROOT / 'data/world/league_manifest.json').read_text())
    leagues = manifest['leagues']
    specifications = manifest['teams']
    specifications_by_id = {team['id']: team for team in specifications}
    legacy = json.loads((ROOT / 'data/examples/fictional-roster.json').read_text())
    legacy_by_id = {team['id']: team for team in legacy['teams']}
    used_names = {p['name'] for team in legacy['teams'] for p in team['players']}
    hl_ids = sorted(team['id'] for team in specifications if team['league_id'] == 'hl')
    league_by_id = {league['id']: league for league in leagues}
    teams = []
    # Generate in ID order so manifest reordering does not change identities.
    for spec in sorted(specifications, key=lambda team: team['id']):
        league = league_by_id[spec['league_id']]
        team_id = spec['id']
        rng = rng_for(team_id)
        root_club = team_id if league['tier'] == 'top' else None
        if league['tier'] == 'minor':
            parent = specifications_by_id[spec['affiliate_of']]
            root_club = parent['id'] if parent['league_id'] == 'hl' else parent['affiliate_of']
        positions = ['C', 'LW', 'RW'] * 4 + ['D'] * 6 + ['G'] * 2
        if league['roster_size'] >= 23:
            positions += ['LW', 'RW', 'D']
        if league['roster_size'] >= 25:
            positions += ['C', 'G']
        players = []
        for slot, position in enumerate(positions):
            player_id = f'generated:{team_id}:{slot+1:02}'
            old_players = legacy_by_id.get(team_id, {}).get('players', [])
            original = dict(old_players[slot]) if slot < len(old_players) else None
            if original:
                player_id = original['id']
                name = original['name']
                position = original['position']
            else:
                while True:
                    name = rng.choice(FIRST) + ' ' + rng.choice(PREFIX) + rng.choice(SUFFIX)
                    if name not in used_names:
                        break
                used_names.add(name)
            age = rng.randint(league['min_age'], min(league['max_age'], 36))
            month, day = rng.randint(1, 12), rng.randint(1, 28)
            year = AS_OF.year - age - int((month, day) > (AS_OF.month, AS_OF.day))
            birth = date(year, month, day).isoformat()
            baseline = {
                'top': 79, 'minor': 66 if league['id'] == 'hda' else 59,
                'junior': 51, 'europe': 72, 'youth': 20 + age * 2,
            }[league['tier']]
            ratings = {
                key: max(15, min(96, baseline + rng.randint(-10, 10)))
                for key in ('speed', 'acceleration', 'agility')
            }
            potential = max(max(ratings.values()), min(99, baseline + rng.randint(5, 23)))
            rights = root_club
            if league['tier'] in ('junior', 'europe') and age >= 18 and rng.random() < 0.25:
                rights = rng.choice(hl_ids)
            player = {
                'id': player_id, 'name': name, 'position': position,
                'identity_kind': 'generated', 'source': None, 'ratings': ratings,
                'rating_metadata': {
                    'kind': 'estimate',
                    'method': 'original tier/age balance fixture v1; uncalibrated',
                    'confidence': 'unassessed',
                },
            }
            if original:
                player.update(original)
            nationality_pool = {
                'NA': ['CA', 'US'], 'AT': ['AT', 'IT', 'SI', 'HU'],
                'EAST': ['RU', 'BY', 'KZ', 'LV', 'LT'],
            }.get(league['region'], [league['region']])
            player.update(
                birth_date=birth, nationality=rng.choice(nationality_pool),
                shoots=rng.choice(['L', 'R']),
                height_cm=rng.randint(165, 200) if age >= 18 else 112 + age * 4 + rng.randint(-8, 8),
                weight_kg=rng.randint(72, 104) if age >= 18 else 13 + age * 3 + rng.randint(-4, 4),
                jersey_number=slot + 1, potential=potential, hl_rights_team_id=rights,
            )
            # Separate draw stream keeps existing identities/profiles stable as skills expand.
            skills_rng = rng_for(player_id + ':hockey-skills')
            player['ratings'] = dict(player['ratings'])
            for attribute in COMMON_SKILLS + (GOALIE_SKILLS if position == 'G' else SKATER_SKILLS):
                player['ratings'][attribute] = max(10, min(96, baseline + skills_rng.randint(-12, 12)))
            player['skill_rating_metadata'] = {
                'kind': 'estimate', 'method': 'original position/tier skill fixture v1; uncalibrated',
                'confidence': 'unassessed',
            }
            player['potential'] = max(player['potential'], max(player['ratings'].values()))
            players.append(player)
        teams.append(dict(**spec, players=players))
    by_id = {team['id']: team for team in teams}
    return {
        'schema_version': 2, 'database_metadata_version': 1,
        'world_id': 'hl-original-2026', 'generator_version': 1,
        'as_of': AS_OF.isoformat(), 'season': SEASON,
        'identity_policy': 'Original fictional/generated identities; no licensed real competition or scouting accuracy claim',
        'draft_policy': {
            'id': 'hl-draft-v1', 'date': DRAFT_DATE.isoformat(),
            'min_age': 18, 'max_age': 20, 'rights_required': 'unowned',
            'note': 'Original simplified eligibility; not a claim about real league regulations',
        },
        'development_routes': development_routes(leagues), 'leagues': leagues,
        'teams': [by_id[team['id']] for team in specifications],
    }


def main() -> None:
    from import_roster import write_atomic
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    world = build_world()
    write_atomic(args.output, world)
    count = sum(len(team['players']) for team in world['teams'])
    print(f"{len(world['leagues'])} leagues / {len(world['teams'])} teams / {count} original players")


if __name__ == '__main__':
    main()
