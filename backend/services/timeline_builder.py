"""
backend/services/timeline_builder.py — Structured Cinematic Timeline Builder

Phase 1 (cont.) of the cinematic upgrade. Takes sorted photos + a BeatMap
and produces a per-photo TimelineSlot list — the master edit decision list (EDL).

Each TimelineSlot specifies:
  • Which photo to show
  • Exact start/end time in the final video
  • Transition type (to next slide)
  • Motion profile overrides (zoom direction, pan vector, easing)
  • Caption text
  • Section label (intro / exploration / peak / scenic / outro)

The timeline respects the 5-section cinematic template:

  0–5s    intro      → 1 or 2 photos, slow build
  5–20s   exploration→ sweep of landscapes, medium pace
  20–40s  peak       → fastest cuts, beat-locked
  40–55s  scenic     → emotional slow-down
  55–60s  outro      → final photo + title hold
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import List, Optional

from backend.config.themes          import Theme, MotionProfile, get_theme
from backend.services.audio_analyzer import BeatMap, get_energy_at, get_section_label
from backend.services.media_intelligence import PhotoMeta


# ── Timeline slot ──────────────────────────────────────────────────────────────

@dataclass
class TimelineSlot:
    """One photo's worth of instructions in the final video."""
    index: int               # position in the video (0-based)
    photo: PhotoMeta
    start_s: float           # when this slide begins
    end_s: float             # when this slide ends
    duration_s: float        # = end_s - start_s
    section: str             # 'intro' | 'exploration' | 'peak' | 'scenic' | 'outro'
    transition_out: str      # transition applied at the END of this slide
    motion: MotionProfile    # cinematic motion for this slide
    caption: str             # text caption or AI caption
    energy: float            # 0–1 energy level at this moment
    is_beat_locked: bool     # True if this cut falls on a detected beat


# ── Section time templates ─────────────────────────────────────────────────────

def get_section_boundaries(duration_s: float):
    """Calculate section start/end times based on the requested video duration."""
    # Scale based on standard 60s template ratios
    r_intro = 5.0 / 60.0
    r_expl  = 15.0 / 60.0
    r_peak  = 20.0 / 60.0
    r_scenic = 15.0 / 60.0
    r_outro  = 5.0 / 60.0
    
    t0 = 0.0
    t1 = round(duration_s * r_intro, 1)
    t2 = round(t1 + duration_s * r_expl, 1)
    t3 = round(t2 + duration_s * r_peak, 1)
    t4 = round(t3 + duration_s * r_scenic, 1)
    t5 = duration_s

    return [
        ("intro",       t0,  t1),
        ("exploration", t1,  t2),
        ("peak",        t2,  t3),
        ("scenic",      t3,  t4),
        ("outro",       t4,  t5),
    ]

# How many photos go into each section (ratios, not absolutes)
SECTION_PHOTO_WEIGHT = {
    "intro":       0.07,   # ≈ 1 photo for 10–15 photos total
    "exploration": 0.25,
    "peak":        0.35,
    "scenic":      0.20,
    "outro":       0.13,
}


# ── Easing functions ───────────────────────────────────────────────────────────

def _ease_inout(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)

def _ease_in(t: float) -> float:
    return t * t

def _ease_out(t: float) -> float:
    return 1.0 - (1.0 - t) ** 2

def _spring(t: float) -> float:
    """Overshoot spring — peaks above 1.0 then settles."""
    return 1.0 - math.exp(-6.0 * t) * math.cos(10.0 * t)


EASING_FN = {
    "linear":    lambda t: t,
    "ease_in":   _ease_in,
    "ease_out":  _ease_out,
    "ease_inout": _ease_inout,
    "spring":    _spring,
}


# ── Motion override builder ────────────────────────────────────────────────────

_PAN_DIRECTIONS = [
    (0.03,  0.0),   # pan right
    (-0.03, 0.0),   # pan left
    (0.0,   0.02),  # tilt down
    (0.0,  -0.02),  # tilt up
    (0.02,  0.015), # diagonal drift
]


def _build_motion(
    base: MotionProfile,
    section: str,
    energy: float,
    index: int,
    intensity: float,
) -> MotionProfile:
    """
    Override the base theme motion profile per-slide based on section + energy.
    Alternates pan direction to avoid repetition.
    """
    # Scale zoom range by energy and intensity
    zoom_range = (base.zoom_end - base.zoom_start) * (0.5 + energy * 0.5) * intensity
    zoom_start = base.zoom_start
    zoom_end   = zoom_start + max(0.01, zoom_range)

    # Alternate pan direction
    pan_x, pan_y = _PAN_DIRECTIONS[index % len(_PAN_DIRECTIONS)]
    pan_x *= intensity
    pan_y *= intensity

    # Section-specific overrides
    if section == "intro":
        easing = "ease_out"
        zoom_end = zoom_start + 0.03  # very subtle intro
    elif section == "peak":
        easing = "ease_in"
        zoom_end = min(1.15, zoom_start + zoom_range * 1.2)  # aggressive zoom
    elif section == "outro":
        easing = "ease_out"
        zoom_end = zoom_start + 0.02  # gentle resolution
        pan_x, pan_y = 0.0, 0.0
    else:
        easing = base.easing

    return MotionProfile(
        zoom_start=round(zoom_start, 4),
        zoom_end=round(zoom_end, 4),
        pan_x=round(pan_x, 4),
        pan_y=round(pan_y, 4),
        easing=easing,
    )


# ── Transition picker ──────────────────────────────────────────────────────────

def _pick_transition(
    transition_pool: List[str],
    section: str,
    energy: float,
    prev_transition: str,
) -> str:
    """
    Pick a transition that:
    - Matches section energy
    - Avoids repeating the same transition twice in a row
    """
    pool = [t for t in transition_pool if t != prev_transition]
    if not pool:
        pool = transition_pool

    # In outro — always dip to black for finality
    if section == "outro":
        return "dip_black"

    # High energy → prefer whip/directional
    if energy > 0.75:
        energetic = [t for t in pool if "whip" in t or "directional" in t or "zoom" in t]
        if energetic:
            return energetic[0]

    # Low energy → prefer dissolve / light_leak
    if energy < 0.35:
        gentle = [t for t in pool if "dissolve" in t or "light_leak" in t]
        if gentle:
            return gentle[0]

    return pool[0]


# ── Main timeline builder ─────────────────────────────────────────────────────

def build_timeline(
    photos: List[PhotoMeta],
    beatmap: BeatMap,
    theme: Theme,
    captions: Optional[List[str]] = None,
) -> List[TimelineSlot]:
    """
    Produce a list of TimelineSlot objects — the master cinematic edit plan.
    """
    if not photos:
        return []

    n_original = len(photos)
    captions = captions or []
    total_duration = beatmap.duration_s

    # ── 1. Smart Sampling: Don't use all 50 photos if it makes the reel too "busy"
    # Target: 2.5s to 4s per photo for a cinematic look.
    # 60s @ 3s/photo = 20 photos.
    # 120s @ 3s/photo = 40 photos.
    target_photo_count = max(5, int(total_duration / 2.8)) # e.g. 21 photos for 60s
    
    if n_original > target_photo_count:
        # We have too many photos. Step through the sorted (high quality) list 
        # but take a subset to maintain variety and story flow.
        step = n_original / target_photo_count
        sampled_photos = [photos[int(i * step)] for i in range(target_photo_count)]
        print(f"[Timeline] Sampled {target_photo_count} photos from {n_original} for a cleaner {total_duration}s edit.")
    else:
        sampled_photos = photos

    n = len(sampled_photos)
    
    # ── 2. Distribute photos across sections ─────────────────────────────────
    section_allocations = _distribute_photos(n)
    boundaries = get_section_boundaries(total_duration)

    # ── 3. Assign cut times using beat_map cut_points ────────────────────────
    slots: List[TimelineSlot] = []
    photo_queue = list(sampled_photos)
    prev_transition = "cross_dissolve"

    for sec_label, sec_start, sec_end in boundaries:
        sec_count = section_allocations.get(sec_label, 0)
        if sec_count == 0 or not photo_queue:
            continue

        # Available beat cut_points in this section window
        section_cuts = [
            cp for cp in beatmap.cut_points
            if sec_start <= cp < sec_end
        ]
        # Generate evenly spaced fallback if not enough beats
        sec_duration = sec_end - sec_start
        if len(section_cuts) < sec_count:
            step = sec_duration / sec_count
            section_cuts = [sec_start + step * i for i in range(sec_count)]

        # Pick sec_count evenly distributed cut_points from section
        cut_times = _sample_cut_times(section_cuts, sec_count, sec_start, sec_end)

        # Build a slot per photo in this section
        for i, cut_start in enumerate(cut_times):
            if not photo_queue:
                break
            photo = photo_queue.pop(0)
            cut_end = cut_times[i + 1] if i + 1 < len(cut_times) else sec_end
            cut_end = min(cut_end, sec_end)
            duration = max(0.5, cut_end - cut_start)

            energy = get_energy_at(beatmap, cut_start)
            motion = _build_motion(
                base=theme.motion_profile,
                section=sec_label,
                energy=energy,
                index=len(slots),
                intensity=theme.motion_intensity,
            )
            transition = _pick_transition(
                transition_pool=theme.transition_pool,
                section=sec_label,
                energy=energy,
                prev_transition=prev_transition,
            )
            caption = captions[len(slots)] if len(slots) < len(captions) else ""
            is_beat = any(abs(cut_start - bt) < 0.07 for bt in beatmap.beat_times)

            slots.append(TimelineSlot(
                index=len(slots),
                photo=photo,
                start_s=round(cut_start, 3),
                end_s=round(cut_end, 3),
                duration_s=round(duration, 3),
                section=sec_label,
                transition_out=transition,
                motion=motion,
                caption=caption,
                energy=round(energy, 4),
                is_beat_locked=is_beat,
            ))
            prev_transition = transition

    # Ensure last slot ends exactly at total_duration
    if slots:
        last = slots[-1]
        slots[-1] = TimelineSlot(
            index=last.index,
            photo=last.photo,
            start_s=last.start_s,
            end_s=total_duration,
            duration_s=round(total_duration - last.start_s, 3),
            section=last.section,
            transition_out="dip_black",
            motion=last.motion,
            caption=last.caption,
            energy=last.energy,
            is_beat_locked=last.is_beat_locked,
        )

    return slots


# ── Helper: distribute photo count across sections ────────────────────────────

def _distribute_photos(n: int) -> dict:
    """
    Divide n photos across the 5 sections using SECTION_PHOTO_WEIGHT.
    Ensures every section gets at least 1 photo if n >= 5.
    """
    raw = {
        label: max(1, round(n * weight))
        for label, weight in SECTION_PHOTO_WEIGHT.items()
    }
    # Clamp total to n
    total = sum(raw.values())
    diff = total - n
    # Trim excess from the largest section
    if diff > 0:
        biggest = max(raw, key=raw.__getitem__)
        raw[biggest] = max(1, raw[biggest] - diff)
    elif diff < 0:
        # Add shortage to exploration (longest section)
        raw["exploration"] += abs(diff)
    return raw


def _sample_cut_times(
    cuts: List[float],
    n: int,
    start: float,
    end: float,
) -> List[float]:
    """
    Select n evenly-spaced cut times from available cuts list.
    Guarantees first cut starts at section start.
    """
    if len(cuts) <= n:
        result = sorted(cuts)
    else:
        step = len(cuts) / n
        result = [cuts[int(i * step)] for i in range(n)]

    # Always start at section boundary
    if result and result[0] > start + 0.2:
        result[0] = start

    return sorted(result)
