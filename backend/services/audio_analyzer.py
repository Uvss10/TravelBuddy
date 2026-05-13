"""
backend/services/audio_analyzer.py — Audio Intelligence & Beat Sync Engine

Phase 1 of the cinematic upgrade. Analyzes uploaded music to drive cut timing.

What it does:
  1. Detects BPM and extracts beat timestamps using librosa (pure-Python, offline)
  2. Builds an energy curve across the full 60-second track
  3. Identifies energy sections: intro / build / peak / drop / outro
  4. Returns a BeatMap used by the TimelineBuilder to align video cuts to music

Fallback:
  If librosa is not installed, returns a synthetic BeatMap at a fixed 120 BPM,
  so the rest of the pipeline always receives a valid object.
"""

from __future__ import annotations

import os
import math
import json
import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional


# ── Caching Helper ────────────────────────────────────────────────────────────

def _get_cache_path(audio_path: str, duration_s: float) -> Path:
    cache_dir = Path("data/cache/audio")
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    # Fingerprint by path + modification time + duration
    mtime = os.path.getmtime(audio_path)
    base_hash = hashlib.sha256(f"{audio_path}_{mtime}_{duration_s}".encode()).hexdigest()[:16]
    return cache_dir / f"{Path(audio_path).stem}_{base_hash}.json"

def _load_from_cache(cache_path: Path) -> Optional[BeatMap]:
    if cache_path.exists():
        try:
            with open(cache_path, "r") as f:
                data = json.load(f)
            return BeatMap(**data)
        except Exception:
            return None
    return None

def _save_to_cache(cache_path: Path, beatmap: BeatMap):
    try:
        from dataclasses import asdict
        with open(cache_path, "w") as f:
            json.dump(asdict(beatmap), f)
    except Exception as e:
        print(f"[Audio] Error caching beatmap: {e}")

# ── Data types ─────────────────────────────────────────────────────────────────

@dataclass
class BeatMap:
    """Fully describes the rhythmic structure of an audio file."""
    bpm: float                          # detected tempo
    duration_s: float                   # total audio length in seconds (clipped to 60)
    beat_times: List[float]             # timestamps (seconds) of every detected beat
    energy_curve: List[float]           # 0–1 energy value sampled every 0.5 s (120 samples for 60 s)
    sections: List[dict]                # [{label, start_s, end_s, energy_avg}]
    # Convenience: ordered cut points (beat_times filtered to every N-th beat per section)
    cut_points: List[float]


# ── Easing helpers ─────────────────────────────────────────────────────────────

def _ease_inout(t: float) -> float:
    """Smooth step — maps 0..1 → 0..1 with ease in/out curve."""
    return t * t * (3 - 2 * t)


# ── Synthetic fallback ─────────────────────────────────────────────────────────

def _synthetic_beatmap(duration_s: float = 60.0, bpm: float = 120.0) -> BeatMap:
    """
    Returns a synthetic BeatMap when librosa is unavailable.
    Energy follows a gentle bell curve (intro → peak → outro).
    """
    beat_interval = 60.0 / bpm
    beat_times = []
    t = 0.0
    while t <= duration_s:
        beat_times.append(round(t, 4))
        t += beat_interval

    # Smooth energy arc: low → high (30 s) → low
    samples = int(duration_s / 0.5)
    energy_curve = []
    for i in range(samples):
        t_norm = i / max(1, samples - 1)          # 0 → 1
        # Bell-ish: rises to 0.9 at 60%, falls off
        env = math.sin(t_norm * math.pi) * 0.8 + 0.15
        energy_curve.append(round(min(1.0, env), 4))

    # Sections: use the dynamic detector logic
    sections = _detect_sections(energy_curve, duration_s)

    # Cut points: every beat during peak, every other beat elsewhere
    cut_points = []
    for bt in beat_times:
        if 20.0 <= bt <= 40.0:
            cut_points.append(bt)
        elif bt % (beat_interval * 2) < beat_interval:
            cut_points.append(bt)

    return BeatMap(
        bpm=bpm,
        duration_s=duration_s,
        beat_times=beat_times,
        energy_curve=energy_curve,
        sections=sections,
        cut_points=sorted(set(cut_points)),
    )


# ── Main analyzer ──────────────────────────────────────────────────────────────

def analyze_audio(audio_path: str, target_duration_s: float = 60.0) -> BeatMap:
    """
    Analyze an audio file and return a BeatMap.

    Attempts to use librosa for real beat detection.
    Falls back to a synthetic BeatMap if librosa is missing or the file fails.

    Args:
        audio_path:        Absolute path to an audio file (mp3, wav, ogg, flac, m4a).
        target_duration_s: Clip length to analyze (default 60 s for reel generation).

    Returns:
        BeatMap
    """
    try:
        import librosa  # type: ignore
        import numpy as np
    except ImportError:
        # librosa not installed — silently return synthetic map
        return _synthetic_beatmap(duration_s=target_duration_s)

    # Check cache first
    cache_path = _get_cache_path(audio_path, target_duration_s)
    cached_map = _load_from_cache(cache_path)
    if cached_map:
        print("[Audio] Loading beatmap from cache.")
        return cached_map

    print("[Audio] Analyzing audio with librosa (sr=22050)...")
    try:
        # Load up to target_duration_s of audio at 22050 Hz for speed
        y, sr = librosa.load(audio_path, sr=22050, mono=True,
                             duration=target_duration_s + 2.0)  # +2 s buffer
        
        # We use target_duration_s as the master timeline length
        # even if the audio file is shorter (the muxer will loop or pad silent)
        actual_audio_dur = len(y) / sr
        master_duration  = target_duration_s

        # ── BPM + beat frames ────────────────────────────────────────────────
        tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr, units="frames")
        bpm = float(tempo) if np.isscalar(tempo) else float(tempo[0])
        bpm = max(40.0, min(240.0, bpm))  # sanity clamp

        beat_times_raw = librosa.frames_to_time(beat_frames, sr=sr).tolist()
        beat_times = [round(t, 4) for t in beat_times_raw if t <= actual_audio_dur]

        # ── RMS energy curve (sampled every 0.5 s) ───────────────────────────
        # Ensure energy curve covers the FULL target duration
        n_samples = int(master_duration / 0.5)
        hop = int(sr * 0.5)
        rms = librosa.feature.rms(y=y, hop_length=hop)[0]
        rms_norm = rms / (rms.max() + 1e-8)
        
        energy_curve = [round(float(e), 4) for e in rms_norm]
        # Pad with silence if audio is shorter than master_duration
        if len(energy_curve) < n_samples:
            energy_curve.extend([0.05] * (n_samples - len(energy_curve)))
        else:
            energy_curve = energy_curve[:n_samples]

        # Smooth energy with a 3-sample moving average
        smoothed = []
        for i, e in enumerate(energy_curve):
            window = energy_curve[max(0, i - 1): i + 2]
            smoothed.append(round(sum(window) / len(window), 4))
        energy_curve = smoothed

        # ── Section detection ────────────────────────────────────────────────
        sections = _detect_sections(energy_curve, master_duration)

        # ── Cut points: beat-aligned, density driven by energy ──────────────
        cut_points = _build_cut_points(beat_times, energy_curve, master_duration)

        beatmap = BeatMap(
            bpm=bpm,
            duration_s=master_duration,
            beat_times=beat_times,
            energy_curve=energy_curve,
            sections=sections,
            cut_points=cut_points,
        )
        
        _save_to_cache(cache_path, beatmap)
        return beatmap

    except Exception:
        return _synthetic_beatmap(duration_s=target_duration_s)


def _detect_sections(
    energy_curve: List[float],
    duration_s: float,
) -> List[dict]:
    """
    Classify the track into cinematic sections based on energy.
    Returns list of dicts with label, start_s, end_s, energy_avg.
    """
    # Fixed 5-section template aligned to a 60-s reel
    templates = [
        ("intro",       0.0,  5.0),
        ("exploration", 5.0,  20.0),
        ("peak",        20.0, 40.0),
        ("scenic",      40.0, 55.0),
        ("outro",       55.0, duration_s),
    ]

    sample_rate = 0.5  # seconds per energy sample

    def avg_energy(start: float, end: float) -> float:
        lo = int(start / sample_rate)
        hi = int(end / sample_rate)
        sub = energy_curve[lo:hi]
        return round(sum(sub) / max(1, len(sub)), 4)

    return [
        {
            "label":      label,
            "start_s":    start,
            "end_s":      min(end, duration_s),
            "energy_avg": avg_energy(start, min(end, duration_s)),
        }
        for label, start, end in templates
        if start < duration_s
    ]


def _build_cut_points(
    beat_times: List[float],
    energy_curve: List[float],
    duration_s: float,
) -> List[float]:
    """
    Select which beats become actual video cuts.
    High energy → cut every beat.
    Low energy  → cut every 2–4 beats.
    """
    sample_rate = 0.5

    def energy_at(t: float) -> float:
        idx = int(t / sample_rate)
        idx = max(0, min(idx, len(energy_curve) - 1))
        return energy_curve[idx]

    cut_points: List[float] = []
    last_cut = -1.0
    for bt in beat_times:
        e = energy_at(bt)
        # Tighter cuts for better "after effects" feel
        # Min gap: 0.35s (intense peak) to 1.8s (scenic)
        min_gap = 1.8 - (e * 1.45)   # 0.35s at e=1.0, 1.8s at e=0.0
        
        if bt - last_cut >= min_gap:
            cut_points.append(round(bt, 4))
            last_cut = bt

    return cut_points


# ── Convenience ────────────────────────────────────────────────────────────────

def get_energy_at(beatmap: BeatMap, time_s: float) -> float:
    """Look up instantaneous energy (0–1) at a given second."""
    idx = int(time_s / 0.5)
    idx = max(0, min(idx, len(beatmap.energy_curve) - 1))
    return beatmap.energy_curve[idx]


def get_section_label(beatmap: BeatMap, time_s: float) -> str:
    """Return the section label (e.g. 'peak') at a given second."""
    for sec in reversed(beatmap.sections):
        if time_s >= sec["start_s"]:
            return sec["label"]
    return "intro"
