"""Synthesises the launch sounds: a raspy seagull-style squawk and a flapping exit.
Pure stdlib so it runs anywhere; output is 44.1 kHz mono 16-bit WAV."""
import math, random, struct, wave, os, sys

SR = 44100
random.seed(7)

def env(t, attack, hold, release, total):
    if t < attack: return t / attack
    if t < attack + hold: return 1.0
    r = (t - attack - hold) / max(release, 1e-6)
    return max(0.0, 1.0 - r) ** 1.5 if t < total else 0.0

def squawk(duration, f_start, f_end, rasp_hz=70, harmonics=7, breath=0.12, bend=1.0):
    n = int(duration * SR)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        p = (t / duration) ** bend
        f0 = f_start + (f_end - f_start) * p
        # a little wobble so it sounds alive
        f0 *= 1 + 0.015 * math.sin(2 * math.pi * 9 * t)
        phase += 2 * math.pi * f0 / SR
        s = 0.0
        for h in range(1, harmonics + 1):
            s += math.sin(phase * h + 0.3 * h) / (h ** 0.85)
        # amplitude "rasp" — the throaty pulsing of a gull
        rasp = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * rasp_hz * t))
        noise = random.uniform(-1, 1)
        lp = lp + 0.25 * (noise - lp)
        s = s * rasp + breath * lp * 3
        s *= env(t, 0.012, duration * 0.35, duration * 0.62, duration)
        out.append(s)
    return out

def flap(duration=0.13):
    n = int(duration * SR)
    out = []
    lp1 = lp2 = 0.0
    for i in range(n):
        t = i / SR
        noise = random.uniform(-1, 1)
        # two cascaded one-pole low passes -> soft whoosh
        lp1 += 0.06 * (noise - lp1)
        lp2 += 0.06 * (lp1 - lp2)
        s = lp2 * 14 * math.sin(math.pi * t / duration) ** 1.6
        out.append(s)
    return out

def silence(d): return [0.0] * int(d * SR)

def mix(*parts):
    return [x for part in parts for x in part]

def normalise(samples, peak=0.85):
    m = max(abs(x) for x in samples) or 1.0
    return [x / m * peak for x in samples]

def write(name, samples):
    samples = normalise(samples)
    with wave.open(name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))
    print(name, f'{len(samples)/SR:.2f}s')

out = sys.argv[1]
# "kyaa-kya": a long falling call, a beat, a shorter higher one
write(os.path.join(out, 'squawk.wav'), mix(
    squawk(0.34, 1500, 950, bend=0.8),
    silence(0.05),
    squawk(0.20, 1700, 1150, rasp_hz=85, bend=0.7),
))
# three flaps then a parting remark
write(os.path.join(out, 'flyaway.wav'), mix(
    flap(), silence(0.05), flap(0.12), silence(0.05), flap(0.11), silence(0.08),
    squawk(0.16, 1800, 1300, rasp_hz=90, bend=0.6),
))
