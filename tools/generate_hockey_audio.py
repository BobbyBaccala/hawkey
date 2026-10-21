#!/usr/bin/env python3
"""Original deterministic synthesized hockey cues. No recordings or third-party audio."""
import argparse, math, random, struct, wave
from pathlib import Path
RATE = 22050
DURATIONS = {"wrist": .15, "slap": .25, "pass": .10, "boards": .30, "pad": .20,
             "post": .65, "net": .17, "whistle": .65, "horn": 1.7, "check": .25, "stop": .42}

def samples(kind, variant):
    rng = random.Random(3817 + list(DURATIONS).index(kind)*71 + variant)
    duration = DURATIONS[kind]
    low = 0.0
    out = []
    detune = 1 + (variant-1)*.035
    for i in range(round(duration*RATE)):
        t = i/RATE
        noise = rng.uniform(-1, 1)
        low += .12*(noise-low)
        bright = noise-low
        attack = min(1, t/.0015)
        if kind in ("wrist", "pass", "slap"):
            # Sharp blade/puck crack plus a short flex resonance; slap adds an ice brush.
            decay = 42 if kind == "pass" else 31
            v = .55*bright*math.exp(-t*decay) + .22*math.sin(2*math.pi*720*detune*t)*math.exp(-t*50)
            if kind == "slap":
                v += .26*bright*math.exp(-((t-.045)/.018)**2) + .18*low*math.exp(-t*16)
        elif kind in ("pad", "boards", "check", "net"):
            freq = {"pad":125, "boards":90, "check":68, "net":240}[kind]*detune
            v = .6*low*math.exp(-t*20) + .30*math.sin(2*math.pi*freq*t)*math.exp(-t*25)
            if kind == "net": v = .35*bright*math.exp(-t*30)
            if kind == "boards": v += .10*math.sin(2*math.pi*210*detune*t)*math.exp(-t*14)
        elif kind == "post":
            v = sum(amp*math.sin(2*math.pi*freq*detune*t)*math.exp(-t*decay)
                    for freq, amp, decay in [(1380,.34,9),(2210,.2,13),(3470,.12,17)])
            v += .18*bright*math.exp(-t*110)
        elif kind == "whistle":
            env = min(1,t/.025)*min(1,(duration-t)/.07)
            v = env*(.27*math.sin(2*math.pi*2850*detune*t + .8*math.sin(2*math.pi*41*t)) + .06*bright)
        elif kind == "horn":
            env = min(1,t/.09)*min(1,(duration-t)/.2)
            v = env*sum(.20/n*math.sin(2*math.pi*184*detune*n*t) for n in (1,2,3,5))
            v += env*.035*low
        else:
            env = math.sin(math.pi*t/duration)**.6
            v = env*(.42*bright+.3*low)*(0.8+.2*math.sin(2*math.pi*32*t))
        out.append(max(-.92,min(.92,v*attack)))
    # Ramp the last 5 ms to zero to avoid cut-off clicks.
    tail = round(.005*RATE)
    for j in range(tail): out[-tail+j] *= (tail-j-1)/tail
    return out

def generate(output):
    output.mkdir(parents=True, exist_ok=True)
    for kind in DURATIONS:
        for variant in range(3):
            pcm = b''.join(struct.pack('<h',round(x*32767)) for x in samples(kind,variant))
            with wave.open(str(output/f'{kind}-{variant}.wav'),'wb') as file:
                file.setparams((1,2,RATE,0,'NONE','not compressed'));file.writeframes(pcm)

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=Path('assets/audio'))
    generate(parser.parse_args().output)
