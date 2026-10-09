"""Synthesises the launch sounds: sparrow tweets and a flapping exit.
Pure stdlib so it runs anywhere; output is 44.1 kHz mono 16-bit WAV.

    python3 design/launch-sounds.py <out dir>
    afconvert -f caff -d LEI16 <out dir>/arrival.wav squabble/Resources/Sounds/arrival.caf
"""
import math, random, struct, wave, os, sys

SR = 44100
random.seed(7)
# Long pure tones in the 2-5 kHz band were shrill in headphones, and moving them
# lower just sounded muffled. Very short falling "tsip"s with a touch of overtone
# stay bright without piercing, so they're kept quieter than the wing beats too.
CHIRP_PEAK = 0.5

def tsip(duration, freqs, overtone=0.2, attack=0.012):
    """One sparrow note: a sine whose pitch follows `freqs` (Hz, evenly spaced over
    the note, smoothly interpolated) with a quiet second harmonic, a fast attack and
    a decay that runs to the end of the note."""
    out = []
    phase = 0.0
    segs = len(freqs) - 1
    for i in range(int(duration * SR)):
        t = i / SR
        p = min(t / duration, 1 - 1e-9) * segs
        k = int(p)
        u = p - k
        u = u * u * (3 - 2 * u)  # smoothstep between control points
        f0 = math.exp(math.log(freqs[k]) * (1 - u) + math.log(freqs[k + 1]) * u)
        phase += 2 * math.pi * f0 / SR
        s = math.sin(phase) + overtone * math.sin(2 * phase)
        if t < attack:
            s *= math.sin(math.pi / 2 * t / attack)
        else:
            s *= max(0.0, 1 - (t - attack) / (duration - attack)) ** 1.6
        out.append(s)
    return out

def soften(samples, cutoff=7000):
    """One-pole low-pass that takes the edge off the overtone without muffling."""
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    out, s = [], 0.0
    for x in samples:
        s += a * (x - s)
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

def write(name, samples, peak=0.8):
    samples = normalise(samples, peak)
    with wave.open(name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))
    print(name, f'{len(samples)/SR:.2f}s')

out = sys.argv[1]
# arrival — three quick falling tweets while the pieces fly in
write(os.path.join(out, 'arrival.wav'), room(soften(mix(
    tsip(0.035, [3200, 1900]),
    silence(0.07),
    tsip(0.035, [3300, 2000]),
    silence(0.07),
    tsip(0.05, [3400, 1800]),
)), gain=0.2), CHIRP_PEAK)
# hop — a pleased pair as the bird lands and puffs up; the second one turns upward
write(os.path.join(out, 'hop.wav'), room(soften(mix(
    tsip(0.035, [3300, 2000]),
    silence(0.06),
    tsip(0.06, [2000, 3200, 2600]),
)), gain=0.2), CHIRP_PEAK)
# a flurry of wing beats, nothing else
write(os.path.join(out, 'flyaway.wav'), room(mix(
    flap(), silence(0.03), flap(0.10), silence(0.03), flap(0.10), silence(0.03), flap(0.09),
), gain=0.12))
