"""Generate original ambient music and game sounds using only Python's stdlib."""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050
random.seed(42)


def write(name, samples):
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 27000)) for x in samples))


def tone(freq, t):
    return math.sin(math.tau * freq * t)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, seconds in [("sword", .24), ("spell", .6), ("hurt", .26), ("heal", 1.2), ("pickup", .55), ("roll", .3), ("boss", .65), ("skill", .85)]:
        samples = []
        smooth = 0.0
        for i in range(int(seconds * RATE)):
            t = i / RATE
            p = t / seconds
            env = math.sin(math.pi * p) * (1-p)
            noise = random.uniform(-1, 1)
            smooth = smooth * .8 + noise * .2
            if name in ("sword", "roll"):
                v = smooth * env * 1.6 + tone(170 - 70*p, t) * env * .15
            elif name in ("hurt", "boss"):
                v = (tone(75-20*p, t) * .65 + smooth * .65) * math.exp(-8*p)
            elif name in ("heal", "pickup"):
                v = sum(tone(f, t) * math.exp(-t*4) for f in (523.25, 659.25, 783.99)) * env * .25
            else:
                v = (tone(480 + 300*p, t) * .3 + tone(960 - 120*p, t) * .12 + smooth * .25) * env
            samples.append(v)
        write(name, samples)

    # A seamless 48-second pastoral C / Am / F / G harp and soft pad loop.
    duration = 48
    music = [0.0] * (duration * RATE)
    chords = [(130.81, 164.81, 196.0), (110, 130.81, 164.81), (87.31, 130.81, 174.61), (98, 146.83, 196)]
    for ci in range(8):
        chord = chords[ci % 4]
        for j in range(6*RATE):
            t = j / RATE
            env = math.sin(math.pi*t/6) ** 2
            music[ci*6*RATE+j] += sum(tone(f, t) for f in chord) * env * .035
        for beat in range(8):
            start = ci*6 + beat*.75
            freq = chord[[0, 1, 2, 1, 0, 2, 1, 2][beat]] * (4 if beat % 3 == 0 else 2)
            for j in range(int(2.2*RATE)):
                t=j/RATE
                v=(tone(freq,t)+tone(freq*2,t)*.28+tone(freq*3,t)*.08)*math.exp(-3.6*t)*min(1,t*90)*.13
                music[(int(start*RATE)+j)%len(music)] += v
    write("meadow", music)
    print(f"Generated 9 original WAV files in {OUT}")


if __name__ == "__main__":
    main()
