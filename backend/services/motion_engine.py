"""
backend/services/motion_engine.py — Cinematic Motion Engine

Phase 2: Replaces the old static Ken Burns zoom with a full keyframe-based
motion system supporting dynamic zoom, directional pan, depth simulation,
and smooth easing curves.

Usage:
    from backend.services.motion_engine import MotionKeyframe, get_transform

    frame_out = get_transform(
        frame=bgr_array,
        t=0.35,            # normalised time 0→1 within this slide
        kf=keyframe,
        out_w=720,
        out_h=1280,
    )
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import cv2
import numpy as np

from backend.config.themes import MotionProfile


# ── Easing library ─────────────────────────────────────────────────────────────

def _ease_linear(t: float) -> float:
    return t

def _ease_in(t: float) -> float:
    return t * t

def _ease_out(t: float) -> float:
    u = 1.0 - t
    return 1.0 - u * u

def _ease_inout(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)

def _spring(t: float) -> float:
    """Slight overshoot spring — organic feel."""
    decay = math.exp(-5.0 * t)
    oscillation = math.cos(8.0 * t * math.pi)
    return 1.0 - decay * oscillation * 0.4

_EASING = {
    "linear":     _ease_linear,
    "ease_in":    _ease_in,
    "ease_out":   _ease_out,
    "ease_inout": _ease_inout,
    "spring":     _spring,
}

def apply_easing(t: float, fn_name: str) -> float:
    """Apply named easing function to normalised time t ∈ [0, 1]."""
    fn = _EASING.get(fn_name, _ease_inout)
    return float(fn(max(0.0, min(1.0, t))))


# ── Keyframe dataclass ─────────────────────────────────────────────────────────

@dataclass
class MotionKeyframe:
    """
    Pre-computed keyframe data for one photo/slide.
    Created once by build_keyframe(), reused every frame of that slide.
    """
    zoom_start: float        # scale at t=0
    zoom_end: float          # scale at t=1
    pan_x_start: float       # normalised X pan at t=0  (-1.0 → +1.0)
    pan_x_end: float         # normalised X pan at t=1
    pan_y_start: float       # normalised Y pan at t=0
    pan_y_end: float         # normalised Y pan at t=1
    easing: str              # easing function name


def build_keyframe(
    profile: MotionProfile,
    energy: float = 0.5,
    index: int = 0,
) -> MotionKeyframe:
    """
    Convert a MotionProfile into a concrete MotionKeyframe.

    Alternates pan direction per slide to avoid monotony.
    Energy (0–1) amplifies zoom range slightly.

    Args:
        profile:  MotionProfile from the theme (or overridden by TimelineBuilder).
        energy:   Audio energy at this slide's timestamp.
        index:    Slide index (used to alternate directions).
    """
    # Amplify zoom range by energy: high energy ↔ more zoom aggression
    energy_mult = 0.8 + energy * 0.4      # range 0.8 → 1.2
    zoom_range  = (profile.zoom_end - profile.zoom_start) * energy_mult
    zoom_start  = profile.zoom_start
    zoom_end    = zoom_start + max(0.005, zoom_range)

    # Alternate pan direction every slide
    sign_x = 1 if index % 2 == 0 else -1
    sign_y = 1 if (index // 2) % 2 == 0 else -1

    pan_x_mag = profile.pan_x * energy_mult
    pan_y_mag = profile.pan_y * energy_mult

    return MotionKeyframe(
        zoom_start   = round(zoom_start, 4),
        zoom_end     = round(zoom_end, 4),
        pan_x_start  = 0.0,
        pan_x_end    = round(sign_x * pan_x_mag, 4),
        pan_y_start  = 0.0,
        pan_y_end    = round(sign_y * pan_y_mag, 4),
        easing       = profile.easing,
    )


# ── Main frame transformer ─────────────────────────────────────────────────────

def get_transform(
    frame: np.ndarray,
    t: float,
    kf: MotionKeyframe,
    out_w: int,
    out_h: int,
) -> np.ndarray:
    """
    Apply zoom + pan motion to a single frame using the keyframe at time t.

    Args:
        frame:  Source BGR uint8 frame (already cropped to output aspect ratio).
        t:      Normalised time within the slide [0.0 → 1.0].
        kf:     MotionKeyframe for this slide.
        out_w:  Output width  (e.g. 720).
        out_h:  Output height (e.g. 1280).

    Returns:
        Transformed BGR uint8 frame at out_w × out_h.
    """
    te = apply_easing(t, kf.easing)

    # Interpolate zoom and pan
    zoom  = kf.zoom_start + (kf.zoom_end - kf.zoom_start) * te
    pan_x = kf.pan_x_start + (kf.pan_x_end - kf.pan_x_start) * te
    pan_y = kf.pan_y_start + (kf.pan_y_end - kf.pan_y_start) * te

    h, w = frame.shape[:2]

    # Compute the affine transform matrix
    # 1. Translate to centre
    # 2. Scale (zoom)
    # 3. Pan offset (as fraction of output dimensions)
    cx = w / 2.0
    cy = h / 2.0
    tx = cx + pan_x * out_w
    ty = cy + pan_y * out_h

    M = cv2.getRotationMatrix2D((cx, cy), 0.0, zoom)
    # Apply pan translation on top of the rotation/zoom matrix
    M[0, 2] += (tx - cx)
    M[1, 2] += (ty - cy)

    transformed = cv2.warpAffine(
        frame, M, (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )

    # Final resize/crop to exact output dimensions
    if (w, h) != (out_w, out_h):
        transformed = _cover_crop(transformed, out_w, out_h)

    return transformed


# ── Cover crop helper ─────────────────────────────────────────────────────────

def _cover_crop(frame: np.ndarray, out_w: int, out_h: int) -> np.ndarray:
    """
    Resize + center-crop frame to exactly out_w × out_h (CSS background-size: cover).
    """
    h, w = frame.shape[:2]
    target_ratio = out_w / out_h
    src_ratio    = w / h

    if src_ratio > target_ratio:
        # Image wider — scale by height
        scale_h = out_h / h
        new_w   = int(w * scale_h)
        resized = cv2.resize(frame, (new_w, out_h), interpolation=cv2.INTER_LINEAR)
        x0      = (new_w - out_w) // 2
        return resized[:, x0:x0 + out_w]
    else:
        # Image taller — scale by width
        scale_w = out_w / w
        new_h   = int(h * scale_w)
        resized = cv2.resize(frame, (out_w, new_h), interpolation=cv2.INTER_LINEAR)
        y0      = (new_h - out_h) // 2
        return resized[y0:y0 + out_h, :]
