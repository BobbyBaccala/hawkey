"""Coverage and development invariants for the fictional universe."""
import json
from pathlib import Path
import sys
import unittest
from datetime import date
from collections import Counter
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from generate_world import build_world, age_on, draft_eligible, OUTPUT, AS_OF, COMMON_SKILLS, SKATER_SKILLS, GOALIE_SKILLS

class WorldGenerationTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.world=build_world()
  cls.teams={t['id']:t for t in cls.world['teams']}
  cls.leagues={l['id']:l for l in cls.world['leagues']}
  cls.players=[p for t in cls.world['teams'] for p in t['players']]
 def test_committed_snapshot_reproducible(self):
  self.assertEqual(self.world,json.loads(OUTPUT.read_text()))
  self.assertEqual(self.world,build_world())
 def test_manifest_reordering_preserves_club_and_player_identities(self):
  manifest=json.loads((OUTPUT.parent/'league_manifest.json').read_text())
  manifest['leagues'].reverse()
  manifest['teams'].reverse()
  reordered=build_world(manifest)
  self.assertEqual({t['id']:t for t in reordered['teams']},self.teams)
 def test_coverage(self):
  self.assertEqual(len(self.leagues),33)
  self.assertEqual(len(self.teams),643)
  self.assertEqual(len(self.players),14745)
  counts=Counter(t['league_id'] for t in self.teams.values())
  self.assertEqual(counts['hl'],32)
  self.assertEqual(counts['hda'],32)
  self.assertEqual(counts['hdb'],32)
  for l in self.leagues.values():self.assertEqual(counts[l['id']],l['team_count'])
  self.assertEqual(Counter(l['tier'] for l in self.leagues.values()),dict(top=1,minor=2,junior=12,europe=13,youth=5))
 def test_full_rosters(self):
  positions={20:dict(C=4,LW=4,RW=4,D=6,G=2),23:dict(C=4,LW=5,RW=5,D=7,G=2),25:dict(C=5,LW=5,RW=5,D=7,G=3)}
  for t in self.teams.values():
   size=self.leagues[t['league_id']]['roster_size']
   self.assertEqual(len(t['players']),size)
   self.assertEqual(Counter(p['position'] for p in t['players']),positions[size])
   self.assertEqual(len({p['jersey_number'] for p in t['players']}),size)
 def test_stable_unique_identities_and_original_names(self):
  self.assertEqual(len({p['id'] for p in self.players}),len(self.players))
  self.assertEqual(len({p['name'] for p in self.players}),len(self.players))
  for p in self.players:
   self.assertIn(p['identity_kind'],['fictional','generated'])
   self.assertIsNone(p['source'])
   self.assertEqual(p['rating_metadata']['kind'],'estimate')
 def test_preserves_initial_players(self):
  old=json.loads((OUTPUT.parents[1]/'examples/fictional-roster.json').read_text())
  current={p['id']:p for p in self.players}
  for t in old['teams']:
   for p in t['players']:
    for attribute,value in p['ratings'].items():
     self.assertEqual(value,current[p['id']]['ratings'][attribute])
    for key in ['id','name','position','identity_kind','rating_metadata']:
     self.assertEqual(p[key],current[p['id']][key])
 def test_farm_network(self):
  for league_id,parent in [('hda','hl'),('hdb','hda')]:
   children=[t for t in self.teams.values() if t['league_id']==league_id]
   self.assertEqual(len({t['affiliate_of'] for t in children}),32)
   for t in children:
    owner=self.teams[t['affiliate_of']]
    self.assertEqual(owner['league_id'],parent)
    rights=owner['id'] if parent=='hl' else owner['affiliate_of']
    self.assertTrue(all(p['hl_rights_team_id']==rights for p in t['players']))
 def test_ages_and_development_profiles(self):
  for t in self.teams.values():
   l=self.leagues[t['league_id']]
   for p in t['players']:
    age=age_on(p['birth_date'],AS_OF)
    self.assertLessEqual(l['min_age'],age)
    self.assertLessEqual(age,l['max_age'])
    self.assertGreaterEqual(p['potential'],max(p['ratings'].values()))
    self.assertLessEqual(p['potential'],100)
    self.assertIn(p['shoots'],['L','R'])
    for key in COMMON_SKILLS + (GOALIE_SKILLS if p['position']=='G' else SKATER_SKILLS):
     self.assertIn(key,p['ratings'])
    self.assertTrue(all(0<=rating<=100 for rating in p['ratings'].values()))
    self.assertEqual(p['skill_rating_metadata']['kind'],'estimate')
    if p['hl_rights_team_id']:
     self.assertEqual(self.teams[p['hl_rights_team_id']]['league_id'],'hl')
    if l['tier']=='youth':
     self.assertIsNone(p['hl_rights_team_id'])
     self.assertFalse(l['play_now'])
 def test_draft_cutoff_and_owned_exclusion(self):
  p=dict(birth_date='2009-09-15',hl_rights_team_id=None)
  self.assertTrue(draft_eligible(p))
  p['birth_date']='2009-09-16';self.assertFalse(draft_eligible(p))
  p['birth_date']='2006-09-15';self.assertFalse(draft_eligible(p))
  p.update(birth_date='2008-09-15',hl_rights_team_id='har');self.assertFalse(draft_eligible(p))
  pool=[p for p in self.players if draft_eligible(p)]
  self.assertGreater(len(pool),1000)
  self.assertTrue(any(p['hl_rights_team_id'] for p in self.players))
 def test_route_references_and_reaches_hl(self):
  routes={r['from_league_id']:r['to_league_ids'] for r in self.world['development_routes']}
  def reaches_hl(id_,seen):
   if id_=='hl':return True
   if id_ in seen:return False
   return any(reaches_hl(dest,seen|{id_}) for dest in routes.get(id_,[]))
  for source,targets in routes.items():
   self.assertIn(source,self.leagues)
   for target in targets:self.assertIn(target,self.leagues)
   self.assertTrue(reaches_hl(source,set()))
if __name__=='__main__':unittest.main()
