"""Original layered spell sounds, synthesized without external samples."""
from pathlib import Path
import math
import random
import struct
import wave

OUT=Path(__file__).resolve().parents[1]/'assets/audio'
RATE=22050
rng=random.Random(971)
for name,duration in [('lightning',.75),('meteor',1.55),('blizzard',1.4),('wind',.65),('swords',1.4),('beam',1.5),('ward',1.2),('comet',2.1)]:
    samples=[]
    low=0.0
    for i in range(int(duration*RATE)):
        t=i/RATE;p=t/duration
        noise=rng.uniform(-1,1);low=low*.90+noise*.10
        phase=math.tau
        tone=lambda f:math.sin(phase*f*t)
        if name=='lightning':
            envelope=sum(math.exp(-(t-hit)*24) for hit in [0,.15,.32] if t>=hit)
            value=(noise*.20+low*.7+tone(72)*.24)*envelope
        elif name in ('meteor','comet'):
            hit=.85 if name=='meteor' else 1.02
            charge=min(1,t/hit)*max(0,1-t/hit)
            value=(math.sin(phase*(160*t+350*t*t))*.14+low*.35)*charge
            for impact in ([hit] if name=='meteor' else [hit,hit+.24,hit+.48]):
                if t>=impact:
                    q=t-impact
                    value+=(math.sin(phase*(64*q-14*q*q))*.42+low*1.6+noise*.09)*math.exp(-q*6)
        elif name=='wind':
            value=(low*1.7+noise*.07)*math.sin(math.pi*p)**2
        elif name=='blizzard':
            value=sum(tone(f)*math.exp(-t*(2+j)) for j,f in enumerate([1046,1318,1568,2093]))*.075+noise*.035*(1-p)
        elif name=='swords':
            value=0
            for j in range(6):
                q=t-.08-j*.13
                if q>=0:value+=(math.sin(phase*(620+j*83)*q)*.15+low*.28)*math.exp(-q*10)
        elif name=='beam':
            value=math.sin(phase*(120*t+330*t*t))*.12*min(1,t*3)*(1-p)
            if t>.6:value+=(tone(90)*.22+tone(180)*.09+low*.8)*math.exp(-(t-.6)*3)
        else:
            value=sum(tone(f) for f in [392,587.33,784,1174.66])*.065*math.sin(math.pi*p)**2
        samples.append(value*min(1,t*120)*min(1,(duration-t)*80))
    peak=max(abs(v) for v in samples)
    gain=min(1,.86/max(.001,peak))
    with wave.open(str(OUT/f'arcane_{name}.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(v*gain*30000)) for v in samples))
print('Generated eight original spell sounds.')
