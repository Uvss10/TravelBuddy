"""
backend/config/themes.py — Centralized Theme Configuration System

Each theme controls every visual and pacing parameter of the cinematic engine.
Themes are referenced by string name throughout the pipeline.

Available Themes:
  • cinematic    – Classic wide-angle drama, warm grade, slow contemplative cuts
  • energetic    – Fast beat-sync cuts, vivid colors, whip transitions
  • romantic     – Soft drift, warm pastel grade, gentle light leaks
  • documentary  – Neutral tones, static motion, cross-dissolve storytelling
  • adventure    – High-contrast, directional cuts, vigorous motion
"""

from dataclasses import dataclass, field
from typing import Tuple, List


# ── Motion profile ─────────────────────────────────────────────────────────────
@dataclass
class MotionProfile:
    """Pan/zoom motion settings per photo."""
    zoom_start: float        # starting scale factor  (e.g. 1.0)
    zoom_end: float          # ending scale factor    (e.g. 1.08)
    pan_x: float             # horizontal drift  -1.0 (left) → +1.0 (right), 0 = center
    pan_y: float             # vertical drift    -1.0 (up)   → +1.0 (down),  0 = center
    easing: str              # 'linear' | 'ease_in' | 'ease_out' | 'ease_inout' | 'spring'


# ── Color grade preset ─────────────────────────────────────────────────────────
@dataclass
class ColorGrade:
    """
    Simple LUT-style color grade applied per-frame via NumPy/OpenCV.
    All values are additive offsets or scale multipliers applied in HSV / RGB.
    """
    brightness: float        # multiplicative  (1.0 = no change, 1.1 = 10% brighter)
    contrast: float          # multiplicative centre-point contrast (1.0 = unchanged)
    saturation: float        # HSV S-channel scale (1.0 = no change, 1.3 = +30%)
    warm_tint: Tuple[int, int, int]   # RGB additive tint (R, G, B additive offsets)
    vignette: float          # 0.0 = none, 1.0 = strong vignette


# ── Text / caption style ───────────────────────────────────────────────────────
@dataclass
class TextStyle:
    font_size_ratio: float   # fraction of video width (e.g. 0.045 → ~32px on 720p)
    font_weight: str         # 'bold' | 'semibold' | 'light'
    color: str               # hex color string  '#ffffff'
    shadow: bool
    animation: str           # 'fade_up' | 'fade_in' | 'scale_in' | 'none'
    position: str            # 'bottom' | 'center' | 'top'


# ── Full theme ─────────────────────────────────────────────────────────────────
@dataclass
class Theme:
    name: str
    display_name: str
    description: str

    # Pacing
    cut_frequency: str       # 'slow' | 'medium' | 'fast'  used by timeline builder
    beat_sensitivity: float  # 0–1, how aggressively cuts align to audio beats

    # Motion
    motion_intensity: float  # 0–1, overall how strong the motion effects are
    motion_profile: MotionProfile

    # Transitions
    transition_pool: List[str]  # ordered priority list: first choice first
    # Available transitions: 'cross_dissolve' | 'zoom_in' | 'zoom_out' | 'directional_blur'
    #                        | 'whip_left' | 'whip_right' | 'light_leak' | 'dip_black'

    # Color
    color_grade: ColorGrade

    # Captions
    text_style: TextStyle


# ── Theme registry ─────────────────────────────────────────────────────────────

THEMES: dict[str, Theme] = {

    "cinematic": Theme(
        name="cinematic",
        display_name="Cinematic",
        description="Classic wide-angle drama. Warm palette, slow contemplative cuts.",
        cut_frequency="slow",
        beat_sensitivity=0.4,
        motion_intensity=0.5,
        motion_profile=MotionProfile(
            zoom_start=1.04, zoom_end=1.12,
            pan_x=0.03, pan_y=0.01,
            easing="ease_inout",
        ),
        transition_pool=["cross_dissolve", "dip_black", "zoom_in", "flash_white", "zoom_blur"],
        color_grade=ColorGrade(
            brightness=1.05, contrast=1.10,
            saturation=0.90,
            warm_tint=(12, 4, -8),
            vignette=0.45,
        ),
        text_style=TextStyle(
            font_size_ratio=0.042, font_weight="bold",
            color="#f5f0e8", shadow=True,
            animation="fade_up", position="bottom",
        ),
    ),

    "energetic": Theme(
        name="energetic",
        display_name="Energetic",
        description="Fast beat-sync cuts, vivid hues, whip transitions.",
        cut_frequency="fast",
        beat_sensitivity=0.9,
        motion_intensity=0.85,
        motion_profile=MotionProfile(
            zoom_start=1.04, zoom_end=1.18,
            pan_x=0.05, pan_y=0.03,
            easing="ease_in",
        ),
        transition_pool=["whip_left", "whip_right", "glitch", "flash_white", "zoom_in", "zoom_blur"],
        color_grade=ColorGrade(
            brightness=1.08, contrast=1.20,
            saturation=1.35,
            warm_tint=(5, 0, 0),
            vignette=0.20,
        ),
        text_style=TextStyle(
            font_size_ratio=0.050, font_weight="bold",
            color="#ffffff", shadow=True,
            animation="scale_in", position="center",
        ),
    ),

    "romantic": Theme(
        name="romantic",
        display_name="Romantic",
        description="Soft drift, warm pastel grade, gentle light leaks.",
        cut_frequency="slow",
        beat_sensitivity=0.3,
        motion_intensity=0.35,
        motion_profile=MotionProfile(
            zoom_start=1.04, zoom_end=1.10,
            pan_x=0.02, pan_y=0.01,
            easing="ease_out",
        ),
        transition_pool=["light_leak", "cross_dissolve", "dip_black"],
        color_grade=ColorGrade(
            brightness=1.10, contrast=0.95,
            saturation=0.85,
            warm_tint=(20, 8, -5),
            vignette=0.55,
        ),
        text_style=TextStyle(
            font_size_ratio=0.040, font_weight="light",
            color="#ffe8d6", shadow=True,
            animation="fade_in", position="bottom",
        ),
    ),

    "documentary": Theme(
        name="documentary",
        display_name="Documentary",
        description="Neutral grading, minimal motion, cross-dissolve storytelling.",
        cut_frequency="medium",
        beat_sensitivity=0.5,
        motion_intensity=0.20,
        motion_profile=MotionProfile(
            zoom_start=1.04, zoom_end=1.08,
            pan_x=0.01, pan_y=0.0,
            easing="linear",
        ),
        transition_pool=["cross_dissolve", "dip_black"],
        color_grade=ColorGrade(
            brightness=1.00, contrast=1.05,
            saturation=0.80,
            warm_tint=(0, 0, 0),
            vignette=0.25,
        ),
        text_style=TextStyle(
            font_size_ratio=0.038, font_weight="semibold",
            color="#e0e0e0", shadow=False,
            animation="fade_in", position="bottom",
        ),
    ),

    "adventure": Theme(
        name="adventure",
        display_name="Adventure",
        description="High contrast, punchy cuts, directional energy.",
        cut_frequency="fast",
        beat_sensitivity=0.8,
        motion_intensity=0.75,
        motion_profile=MotionProfile(
            zoom_start=1.04, zoom_end=1.16,
            pan_x=0.05, pan_y=0.02,
            easing="spring",
        ),
        transition_pool=["glitch", "directional_blur", "zoom_out", "whip_right", "zoom_blur", "cross_dissolve"],
        color_grade=ColorGrade(
            brightness=1.03, contrast=1.30,
            saturation=1.20,
            warm_tint=(-5, 2, 8),
            vignette=0.30,
        ),
        text_style=TextStyle(
            font_size_ratio=0.048, font_weight="bold",
            color="#ffffff", shadow=True,
            animation="scale_in", position="bottom",
        ),
    ),
}


def get_theme(name: str) -> Theme:
    """Return a Theme object by name. Falls back to 'cinematic' if unknown."""
    return THEMES.get(name.lower(), THEMES["cinematic"])


def list_themes() -> list[dict]:
    """Return a list of {name, display_name, description} dicts for API responses."""
    return [
        {"name": t.name, "display_name": t.display_name, "description": t.description}
        for t in THEMES.values()
    ]
