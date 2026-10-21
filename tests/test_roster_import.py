"""Standard-library tests: python3 -m unittest discover -s tests -p 'test_roster_import.py'."""
import csv
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from import_roster import FIELDS, RosterError, import_csv, write_atomic


def row(**changes):
    result = dict(zip(FIELDS, ('fictional:vale', 'E. Vale', 'C', 'tor', 'Toronto',
        'North Stars', 'fictional-pro', '2026-27', 'fictional', '', '', '',
        'estimate', 'hand-authored fixture v1', '75', '76', '77')))
    result.update(changes)
    return result


def csv_text(*rows):
    text = io.StringIO()
    writer = csv.DictWriter(text, fieldnames=FIELDS)
    writer.writeheader()
    writer.writerows(rows)
    return text.getvalue()


class ImportTests(unittest.TestCase):
    def test_fictional_identity_and_estimates_are_explicit(self):
        player = import_csv(csv_text(row()))['teams'][0]['players'][0]
        self.assertEqual(player['identity_kind'], 'fictional')
        self.assertIsNone(player['source'])
        self.assertEqual(player['rating_metadata']['confidence'], 'unassessed')
        self.assertEqual(player['ratings']['speed'], 75)

    def test_real_identity_needs_complete_provenance(self):
        with self.assertRaises(RosterError):
            import_csv(csv_text(row(identity_kind='real')))
        # Deliberately synthetic source fixture; no real player's data is claimed.
        player = import_csv(csv_text(row(identity_kind='real', source_url='https://example.org/player/1',
            source_player_id='1', source_as_of='2026-01-01')))['teams'][0]['players'][0]
        self.assertEqual(player['source']['player_id'], '1')

    def test_reject_bad_values(self):
        for change in ({'speed': 'NaN'}, {'agility': 'inf'}, {'speed': '-1'},
            {'speed': '101'}, {'speed': 'fast'}, {'position': 'X'},
            {'ratings_kind': 'official'}, {'ratings_method': ''},
            {'player_id': 'has spaces'}, {'identity_kind': 'unknown'},
            {'name': ''}, {'season': ''}):
            with self.subTest(change=change), self.assertRaises(RosterError):
                import_csv(csv_text(row(**change)))

    def test_duplicate_ids_and_conflicting_metadata(self):
        for other in (row(), row(player_id='second', team_city='Montreal'),
                      row(player_id='second', season='2025-26')):
            with self.subTest(other=other), self.assertRaises(RosterError):
                import_csv(csv_text(row(), other))

    def test_duplicate_source_identity(self):
        source = dict(identity_kind='real', source_url='https://example.org/player/1',
                      source_player_id='1', source_as_of='2026-01-01')
        with self.assertRaises(RosterError):
            import_csv(csv_text(row(**source), row(player_id='second', **source)))

    def test_invalid_provenance(self):
        source = dict(source_url='https://example.org/1', source_player_id='1', source_as_of='2026-01-01')
        for change in ({'source_url': 'http://example.org/1'}, {'source_url': 'https://user:pass@example.org/1'},
                       {'source_as_of': '2099-01-01'}, {'source_as_of': '2026-02-30'},
                       {'source_as_of': '20260101'}, {'source_player_id': ''}):
            with self.subTest(change=change), self.assertRaises(RosterError):
                import_csv(csv_text(row(**(source | change))))

    def test_empty_and_malformed_files(self):
        for text in ('', csv_text(), 'name\nA\n', csv_text(row()) + 'too,few\n',
                     csv_text(row()).replace('75,76,77', '75,76,77,extra')):
            with self.subTest(text=text), self.assertRaises(RosterError):
                import_csv(text)

    def test_deterministic_output_and_unicode_bom(self):
        first, second = row(), row(player_id='fictional:adler', name='S. Adlér')
        self.assertEqual(import_csv(csv_text(first, second)), import_csv('\ufeff' + csv_text(second, first)))

    def test_atomic_round_trip(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'nested' / 'roster.json'
            roster = import_csv(csv_text(row()))
            write_atomic(path, roster)
            self.assertEqual(json.loads(path.read_text()), roster)
            self.assertEqual(list(path.parent.iterdir()), [path])

    def test_failed_replace_preserves_old_file_and_cleans_temp(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'roster.json'
            path.write_text('original')
            with patch('import_roster.os.replace', side_effect=OSError('disk failure')):
                with self.assertRaises(OSError):
                    write_atomic(path, import_csv(csv_text(row())))
            self.assertEqual(path.read_text(), 'original')
            self.assertEqual(list(path.parent.iterdir()), [path])

    def test_invalid_json_preserves_old_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'roster.json'
            path.write_text('original')
            with self.assertRaises(ValueError):
                write_atomic(path, {'bad': float('nan')})
            self.assertEqual(path.read_text(), 'original')


if __name__ == '__main__':
    unittest.main()
