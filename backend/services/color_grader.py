"""
backend/services/color_grader.py — Cinematic Color Grading Engine

Phase 3: Apply theme-defined color grading to each frame's NumPy array.

Operations (applied in order):
  1. Brightness adjustment          (linear scale on all channels)
  2. Contrast adjustment            (center-point contrast)
  3. Saturation adjustment          (HSV S-channel scale)
  4. Warm / cool tint               (per-channel RGB additive offset)
  5. Vignette overlay               (radial gradient darkening toward edges)

All operations are pure NumPy/OpenCV — 100% offline, no LUT files required.
"""

from __future__ import annotations

import cv2
import numpy as np

from backend.config.themes import ColorGrade


def apply_grade(frame: np.ndarray, grade: ColorGrade) -> np.ndarray:
    """
    Apply cinematic color grade to a single BGR frame (uint8, HxWx3).

    Args:
        frame:  NumPy array, dtype uint8, BGR colour order (OpenCV standard).
        grade:  ColorGrade settings from the active Theme.

    Returns:
        Graded frame, same shape and dtype.
    """
    out = frame.astype(np.float32)

    # ── 1. Brightness ─────────────────────────────────────────────────────────
    if grade.brightness != 1.0:
        out *= grade.brightness

    # ── 2. Contrast ───────────────────────────────────────────────────────────
    if grade.contrast != 1.0:
        # Centre-point contrast: scale around midpoint (128)
        out = (out - 128.0) * grade.contrast + 128.0

    # ── 3. Saturation ─────────────────────────────────────────────────────────
    if grade.saturation != 1.0:
        # Convert to HSV, scale S channel, convert back
        u8 = np.clip(out, 0, 255).astype(np.uint8)
        hsv = cv2.cvtColor(u8, cv2.COLOR_BGR2HSV).astype(np.float32)
        hsv[:, :, 1] = np.clip(hsv[:, :, 1] * grade.saturation, 0, 255)
        out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR).astype(np.float32)

    # ── 4. Warm / cool tint (RGB additive offset) ─────────────────────────────
    r_add, g_add, b_add = grade.warm_tint   # tuple is (R, G, B) — we store as BGR
    if r_add or g_add or b_add:
        # OpenCV stores as BGR
        out[:, :, 2] += r_add   # red channel
        out[:, :, 1] += g_add   # green channel
        out[:, :, 0] += b_add   # blue channel

    # Clamp before vignette
    out = np.clip(out, 0, 255)

    # ── 5. Vignette ───────────────────────────────────────────────────────────
    if grade.vignette > 0.0:
        out = _apply_vignette(out, grade.vignette)

    return np.clip(out, 0, 255).astype(np.uint8)


# ── Vignette generator (cached per resolution) ─────────────────────────────────

_vignette_cache: dict[tuple, np.ndarray] = {}


def _apply_vignette(frame: np.ndarray, strength: float) -> np.ndarray:
    """
    Darken corners with a smooth radial gradient vignette.

    Strength 0 = none, 1 = very heavy (edges almost black).
    """
    h, w = frame.shape[:2]
    cache_key = (h, w, round(strength, 3))

    if cache_key not in _vignette_cache:
        # Build normalised distance map from centre
        cx, cy = w / 2.0, h / 2.0
        y_coords = np.linspace(0, h - 1, h)
        x_coords = np.linspace(0, w - 1, w)
        xv, yv = np.meshgrid(x_coords, y_coords)
        dist = np.sqrt(((xv - cx) / cx) ** 2 + ((yv - cy) / cy) ** 2)
        # Smooth cosine falloff
        vignette = np.cos(np.clip(dist * 1.2, 0, 1) * np.pi / 2) ** 2
        # Apply strength — at strength=1 the corners reach 0
        vignette = 1.0 - (1.0 - vignette) * strength
        mask = np.stack([vignette, vignette, vignette], axis=2).astype(np.float32)
        _vignette_cache[cache_key] = mask

    mask = _vignette_cache[cache_key]
    return (frame * mask).astype(np.float32)


# ── Convenience: normalize exposure before grading ────────────────────────────

def normalize_exposure(frame: np.ndarray, target_mean: float = 128.0) -> np.ndarray:
    """
    Linearly scale frame brightness so its mean luminance meets target_mean.
    This counters over- or under-exposed photo inconsistencies before grading.

    Args:
        frame:        BGR uint8 frame.
        target_mean:  Desired mean luminance (default 128 for mid-tone).

    Returns:
        Exposure-normalized frame (uint8).
    """
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    mean = float(np.mean(gray))
    if mean < 5.0:
        return frame   # black frame — skip
    scale = target_mean / mean
    # Only correct if significant deviation (±20%)
    if 0.8 <= scale <= 1.25:
        return frame
    normalized = np.clip(frame.astype(np.float32) * scale, 0, 255).astype(np.uint8)
    return normalized
