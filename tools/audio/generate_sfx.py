#!/usr/bin/env python3
"""
Procedural Retro Arcade SFX Synthesizer for Side Beat.
Generates crisp 16-bit 44.1 kHz mono WAV sound effects in res://assets/sfx/.
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100


def clamp(v: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, v))


def write_wav(filepath: str, samples: list[float], gain: float = 0.88) -> None:
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0)
    scale = (gain / peak) if peak > 1e-6 else 1.0
    pcm = bytearray()
    for s in samples:
        val = int(clamp(s * scale) * 32767.0)
        pcm.extend(struct.pack("<h", val))
    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(pcm))


def env_ad(t: float, dur: float, attack: float = 0.003, curve: float = 2.2) -> float:
    if t < 0.0 or t >= dur:
        return 0.0
    if t < attack:
        return t / max(attack, 1e-5)
    rem = 1.0 - ((t - attack) / max(dur - attack, 1e-5))
    return max(0.0, rem) ** curve


def square(phase: float) -> float:
    return 1.0 if math.sin(phase) >= 0.0 else -1.0


def saw(phase: float) -> float:
    x = (phase / (2.0 * math.pi)) % 1.0
    return 2.0 * x - 1.0


def synth_impact(dur: float, f_start: float, f_end: float, noise_amt: float, crunch: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * dur)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        prog = t / dur
        freq = f_start * ((f_end / max(f_start, 1.0)) ** (prog ** 0.55))
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        body = math.sin(phase) * 0.7 + square(phase * 0.5) * 0.3
        raw_noise = rng.uniform(-1.0, 1.0)
        lp = lp + 0.32 * (raw_noise - lp)
        snap = env_ad(t, min(dur, 0.045), 0.001, 1.8) * raw_noise
        sig = (body * (1.0 - noise_amt * 0.45) + lp * noise_amt + snap * 0.65) * env_ad(t, dur, 0.002, 2.0)
        sig = math.tanh(sig * crunch)
        out.append(sig)
    return out


def synth_thunder(dur: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * dur)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 210.0 * (0.22 ** (t / dur)) + 38.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        crackle = rng.uniform(-1.0, 1.0) * (1.0 if rng.random() > 0.35 else 0.2)
        lp = lp + 0.18 * (crackle - lp)
        zap = math.sin(phase * (1.0 + 0.35 * math.sin(t * 95.0)))
        sig = (zap * 0.58 + lp * 0.75) * env_ad(t, dur, 0.002, 1.65)
        out.append(math.tanh(sig * 2.4))
    return out


def synth_blade(dur: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * dur)
    out = []
    phase = 0.0
    hp_prev = 0.0
    raw_prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 1650.0 * ((420.0 / 1650.0) ** (t / dur))
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        raw = rng.uniform(-1.0, 1.0)
        hp = 0.85 * (hp_prev + raw - raw_prev)
        hp_prev, raw_prev = hp, raw
        ring = math.sin(phase) + 0.4 * math.sin(phase * 2.41)
        sig = (ring * 0.55 + hp * 0.65) * env_ad(t, dur, 0.0015, 2.1)
        out.append(math.tanh(sig * 1.8))
    return out


def synth_morph(dur: float, base_f: float, harmonics: list[float]) -> list[float]:
    n = int(SAMPLE_RATE * dur)
    out = []
    phases = [0.0 for _ in harmonics]
    for i in range(n):
        t = i / SAMPLE_RATE
        sweep = 0.8 + 0.65 * (t / dur)
        acc = 0.0
        for idx, h in enumerate(harmonics):
            phases[idx] += 2.0 * math.pi * (base_f * h * sweep) / SAMPLE_RATE
            acc += math.sin(phases[idx]) / (1.0 + idx * 0.55)
        shimmer = 0.75 + 0.25 * math.sin(t * 72.0)
        out.append(math.tanh(acc * shimmer * env_ad(t, dur, 0.004, 1.7) * 1.3))
    return out


def synth_arpeggio(notes_hz: list[float], note_dur: float, wave_kind: str = "square") -> list[float]:
    out = []
    phase = 0.0
    for freq in notes_hz:
        n = int(SAMPLE_RATE * note_dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            phase += 2.0 * math.pi * freq / SAMPLE_RATE
            osc = square(phase) * 0.55 + math.sin(phase) * 0.45 if wave_kind == "square" else saw(phase) * 0.6 + math.sin(phase * 2.0) * 0.4
            out.append(osc * env_ad(t, note_dur, 0.003, 1.5))
    return out


def synth_metallic_clang(dur: float, root_hz: float) -> list[float]:
    n = int(SAMPLE_RATE * dur)
    ratios = [1.0, 1.47, 2.13, 2.91, 3.77]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = sum(math.sin(2.0 * math.pi * root_hz * r * t) * (0.75 ** idx) for idx, r in enumerate(ratios))
        out.append(math.tanh(s * env_ad(t, dur, 0.001, 2.3) * 1.6))
    return out


def main() -> None:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sfx_dir = os.path.join(root, "assets", "sfx")
    os.makedirs(sfx_dir, exist_ok=True)

    bank: dict[str, list[float]] = {
        "hit_light.wav": synth_impact(0.11, 340.0, 75.0, 0.42, 2.2, 101),
        "hit_heavy.wav": synth_impact(0.22, 220.0, 42.0, 0.55, 2.9, 102),
        "hit_thunder.wav": synth_thunder(0.34, 103),
        "hit_blade.wav": synth_blade(0.14, 104),
        "hit_flail.wav": synth_impact(0.19, 480.0, 95.0, 0.50, 2.3, 105),
        "hit_solar.wav": synth_impact(0.24, 620.0, 110.0, 0.38, 2.5, 106),
        "block_thud.wav": synth_impact(0.09, 190.0, 80.0, 0.20, 1.7, 107),
        "parry_clang.wav": synth_metallic_clang(0.30, 880.0),
        "armor_break.wav": synth_thunder(0.40, 109),
        "grab_throw.wav": synth_impact(0.20, 150.0, 310.0, 0.35, 2.1, 110),
        "ko_boom.wav": synth_thunder(0.58, 111),
        "morph_endor.wav": synth_morph(0.16, 220.0, [1.0, 1.5, 2.0, 3.0]),
        "morph_ir.wav": synth_morph(0.14, 440.0, [1.0, 1.25, 1.5, 2.5]),
        "morph_osiris.wav": synth_morph(0.17, 261.63, [1.0, 1.2, 1.8, 2.4]),
        "morph_horus.wav": synth_morph(0.15, 349.23, [1.0, 1.33, 2.0, 3.0]),
        "super_flash.wav": synth_morph(0.45, 330.0, [1.0, 1.5, 2.0, 2.5, 4.0]),
        "go_siren.wav": synth_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.085, "saw"),
        "prop_smash.wav": synth_impact(0.26, 290.0, 55.0, 0.78, 2.6, 118),
        "pickup_hp.wav": synth_arpeggio([440.0, 554.37, 659.25, 880.0], 0.065, "square"),
        "pickup_meter.wav": synth_arpeggio([392.0, 587.33, 783.99, 1174.66], 0.06, "saw"),
        "pickup_gold.wav": synth_metallic_clang(0.18, 1318.5),
        "boss_warning.wav": synth_arpeggio([220.0, 155.56, 220.0, 155.56], 0.14, "saw"),
        "ui_move.wav": synth_arpeggio([660.0], 0.045, "square"),
        "ui_confirm.wav": synth_arpeggio([523.25, 783.99], 0.065, "square"),
        "continue_tick.wav": synth_arpeggio([440.0, 330.0], 0.055, "square"),
    }

    for filename, samples in bank.items():
        write_wav(os.path.join(sfx_dir, filename), samples)
    print(f"Generated {len(bank)} WAV SFX files in {sfx_dir}")


if __name__ == "__main__":
    main()
