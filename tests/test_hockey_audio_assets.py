"""Signal and provenance checks for original generated samples; not a listening test."""
import hashlib
import importlib.util
import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('hockey_samples',ROOT/'tools/generate_hockey_audio.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class HockeyAudioAssets(unittest.TestCase):
    def test_all_signals_are_bounded_nonempty_pcm(self):
        for kind, duration in module.DURATIONS.items():
            for variant in range(3):
                with self.subTest(kind=kind,variant=variant):
                    with wave.open(str(ROOT/f'assets/audio/{kind}-{variant}.wav')) as audio:
                        self.assertEqual((audio.getnchannels(),audio.getsampwidth(),audio.getframerate()),(1,2,module.RATE))
                        pcm=audio.readframes(audio.getnframes())
                    values=struct.unpack('<'+'h'*(len(pcm)//2),pcm)
                    self.assertEqual(len(values),round(duration*module.RATE))
                    self.assertLess(max(abs(x) for x in values),32767)
                    self.assertGreater(math.sqrt(sum(x*x for x in values)/len(values)),100)
                    self.assertEqual(values[0],0);self.assertEqual(values[-1],0)
    def test_variants_are_distinct(self):
        for kind in module.DURATIONS:
            hashes={hashlib.sha256((ROOT/f'assets/audio/{kind}-{n}.wav').read_bytes()).hexdigest() for n in range(3)}
            self.assertEqual(len(hashes),3)
    def test_regeneration_is_byte_identical(self):
        with tempfile.TemporaryDirectory() as path:
            output=Path(path);module.generate(output)
            for sample in output.glob('*.wav'):
                self.assertEqual(sample.read_bytes(),(ROOT/'assets/audio'/sample.name).read_bytes())
