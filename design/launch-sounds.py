"""Synthesises the launch sounds: a few songbird chirps and a flapping exit.
Pure stdlib so it runs anywhere; output is 44.1 kHz mono 16-bit WAV.

    python3 design/launch-sounds.py <out dir>
    afconvert -f caff -d LEI16 <out dir>/arrival.wav squabble/Resources/Sounds/arrival.caf
"""
import math, random, struct, wave, os, sys

SR = 44100
random.seed(7)

def env(t, attack, hold, release, total):
    if t < attack: return math.sin(math.pi / 2 * t / attack)
    if t < attack + hold: return 1.0
    r = (t - attack - hold) / max(release, 1e-6)
    return max(0.0, 1.0 - r) ** 1.5 if t < total else 0.0

def chirp(duration, freqs, vibrato_hz=0, vibrato=0.0, harmonic=0.06):
    """One songbird note: a near-pure sine whose pitch follows `freqs` (Hz, evenly
    spaced over the note) with smooth interpolation, so a rising or falling glide,
    or an inverted V, is just a list of numbers."""
    n = int(duration * SR)
    out = []
    phase = 0.0
    segs = len(freqs) - 1
    for i in range(n):
        t = i / SR
        p = min(t / duration, 1 - 1e-9) * segs
        k = int(p)
        u = p - k
        u = u * u * (3 - 2 * u)  # smoothstep between control points
        f0 = math.exp(math.log(freqs[k]) * (1 - u) + math.log(freqs[k + 1]) * u)
        f0 *= 1 + vibrato * math.sin(2 * math.pi * vibrato_hz * t)
        phase += 2 * math.pi * f0 / SR
        s = math.sin(phase) + harmonic * math.sin(2 * phase)
        s *= env(t, 0.006, duration * 0.3, duration * 0.68, duration)
        out.append(s)
    return out

def room(samples, delay=0.028, gain=0.22, tail=3):
    """A whisper of echo so the notes don't sound like they were made in a vacuum."""
    d = int(delay * SR)
    out = list(samples) + [0.0] * (d * tail)
    for i in range(d, len(out)):
        out[i] += out[i - d] * gain
    return out

def flap(duration=0.11):
    """A wing beat: a soft whoosh with a little clap at the start."""
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
# arrival — four quick notes while the pieces fly in: two rising glides, an
# inverted V, and a short falling one
write(os.path.join(out, 'arrival.wav'), room(mix(
    chirp(0.08, [2300, 3400, 3700]),
    silence(0.05),
    chirp(0.09, [2400, 3600, 3900]),
    silence(0.07),
    chirp(0.11, [2800, 4200, 3000], vibrato_hz=60, vibrato=0.02),
    silence(0.06),
    chirp(0.07, [3800, 2900, 2600]),
)))
# hop — a pleased two-note tweet as the bird lands and puffs up
write(os.path.join(out, 'hop.wav'), room(mix(
    chirp(0.07, [3000, 4100, 3800]),
    silence(0.04),
    chirp(0.10, [3300, 4400, 3200], vibrato_hz=70, vibrato=0.02),
)))
# a flurry of wing beats, nothing else
write(os.path.join(out, 'flyaway.wav'), room(mix(
    flap(), silence(0.03), flap(0.10), silence(0.03), flap(0.10), silence(0.03), flap(0.09),
), gain=0.12))
