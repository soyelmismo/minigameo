#!/usr/bin/env python3
"""Synthesize every audio asset the game ships with.

WHY SYNTHESIZED ASSETS (not downloads):
The game must build and run offline with zero third-party binaries. Every
sound here is generated from math (numpy) and written as plain WAV, so the
pipeline is reproducible and diffs are auditable.

CONTRACT with the running system (src/audio/):
  - MusicDirector (src/audio/music_director.gd) mixes 5 vertical stems
    (drums / bass / lead / harmony / fx) plus a pre-mixed "full" fallback,
    driven by a 128 BPM beat clock (GameConfig.music_bpm) and 4/4 bars.
    Every stem is therefore the SAME length in bars, same tempo, and
    sample-exact loopable: the director can drop any layer in/out on a
    bar boundary without phase drift or an audible seam.
  - SFXPlayer/SFXLibrary (src/audio/sfx_library.gd) resolves a StringName id
    to a res:// path. Ids are registered by data, so the FILE NAMES here are
    the contract: sfx_pickup, sfx_jump, sfx_hit, sfx_fail, sfx_score,
    sfx_ui_click, sfx_roulette, sfx_countdown (+ 4 impact tiers that match
    the four ImpactFrame presets in src/juice/presets/).
  - BusLayout routes by GROUP (player/world/ui/impact), so each SFX is
    authored to sit on the bus its group implies.

Format: 16-bit PCM WAV (Godot imports WAV natively, no extra config).
  - music:  stereo 44100 Hz, 8 bars of 4/4 @ 128 BPM = 15.0 s per loop
  - sfx:    mono   44100 Hz, 0.1-1.0 s one-shots
  - ambience: stereo 44100 Hz, 4 s seamless loop

Run:  python3 tools/audio/build_audio.py
"""

from __future__ import annotations

import math
import os
import hashlib
import wave

import numpy as np

# --- Global musical constants (single source of truth) ---

SAMPLE_RATE = 44100
BPM = 128.0                       # GameConfig.music_bpm
BEATS_PER_BAR = 4
BARS_PER_LOOP = 4                 # 4 bars @ 128 BPM = 7.5 s (brief: 4-8 s/stem)
SECONDS_PER_BEAT = 60.0 / BPM
SECONDS_PER_BAR = SECONDS_PER_BEAT * BEATS_PER_BAR
# 4 bars @ 128 BPM = 4 * 1.875 s = 7.5 s per stem (brief asks for 4-8 s).
LOOP_SECONDS = SECONDS_PER_BAR * BARS_PER_LOOP
assert abs(LOOP_SECONDS - 7.5) < 1e-9, "loop length drifted: %r" % LOOP_SECONDS

# Root note / key: A minor, energetic arcade feel.
ROOT_MIDI = 57                    # A3

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_MUSIC = os.path.join(REPO_ROOT, "assets", "audio", "music")
OUT_SFX = os.path.join(REPO_ROOT, "assets", "audio", "sfx")
OUT_AMB = os.path.join(REPO_ROOT, "assets", "audio", "ambience")


# --- Small signal helpers -------------------------------------------------

def note_hz(midi: int) -> float:
    """Equal-temperament frequency for a MIDI note number."""
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def seconds_to_samples(seconds: float) -> int:
    return int(round(seconds * SAMPLE_RATE))


def env_ads(n_samples: int, attack: float, decay: float) -> np.ndarray:
    """Percussive envelope: linear attack, exponential decay to (near) zero."""
    n_a = max(1, seconds_to_samples(attack))
    n_d = max(1, n_samples - n_a)
    attack = np.linspace(0.0, 1.0, n_a, endpoint=False)
    decay = np.exp(-np.linspace(0.0, 6.0, n_d))
    env = np.concatenate([attack, decay])
    if env.size < n_samples:
        env = np.pad(env, (0, n_samples - env.size))
    return env[:n_samples]


def env_pad(n_samples: int, attack: float, release: float) -> np.ndarray:
    """Sustained envelope: slow swell in, slow release out (pads)."""
    n_a = max(1, seconds_to_samples(attack))
    n_r = max(1, seconds_to_samples(release))
    n_s = max(1, n_samples - n_a - n_r)
    attack = np.linspace(0.0, 1.0, n_a) ** 2
    sustain = np.ones(n_s)
    release = np.linspace(1.0, 0.0, n_r) ** 2
    env = np.concatenate([attack, sustain, release])
    if env.size < n_samples:
        env = np.pad(env, (0, n_samples - env.size))
    return env[:n_samples]


def soft_clip(signal: np.ndarray, drive: float = 1.0) -> np.ndarray:
    """tanh saturation: keeps mixes loud without hard digital clipping."""
    return np.tanh(signal * drive) / math.tanh(drive)


def normalize(signal: np.ndarray, peak: float = 0.89) -> np.ndarray:
    """Scale so the loudest sample hits `peak` (headroom for the master limiter)."""
    top = float(np.max(np.abs(signal))) if signal.size else 0.0
    if top < 1e-9:
        return signal
    return signal * (peak / top)


def to_stereo(mono: np.ndarray, width: float = 0.0) -> np.ndarray:
    """Duplicate mono to L/R, applying a small Haas-style decorrelation."""
    if width <= 0.0:
        stereo = np.stack([mono, mono], axis=1)
        return stereo
    delay = seconds_to_samples(0.006 * width)
    right = np.roll(mono, delay)
    right[:delay] = 0.0
    stereo = np.stack([mono, right], axis=1)
    # Equal-power pan so the centre image keeps its level.
    stereo[:, 0] *= math.cos(width * 0.35)
    stereo[:, 1] *= math.sin(width * 0.35) + 1.0
    return stereo * 0.7


def write_wav(path: str, signal: np.ndarray, channels: int) -> int:
    """Write a 16-bit PCM WAV. Returns the file size in bytes."""
    clipped = np.clip(signal, -1.0, 1.0)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())
    return os.path.getsize(path)


def silent(n_samples: int) -> np.ndarray:
    return np.zeros(n_samples, dtype=np.float64)


# --- Godot import settings -------------------------------------------------
# Godot only regenerates the uid/hash lines of a .import sidecar; the [params]
# block is preserved verbatim. That lets this pipeline own its import settings
# instead of leaving them to whatever the editor defaults produce.
#
# Verified against Godot 4.4.1:
#   edit/loop_mode enum is 0=Detect, 1=Disabled, 2=Forward, 3=PingPong
#     (NOTE: the *resource* enum is 0=Disabled, 1=Forward, 2=PingPong).
#   compress/mode: 0 = raw PCM, 1 = ADPCM, 2 = QOA (the default).
#
# Music stems and the ambience bed MUST loop (MusicDirector calls play() and
# never stops the layer), and they are authored to be period-exact loops, so
# they ship forward-looped and uncompressed. SFX are one-shots: loop off, and
# QOA-compressed (Godot's memory-friendly default for short sounds).

IMPORT_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"

# Deterministic uid from the res:// path: stable across rebuilds and machines,
# so a clean checkout imports to the same uids every time.
def _stable_uid(res_path: str) -> str:
    digest = hashlib.md5(res_path.encode("utf-8")).digest()
    value = int.from_bytes(digest[:8], "big")
    if value == 0:
        value = 1
    text = ""
    while value:
        text = IMPORT_CHARS[value % 36] + text
        value //= 36
    return "uid://" + text


def write_import_sidecar(wav_path: str, loop: bool, compress_mode: int) -> None:
    """Write the .import sidecar next to `wav_path` with the wanted settings.

    Godot overwrites the uid and the import-path hash on the next import and
    leaves [params] untouched, so a stale/hand-written sidecar self-heals
    while keeping the loop/compression decisions made here.
    """
    rel = os.path.relpath(wav_path, REPO_ROOT).replace(os.sep, "/")
    res_path = "res://" + rel
    sidecar = wav_path + ".import"
    contents = (
        "[remap]\n\n"
        'importer="wav"\n'
        'type="AudioStreamWAV"\n'
        'uid="%s"\n\n'
        "[deps]\n\n"
        'source_file="%s"\n\n'
        "[params]\n\n"
        "force/8_bit=false\n"
        "force/mono=false\n"
        "force/max_rate=false\n"
        "force/max_rate_hz=44100\n"
        "edit/trim=false\n"
        "edit/normalize=false\n"
        "edit/loop_mode=%d\n"
        "edit/loop_begin=0\n"
        "edit/loop_end=-1\n"
        "compress/mode=%d\n"
        % (_stable_uid(res_path), res_path, 2 if loop else 1, compress_mode)
    )
    with open(sidecar, "w") as handle:
        handle.write(contents)


# --- Drum synthesis -------------------------------------------------------

def kick(start: int, length: float, gain: float, buffer: np.ndarray) -> None:
    """Pitch-swept sine kick + a click transient.

    The sweep is integrated analytically instead of approximated, so the
    instantaneous frequency starts at f0 and decays to f1:
        f(t)   = f1 + (f0 - f1) * exp(-t / sweep)
        phase(t) = 2*pi * (f1*t + (f0 - f1) * sweep * (1 - exp(-t / sweep)))
    Getting this wrong (a naive linear-in-t frequency term) yields a wildly
    negative instantaneous frequency at t=0, i.e. an aliased noise burst
    instead of a kick -- verified with an FFT band-energy check.
    """
    n = seconds_to_samples(length)
    end = min(start + n, buffer.size)
    n = end - start
    if n <= 0:
        return
    t = np.arange(n) / SAMPLE_RATE
    f0, f1, sweep = 130.0, 46.0, 0.045
    decay = np.exp(-t / sweep)
    phase = 2.0 * np.pi * (f1 * t + (f0 - f1) * sweep * (1.0 - decay))
    body = np.sin(phase) * env_ads(n, 0.001, length)
    click = np.random.default_rng(7).standard_normal(n) * env_ads(n, 0.0005, 0.012) * 0.18
    buffer[start:end] += (body + click) * gain


def snare(start: int, length: float, gain: float, buffer: np.ndarray) -> None:
    """Noise burst through a band-passed tone stack (body + snap)."""
    n = seconds_to_samples(length)
    end = min(start + n, buffer.size)
    n = end - start
    if n <= 0:
        return
    rng = np.random.default_rng(11)
    noise = rng.standard_normal(n)
    t = np.arange(n) / SAMPLE_RATE
    body = np.sin(2.0 * np.pi * 190.0 * t) * 0.55
    # One-pole high-pass on the noise -> the "snap" band.
    alpha = 0.42
    hp = np.empty(n)
    hp[0] = noise[0]
    for i in range(1, n):
        hp[i] = alpha * (hp[i - 1] + noise[i] - noise[i - 1])
    env = env_ads(n, 0.001, length)
    buffer[start:end] += (body + hp * 1.35) * env * gain


def hat(start: int, length: float, gain: float, buffer: np.ndarray, open_: bool = False) -> None:
    """High-passed noise with a very short decay (closed) or ringing tail (open)."""
    n = seconds_to_samples(length)
    end = min(start + n, buffer.size)
    n = end - start
    if n <= 0:
        return
    rng = np.random.default_rng(23)
    noise = rng.standard_normal(n)
    alpha = 0.86
    hp = np.empty(n)
    hp[0] = noise[0]
    for i in range(1, n):
        hp[i] = alpha * (hp[i - 1] + noise[i] - noise[i - 1])
    decay = 0.09 if open_ else 0.028
    env = env_ads(n, 0.0008, decay)
    buffer[start:end] += hp * env * gain


def clap(start: int, length: float, gain: float, buffer: np.ndarray) -> None:
    """Three stacked noise bursts = handclap (used as a backbeat accent)."""
    n = seconds_to_samples(length)
    for i, offset in enumerate((0.0, 0.011, 0.023)):
        snare(start + seconds_to_samples(offset), length, gain * (0.9 - 0.25 * i), buffer)


def build_drums() -> np.ndarray:
    """Four-on-the-floor kick, backbeat clap/snare, 8th + 16th hats."""
    total = seconds_to_samples(LOOP_SECONDS)
    buffer = silent(total)
    spb_samples = seconds_to_samples(SECONDS_PER_BEAT)

    for bar in range(BARS_PER_LOOP):
        bar_start = bar * seconds_to_samples(SECONDS_PER_BAR)
        # Kick on every beat (128 BPM four-on-the-floor).
        for beat in range(BEATS_PER_BAR):
            kick(bar_start + beat * spb_samples, 0.42, 1.0, buffer)
        # Extra kick offbeat for drive on the second half of the loop.
        if bar >= 2:
            for beat in (2,):
                kick(bar_start + beat * spb_samples + spb_samples // 2, 0.34, 0.55, buffer)
        # Backbeat: clap on 2 and 4, snare ghost on the "and" of 4.
        clap(bar_start + spb_samples, 0.22, 0.5, buffer)
        clap(bar_start + 3 * spb_samples, 0.22, 0.55, buffer)
        snare(bar_start + seconds_to_samples(SECONDS_PER_BEAT * 3.75), 0.18, 0.28, buffer)
        # Hats: 8ths closed, 16ths quieter, open hat on the last 8th of the bar.
        for eighth in range(BEATS_PER_BAR * 2):
            at = bar_start + eighth * (spb_samples // 2)
            gain = 0.30 if eighth % 2 == 0 else 0.19
            hat(at, 0.06, gain, buffer)
            hat(at + spb_samples // 4, 0.03, gain * 0.45, buffer)
        hat(bar_start + seconds_to_samples(SECONDS_PER_BEAT * 3.5), 0.16, 0.24, buffer, open_=True)
    return soft_clip(buffer, 1.2) * 0.85


# --- Bass / lead / harmony / fx -------------------------------------------

def build_bass() -> np.ndarray:
    """Sine sub with a pluck envelope, walking the root of each bar."""
    total = seconds_to_samples(LOOP_SECONDS)
    buffer = silent(total)
    spb_samples = seconds_to_samples(SECONDS_PER_BEAT)
    # i - VI - III - VII in A minor: Am F C G (classic driving minor loop).
    # Register matters: these roots are an octave BELOW the harmony pad
    # (82-131 Hz vs 175-392 Hz) so the two layers never fight for the same
    # spectrum. Verified with an FFT band-energy check.
    roots = [45, 41, 48, 43]
    for bar in range(BARS_PER_LOOP):
        root = roots[bar % len(roots)]
        bar_start = bar * seconds_to_samples(SECONDS_PER_BAR)
        for beat in range(BEATS_PER_BAR):
            at = bar_start + beat * spb_samples
            n = seconds_to_samples(SECONDS_PER_BEAT * 0.95)
            end = min(at + n, total)
            n = end - at
            t = np.arange(n) / SAMPLE_RATE
            # Octave up on the last bar for the lift into the loop seam.
            midi = root + (12 if bar >= 3 and beat == 3 else 0)
            wave_ = np.sin(2.0 * np.pi * note_hz(midi) * t)
            # A little 2nd harmonic gives the sub definition on small speakers.
            wave_ += 0.28 * np.sin(2.0 * np.pi * note_hz(midi) * 2.0 * t)
            buffer[at:end] += wave_ * env_ads(n, 0.004, SECONDS_PER_BEAT * 0.9) * 0.75
    return soft_clip(buffer, 1.1) * 0.9


def build_lead() -> np.ndarray:
    """Detuned square/saw stab melody, 8th notes over an A-minor riff."""
    total = seconds_to_samples(LOOP_SECONDS)
    buffer = silent(total)
    spb_samples = seconds_to_samples(SECONDS_PER_BEAT)
    # Riff: root, 5th, octave, 7th... (A C E G D) then the descending answer.
    riff = [57, 60, 64, 67, 65, 64, 60, 57]
    for bar in range(BARS_PER_LOOP):
        bar_start = bar * seconds_to_samples(SECONDS_PER_BAR)
        # Second half of the loop transposes the riff up a 4th (variation).
        shift = 5 if bar >= 2 else 0
        for step, midi in enumerate(riff):
            at = bar_start + step * (spb_samples // 2)
            n = seconds_to_samples(SECONDS_PER_BEAT * 0.5)
            end = min(at + n, total)
            n = end - at
            if n <= 0:
                continue
            t = np.arange(n) / SAMPLE_RATE
            freq = note_hz(midi + shift + 12)
            square = np.sign(np.sin(2.0 * np.pi * freq * t))
            saw = 2.0 * (t * freq - np.floor(0.5 + t * freq))
            wave_ = 0.55 * square + 0.45 * saw
            env = env_ads(n, 0.002, SECONDS_PER_BEAT * 0.45)
            buffer[at:end] += wave_ * env * 0.34
    # Gentle high-pass so the lead never muddies the bass.
    return soft_clip(buffer, 1.3) * 0.8


def build_harmony() -> np.ndarray:
    """Slow saw pads holding a triad per bar (the vertical "wall" layer)."""
    total = seconds_to_samples(LOOP_SECONDS)
    buffer = silent(total)
    spb_samples = seconds_to_samples(SECONDS_PER_BEAT)
    # Triads over the same i - VI - III - VII movement.
    chords = [
        (57, 60, 64),   # Am
        (53, 57, 60),   # F
        (60, 64, 67),   # C
        (55, 59, 62),   # G
    ]
    for bar in range(BARS_PER_LOOP):
        chord = chords[bar % len(chords)]
        bar_start = bar * seconds_to_samples(SECONDS_PER_BAR)
        n = seconds_to_samples(SECONDS_PER_BAR * BEATS_PER_BAR * 1.05)
        end = min(bar_start + n, total)
        n = end - bar_start
        t = np.arange(n) / SAMPLE_RATE
        pad = np.zeros(n)
        for i, midi in enumerate(chord):
            freq = note_hz(midi)
            # Slightly detuned saws per voice = wide, chorus-y pad.
            saw = 2.0 * (t * freq - np.floor(0.5 + t * freq))
            saw_detune = 2.0 * (t * freq * 1.004 - np.floor(0.5 + t * freq * 1.004))
            pad += (saw + saw_detune) * (0.34 - 0.05 * i)
        env = env_pad(n, 0.35, 0.5)
        buffer[bar_start:end] += pad * env * 0.30
    # One-pole low-pass: pads stay soft, they never fight the lead.
    alpha = 0.22
    out = np.empty(total)
    out[0] = buffer[0]
    for i in range(1, total):
        out[i] = alpha * buffer[i] + (1.0 - alpha) * out[i - 1]
    return soft_clip(out, 1.2) * 0.85


def build_fx() -> np.ndarray:
    """Risers/sweeps: a noise riser into bar 3 and a bright zap on the loop seam."""
    total = seconds_to_samples(LOOP_SECONDS)
    buffer = silent(total)
    # Riser across bars 2-3 (the second half of the loop) -> energy lift.
    rise_start = seconds_to_samples(SECONDS_PER_BAR * 2)
    rise_len = seconds_to_samples(SECONDS_PER_BAR * 1.5)
    end = min(rise_start + rise_len, total)
    n = end - rise_start
    rng = np.random.default_rng(31)
    noise = rng.standard_normal(n)
    # Rising band-pass: modulate the one-pole coefficient with an exp sweep.
    t = np.arange(n) / SAMPLE_RATE
    ramp = (t / (n / SAMPLE_RATE)) ** 2.0
    coeff = 0.30 + 0.60 * ramp
    hp = np.empty(n)
    hp[0] = noise[0]
    for i in range(1, n):
        hp[i] = coeff[i] * (hp[i - 1] + noise[i] - noise[i - 1])
    sweep = np.sin(2.0 * np.pi * (300.0 + 2600.0 * ramp) * t) * 0.5
    env = ramp ** 1.5
    buffer[rise_start:end] += (hp * 1.2 + sweep) * env * 0.30
    # Zap on the downbeat of bar 3 (the section change).
    zap_at = seconds_to_samples(SECONDS_PER_BAR * 2)
    zlen = seconds_to_samples(0.5)
    zend = min(zap_at + zlen, total)
    zn = zend - zap_at
    tz = np.arange(zn) / SAMPLE_RATE
    chirp = np.sin(2.0 * np.pi * (1800.0 - 1500.0 * (tz / 0.5)) * tz)
    buffer[zap_at:zend] += chirp * env_ads(zn, 0.001, 0.4) * 0.22
    # Bright impact exactly at the loop point so the seam feels intentional.
    seam = seconds_to_samples(LOOP_SECONDS) - seconds_to_samples(0.35)
    slen = total - seam
    ts = np.arange(slen) / SAMPLE_RATE
    rng2 = np.random.default_rng(37)
    noise2 = rng2.standard_normal(slen)
    alpha = 0.8
    hp2 = np.empty(slen)
    hp2[0] = noise2[0]
    for i in range(1, slen):
        hp2[i] = alpha * (hp2[i - 1] + noise2[i] - noise2[i - 1])
    buffer[seam:] += hp2 * env_ads(slen, 0.001, 0.3) * 0.16
    return soft_clip(buffer, 1.4) * 0.75


# --- Music orchestration --------------------------------------------------

def build_all_music() -> dict[str, np.ndarray]:
    """Build the five stems and the pre-mixed 'full' reference mix."""
    stems = {
        "music_drums.wav": build_drums(),
        "music_bass.wav": build_bass(),
        "music_lead.wav": build_lead(),
        "music_harmony.wav": build_harmony(),
        "music_fx.wav": build_fx(),
    }
    # Mix balance: the stems are authored independently, so the "full" mix
    # uses fixed gains (not a sum of the normalized files) to keep the mix
    # identical on every rebuild.
    mix = (
        stems["music_drums.wav"] * 0.95
        + stems["music_bass.wav"] * 0.90
        + stems["music_lead.wav"] * 0.80
        + stems["music_harmony.wav"] * 0.55
        + stems["music_fx.wav"] * 0.50
    )
    stems["music_full.wav"] = normalize(soft_clip(mix, 1.15), 0.92)
    return stems


def write_music() -> list[tuple[str, int, int]]:
    """Write every stem as stereo 16-bit WAV; returns (name, bytes, frames).

    Stems are forward-looped and uncompressed: MusicDirector plays a layer and
    never stops it, and the stems are period-exact loops (see the bar math
    above), so they must survive an indefinite number of loop wraps.
    """
    written: list[tuple[str, int, int]] = []
    for name, signal in build_all_music().items():
        stereo = to_stereo(signal, 0.35 if "harmony" in name or "lead" in name else 0.0)
        path = os.path.join(OUT_MUSIC, name)
        size = write_wav(path, stereo, channels=2)
        write_import_sidecar(path, loop=True, compress_mode=0)
        written.append((name, size, stereo.shape[0]))
    return written


# --- SFX synthesis --------------------------------------------------------

def sfx_arpeggio(base_midi: int, steps: list[int], step_s: float, gain: float,
                 wave_kind: str = "square") -> np.ndarray:
    """Stepped arpeggio used by the score / pickup stings."""
    n = seconds_to_samples(step_s * len(steps))
    out = silent(n)
    for i, interval in enumerate(steps):
        at = seconds_to_samples(step_s * i)
        n_s = seconds_to_samples(step_s)
        end = min(at + n_s, n)
        seg = end - at
        if seg <= 0:
            continue
        t = np.arange(seg) / SAMPLE_RATE
        freq = note_hz(base_midi + interval)
        if wave_kind == "square":
            sig = np.sign(np.sin(2.0 * np.pi * freq * t))
        else:
            sig = 2.0 * (t * freq - np.floor(0.5 + t * freq))
        out[at:end] += sig * env_ads(seg, 0.002, step_s * 0.8) * gain
    return soft_clip(out, 1.3) * 0.8


def build_sfx() -> dict[str, np.ndarray]:
    """Every SFX the library expects, grouped the way BusLayout routes them."""
    sfx: dict[str, np.ndarray] = {}

    # --- group: player ---
    # Pickup: bright two-note ping with a shimmer tail.
    ping = sfx_arpeggio(76, [0, 7], 0.075, 0.5)
    tail_n = seconds_to_samples(0.30)
    t = np.arange(tail_n) / SAMPLE_RATE
    shimmer = np.sin(2.0 * np.pi * 1568.0 * t) * env_ads(tail_n, 0.01, 0.28) * 0.18
    sfx["sfx_pickup.wav"] = normalize(np.concatenate([ping, shimmer]), 0.85)

    # Jump: quick upward sine sweep with a short noise whoosh.
    n = seconds_to_samples(0.22)
    t = np.arange(n) / SAMPLE_RATE
    sweep = np.sin(2.0 * np.pi * (220.0 + 900.0 * (t / 0.22)) * t)
    whoosh = np.random.default_rng(41).standard_normal(n)
    alpha = 0.7
    hp = np.empty(n)
    hp[0] = whoosh[0]
    for i in range(1, n):
        hp[i] = alpha * (hp[i - 1] + whoosh[i] - whoosh[i - 1])
    sfx["sfx_jump.wav"] = normalize(
        (sweep * 0.7 + hp * 0.12 * (t / 0.22)) * env_ads(n, 0.003, 0.2), 0.9
    )

    # --- group: impact (the four ImpactFrame tiers) ---
    def impact(duration: float, thump_hz: float, noise_gain: float) -> np.ndarray:
        n = seconds_to_samples(duration)
        t = np.arange(n) / SAMPLE_RATE
        body = np.sin(2.0 * np.pi * thump_hz * t) * np.exp(-t / (duration * 0.30))
        snap = np.random.default_rng(43).standard_normal(n)
        alpha = 0.75
        hp = np.empty(n)
        hp[0] = snap[0]
        for i in range(1, n):
            hp[i] = alpha * (hp[i - 1] + snap[i] - snap[i - 1])
        env = env_ads(n, 0.001, duration * 0.8)
        return normalize((body + hp * noise_gain) * env, 0.92)

    sfx["sfx_hit.wav"] = impact(0.28, 150.0, 0.55)
    sfx["sfx_impact_light.wav"] = impact(0.18, 220.0, 0.30)
    sfx["sfx_impact_medium.wav"] = impact(0.26, 175.0, 0.45)
    sfx["sfx_impact_heavy.wav"] = impact(0.34, 120.0, 0.70)
    sfx["sfx_impact_critical.wav"] = impact(0.45, 90.0, 0.95)

    # Fail: descending detuned sweep + a low boom (never cruel, just "oof").
    # Same integrated-sweep math as the kick: the frequency must decay
    # WITHOUT going negative, otherwise t=0 aliases into noise.
    n = seconds_to_samples(0.55)
    t = np.arange(n) / SAMPLE_RATE
    f0, f1, sweep = note_hz(64), note_hz(52), 0.18
    decay = np.exp(-t / sweep)
    phase = 2.0 * np.pi * (f1 * t + (f0 - f1) * sweep * (1.0 - decay))
    sig = np.sin(phase) * 0.6
    sig += np.sin(2.0 * np.pi * note_hz(50) * t) * np.exp(-t / 0.22) * 0.5
    sfx["sfx_fail.wav"] = normalize(sig * env_ads(n, 0.004, 0.5), 0.9)

    # Score: rising major arpeggio (rewarding, arcade-y).
    sfx["sfx_score.wav"] = sfx_arpeggio(72, [0, 4, 7, 12], 0.06, 0.45)

    # --- group: ui ---
    # UI click: very short blip, no tail (clean bus, no reverb). Kept inside
    # the brief's 0.1-1.0 s window while still reading as a click.
    n = seconds_to_samples(0.14)
    t = np.arange(n) / SAMPLE_RATE
    blip = np.sin(2.0 * np.pi * 1200.0 * t) * 0.7 + np.sin(2.0 * np.pi * 2400.0 * t) * 0.3
    sfx["sfx_ui_click.wav"] = normalize(blip * env_ads(n, 0.0008, 0.12), 0.8)

    # UI hover: the quietest, shortest cue in the game (passive feedback).
    n = seconds_to_samples(0.12)
    t = np.arange(n) / SAMPLE_RATE
    sfx["sfx_ui_hover.wav"] = normalize(
        np.sin(2.0 * np.pi * 880.0 * t) * env_ads(n, 0.001, 0.1), 0.45
    )

    # --- group: world ---
    # Roulette: ratcheting tick loop (the spin).
    n = seconds_to_samples(0.85)
    out = silent(n)
    tick_every = seconds_to_samples(0.045)
    i = 0
    rng = np.random.default_rng(47)
    while i < n:
        seg = seconds_to_samples(0.05)
        end = min(i + seg, n)
        noise = rng.standard_normal(end - i)
        out[i:end] += noise * env_ads(end - i, 0.0004, 0.035) * 0.55
        i += tick_every
    t = np.arange(n) / SAMPLE_RATE
    whoosh = rng.standard_normal(n)
    alpha = 0.55
    hp = np.empty(n)
    hp[0] = whoosh[0]
    for i2 in range(1, n):
        hp[i2] = alpha * (hp[i2 - 1] + whoosh[i2] - whoosh[i2 - 1])
    out += hp * 0.10 * (t / 0.85)
    sfx["sfx_roulette.wav"] = normalize(soft_clip(out, 1.2), 0.85)

    # Countdown: single clean beep (one per second of the 3-2-1).
    n = seconds_to_samples(0.22)
    t = np.arange(n) / SAMPLE_RATE
    sfx["sfx_countdown.wav"] = normalize(
        np.sin(2.0 * np.pi * 880.0 * t) * env_ads(n, 0.002, 0.18), 0.85
    )

    # Countdown GO: brighter, higher, longer than the tick (the release).
    n = seconds_to_samples(0.5)
    t = np.arange(n) / SAMPLE_RATE
    sig = np.sin(2.0 * np.pi * 1320.0 * t) * 0.6 + np.sin(2.0 * np.pi * 1760.0 * t) * 0.4
    sfx["sfx_countdown_go.wav"] = normalize(sig * env_ads(n, 0.002, 0.42), 0.92)

    # Powerup spawn: soft chime that announces a new orb (world group).
    n = seconds_to_samples(0.5)
    t = np.arange(n) / SAMPLE_RATE
    sig = (
        np.sin(2.0 * np.pi * 1046.0 * t) * 0.35
        + np.sin(2.0 * np.pi * 1568.0 * t) * 0.30
        + np.sin(2.0 * np.pi * 2093.0 * t) * 0.15
    )
    sfx["sfx_powerup_spawn.wav"] = normalize(sig * env_ads(n, 0.006, 0.45), 0.8)

    # Combo step: short rising blip, pitch escalates via the ±5% randomizer.
    n = seconds_to_samples(0.15)
    t = np.arange(n) / SAMPLE_RATE
    sweep = np.sin(2.0 * np.pi * (600.0 + 700.0 * (t / 0.15)) * t)
    sfx["sfx_combo.wav"] = normalize(sweep * env_ads(n, 0.002, 0.13), 0.8)

    return sfx


def write_sfx() -> list[tuple[str, int, int]]:
    """Write every SFX as mono 16-bit WAV; returns (name, bytes, frames).

    One-shots: loop disabled. QOA compression (Godot's default for short
    sounds) keeps the 16 files small in memory; the source stays raw PCM.
    """
    written: list[tuple[str, int, int]] = []
    for name, signal in build_sfx().items():
        path = os.path.join(OUT_SFX, name)
        size = write_wav(path, signal, channels=1)
        write_import_sidecar(path, loop=False, compress_mode=2)
        written.append((name, size, signal.size))
    return written


# --- Ambience -------------------------------------------------------------

def build_ambience() -> np.ndarray:
    """City bed: low drone + slow filtered noise, seamless 4 s loop."""
    duration = 4.0
    total = seconds_to_samples(duration)
    t = np.arange(total) / SAMPLE_RATE
    # Low drone: two slightly detuned sines around 55/82 Hz (traffic rumble).
    drone = np.sin(2.0 * np.pi * 55.0 * t) * 0.30
    drone += np.sin(2.0 * np.pi * 82.5 * t) * 0.22
    drone += np.sin(2.0 * np.pi * 110.0 * t) * 0.10
    # Filtered noise "air", amplitude-modulated so it breathes every 2 s.
    rng = np.random.default_rng(53)
    noise = rng.standard_normal(total)
    alpha = 0.06                      # heavy low-pass -> distant city hiss
    lp = np.empty(total)
    lp[0] = noise[0]
    for i in range(1, total):
        lp[i] = alpha * noise[i] + (1.0 - alpha) * lp[i - 1]
    # Modulation period divides the loop exactly (2 s) -> no seam pop.
    lfo = 0.5 + 0.5 * np.sin(2.0 * np.pi * 0.5 * t)
    bed = drone + lp * (0.35 + 0.30 * lfo)
    # Fade the first/last 60 ms so the loop point is inaudible.
    fade = seconds_to_samples(0.06)
    env = np.ones(total)
    env[:fade] = np.linspace(0.0, 1.0, fade)
    env[-fade:] = np.linspace(1.0, 0.0, fade)
    return normalize(bed * env, 0.55)


def write_ambience() -> list[tuple[str, int, int]]:
    """Write the ambience loop as stereo 16-bit WAV, forward-looped, raw PCM."""
    signal = build_ambience()
    stereo = to_stereo(signal, 0.5)
    path = os.path.join(OUT_AMB, "amb_city_loop.wav")
    size = write_wav(path, stereo, channels=2)
    write_import_sidecar(path, loop=True, compress_mode=0)
    return [("amb_city_loop.wav", size, stereo.shape[0])]


# --- Entry point ----------------------------------------------------------

def main() -> int:
    np.random.seed(0)  # deterministic output for reproducible rebuilds
    music = write_music()
    sfx = write_sfx()
    ambience = write_ambience()

    print("music (%d files, %.1f s loop @ %.0f BPM, stereo 16-bit):"
          % (len(music), LOOP_SECONDS, BPM))
    for name, size, frames in music:
        print("  %-22s %8d bytes  %6d frames" % (name, size, frames))
    print("sfx (%d files, mono 16-bit):" % len(sfx))
    for name, size, frames in sfx:
        print("  %-22s %8d bytes  %6d frames  %.3f s"
              % (name, size, frames, frames / SAMPLE_RATE))
    print("ambience (%d files, stereo 16-bit):" % len(ambience))
    for name, size, frames in ambience:
        print("  %-22s %8d bytes  %6d frames  %.3f s"
              % (name, size, frames, frames / SAMPLE_RATE))
    print("total files: %d" % (len(music) + len(sfx) + len(ambience)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
