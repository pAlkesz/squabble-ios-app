"""Synthesises the launch sounds: a soft pigeon coo and a flapping exit.
Pure stdlib so it runs anywhere; output is 44.1 kHz mono 16-bit WAV.

    python3 design/launch-sounds.py <out dir>
    afconvert -f caff -d LEI16 <out dir>/squawk.wav squabble/Resources/Sounds/squawk.caf
"""
import math, random, struct, wave, os, sys

SR = 44100
random.seed(7)

def env(t, attack, hold, release, total):
    if t < attack: return math.sin(math.pi / 2 * t / attack)
    if t < attack + hold: return 1.0
    r = (t - attack - hold) / max(release, 1e-6)
    return max(0.0, 1.0 - r) ** 1.5 if t < total else 0.0

def coo(duration, f_start, f_peak, f_end, roll_hz=22, roll_depth=0.35, breath=0.05):
    """One pigeon syllable: a rounded tone that swells in pitch then settles, with the
    throaty roll pigeons have (slow amplitude tremolo) and very little edge."""
    n = int(duration * SR)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        p = t / duration
        # pitch: rise to the peak at ~40 %, then ease back down
        if p < 0.4:
            f0 = f_start + (f_peak - f_start) * math.sin(math.pi / 2 * p / 0.4)
        else:
            f0 = f_peak + (f_end - f_peak) * (1 - math.cos(math.pi * (p - 0.4) / 0.6)) / 2
        phase += 2 * math.pi * f0 / SR
        # mostly fundamental, a touch of 2nd/3rd for body — no rasp
        s = math.sin(phase) + 0.28 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase)
        roll = 1 - roll_depth * (0.5 + 0.5 * math.sin(2 * math.pi * roll_hz * t))
        noise = random.uniform(-1, 1)
        lp = lp + 0.04 * (noise - lp)
        s = s * roll + breath * lp * 6
        s *= env(t, 0.04, duration * 0.45, duration * 0.5, duration)
        out.append(s)
    return out

def flap(duration=0.11):
    """A wing beat: a soft whoosh with a little clap at the start, as pigeons do."""
    n = int(duration * SR)
    out = []
    lp1 = lp2 = 0.0
    for i in range(n):
        t = i / SR
        noise = random.uniform(-1, 1)
        lp1 += 0.08 * (noise - lp1)
        lp2 += 0.08 * (lp1 - lp2)
        whoosh = lp2 * 12 * math.sin(math.pi * t / duration) ** 1.4
        clap = noise * 0.5 * math.exp(-t / 0.006)
        out.append(whoosh + clap)
    return out

def silence(d): return [0.0] * int(d * SR)

def mix(*parts):
    return [x for part in parts for x in part]

def normalise(samples, peak=0.8):
    m = max(abs(x) for x in samples) or 1.0
    return [x / m * peak for x in samples]

def write(name, samples):
    samples = normalise(samples)
    with wave.open(name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))
    print(name, f'{len(samples)/SR:.2f}s')

out = sys.argv[1]
# "coo-coo-coooo": two short syllables and a longer settling one
write(os.path.join(out, 'squawk.wav'), mix(
    coo(0.16, 380, 470, 420),
    silence(0.03),
    coo(0.16, 400, 490, 430),
    silence(0.03),
    coo(0.42, 390, 520, 340, roll_hz=18, roll_depth=0.45),
))
# a flurry of wing beats and a short coo on the way out
write(os.path.join(out, 'flyaway.wav'), mix(
    flap(), silence(0.03), flap(0.10), silence(0.03), flap(0.10), silence(0.03), flap(0.09),
    silence(0.06),
    coo(0.22, 400, 500, 380),
))
