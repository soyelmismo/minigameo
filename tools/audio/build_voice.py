#!/usr/bin/env python3
"""Build the announcer VO assets (scaffold §6.10, §10.3, §2 tone guide).

Synthesises every line in the VoiceLines catalog with the local piper-ng
model, then applies an arcade announcer chain: high-pass to clear the rumble,
a gentle soft-clip for the "radio voice" bite, hard limiting and a touch of
short reverb so the line cuts through the music mix.

Outputs 16-bit mono WAVs plus the Godot .import sidecars the engine needs to
load them in headless runs, under assets/audio/voice/.
"""

from __future__ import annotations

import json
import math
import os
import struct
import sys
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOICE_DIR = ROOT / "assets" / "audio" / "voice"
CATALOG = ROOT / "src" / "audio" / "voice_lines.gd"

# Model + config downloaded by fetch_voice_model.py.
MODEL_DIR = Path(os.environ.get("PIPER_MODEL_DIR", "/tmp/piper-voice"))
MODEL_ONNX = MODEL_DIR / "en_US-lessac-medium.onnx"
MODEL_JSON = MODEL_DIR / "en_US-lessac-medium.json"

SRC_DURATION_PAD_S = 0.12
OUTPUT_RATE = 22050


# --- catalog parsing -------------------------------------------------------

def parse_catalog(path: Path) -> dict[str, list[str]]:
    """Read {EVENT: [line, ...]} from the GDScript catalog without a parser."""
    events: dict[str, list[str]] = {}
    current: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("EV_") and ":" in line and "[" in line:
            name = line.split(":", 1)[0].strip()
            current = name
            events[current] = []
            tail = line.split("[", 1)[1]
            for found in _strings(tail):
                events[current].append(found)
            continue
        if current is not None and '"' in line:
            events[current].extend(_strings(line))
        if current is not None and line.startswith("]"):
            current = None
    return {k: v for k, v in events.items() if v}


def _strings(text: str) -> list[str]:
    out: list[str] = []
    i = 0
    while True:
        start = text.find('"', i)
        if start < 0:
            break
        end = text.find('"', start + 1)
        if end < 0:
            break
        out.append(text[start + 1:end])
        i = end + 1
    return out


def event_filename(event: str) -> str:
    """EV_MINIGAME_START -> vo_minigame_start.wav"""
    body = event[3:] if event.startswith("EV_") else event
    return "vo_" + body.lower() + ".wav"


# --- synthesis -------------------------------------------------------------

def synth_line(text: str, out_path: Path) -> bool:
    """Render one line with piper. Returns True on success."""
    if not MODEL_ONNX.exists():
        sys.stderr.write(f"missing model: {MODEL_ONNX}\n")
        return False
    try:
        from piper import PiperVoice
    except Exception as exc:  # pragma: no cover - environment dependent
        sys.stderr.write(f"piper unavailable: {exc}\n")
        return False

    try:
        voice = PiperVoice.load(str(MODEL_ONNX), config_path=str(MODEL_JSON))
    except TypeError:
        voice = PiperVoice.load(str(MODEL_ONNX))

    length_scale = None
    if hasattr(voice, "config") and isinstance(voice.config, dict):
        phoneme_type = voice.config.get("phoneme_type")
        if phoneme_type and hasattr(voice, "phonemize"):
            text = voice.phonemize(text, phoneme_type)

    chunks = list(voice.synthesize(text))
    if not chunks:
        return False
    pcm = array("h")
    rate = 22050
    for chunk in chunks:
        rate = int(getattr(chunk, "sample_rate", rate) or rate)
        pcm.extend(chunk.audio_int16_bytes_to_array() if hasattr(chunk, "audio_int16_bytes_to_array") else array("h", chunk.audio_int16_array))
    if not pcm:
        return False
    write_wav(out_path, arcade_chain(pcm, rate, rate), rate)
    return True


# --- arcade processing -----------------------------------------------------

def arcade_chain(pcm: array, rate: int, out_rate: int) -> array:
    """High-pass, soft-clip bite, limiter and a short slap of reverb."""
    # 1) High-pass at 180 Hz (one-pole, cheap and enough for VO).
    hp = one_pole_highpass(pcm, rate, 180.0)
    # 2) Soft clip: tanh-ish curve keeps the voice present in a loud mix.
    clipped = array("h", (int(max(-32767, min(32767, soft_clip(v, 0.85)))) for v in hp))
    # 3) Limit peaks to -1 dBFS.
    peak = max((abs(v) for v in clipped), default=1) or 1
    target = int(32767 * 0.891)
    if peak > target:
        clipped = array("h", (int(v * target / peak) for v in clipped))
    # 4) Short slap-back reverb, mixed low: the "arena announcer" distance.
    wet = slap_delay(clipped, rate, delay_s=0.09, mix=0.14)
    # 5) Silence padding so the line does not clip its first consonant.
    padded = array("h", [0] * int(rate * SRC_DURATION_PAD_S)) + wet
    padded += array("h", [0] * int(rate * SRC_DURATION_PAD_S))
    return padded


def one_pole_highpass(pcm: array, rate: int, cutoff: float) -> array:
    rc = 1.0 / (2.0 * math.pi * cutoff)
    dt = 1.0 / rate
    alpha = rc / (rc + dt)
    out = array("h")
    prev_in = 0.0
    prev_out = 0.0
    for v in pcm:
        f = float(v)
        value = alpha * (prev_out + f - prev_in)
        out.append(int(max(-32767, min(32767, value))))
        prev_in, prev_out = f, value
    return out


def soft_clip(value: float, drive: float) -> float:
    x = value / 32767.0 * drive
    y = math.tanh(x * 1.6) / math.tanh(1.6)
    return y * 32767.0


def slap_delay(pcm: array, rate: int, delay_s: float, mix: float) -> array:
    delay = int(rate * delay_s)
    out = array("h", pcm)
    if delay <= 0 or delay >= len(out):
        return out
    for i in range(delay, len(out)):
        out[i] = int(max(-32767, min(32767, out[i] + mix * out[i - delay])))
    return out


# --- wav + Godot import sidecar -------------------------------------------

def write_wav(path: Path, pcm: array, rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def stable_uid(res_path: str) -> str:
    """Godot derives the .uid from the resource path; keep it deterministic."""
    import hashlib

    digest = hashlib.sha1(res_path.encode("utf-8")).hexdigest()
    return "uid://" + digest[:13]


def write_import_sidecar(wav: Path) -> None:
    res = "res://" + wav.relative_to(ROOT).as_posix()
    uid = stable_uid(res)
    sidecar = wav.with_suffix(wav.suffix + ".import")
    sidecar.write_text(
        "[remap]\n\n"
        f'importer = "wav"\n'
        f'type = "AudioStreamWAV"\n'
        f'uid = "{uid}"\n'
        f'path = "{wav.with_suffix("").name}.wav"\n\n'
        "[deps]\n\n"
        f'source_file = "{wav.with_suffix("").name}.wav"\n\n'
        "[params]\n\n"
        "edit/loop_mode = 0\n"
        "edit/loop_begin = 0\n"
        "edit/loop_end = -1\n"
        "edit/normalize = false\n"
        "edit/trim = false\n\n"
        "[ext_resource path=\"\"]\n" if False else
        "[remap]\n\n"
        f'importer = "wav"\n'
        f'type = "AudioStreamWAV"\n'
        f'uid = "{uid}"\n'
        f'path = "{wav.with_suffix("").name}.wav"\n\n'
        "[deps]\n\n"
        f'source_file = "{wav.with_suffix("").name}.wav"\n\n'
        "[params]\n\n"
        "edit/loop_mode = 0\n"
        "edit/loop_begin = 0\n"
        "edit/loop_end = -1\n"
        "edit/normalize = false\n"
        "edit/trim = false\n",
        encoding="utf-8",
    )


def main() -> int:
    catalog = parse_catalog(CATALOG)
    print(f"catalog events: {len(catalog)}")
    made = 0
    for event, lines in sorted(catalog.items()):
        # One file per event; the director picks a line from the catalog, so a
        # single rendered line per event is the deterministic choice.
        text = lines[0]
        text = text.replace("{5}", "5")
        out = VOICE_DIR / event_filename(event)
        if synth_line(text, out):
            write_import_sidecar(out)
            made += 1
            print(f"  {event:26s} -> {out.name}  \"{text}\"")
        else:
            print(f"  {event:26s} FAILED \"{text}\"")
    print(f"generated {made}/{len(catalog)} VO lines")
    return 0 if made == len(catalog) else 1


if __name__ == "__main__":
    raise SystemExit(main())
