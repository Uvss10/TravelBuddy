"""
backend/services/transition_composer.py — Cinematic Transition Composer

Phase 3: Replaces simple cross-fade with a theme-based transition library.

Supported transitions:
  • cross_dissolve    — Classic alpha blend (baseline)
  • zoom_in           — Next slide zooms in from center
  • zoom_out          — Current slide zooms out while next fades in
  • directional_blur  — Motion-blur smear in pan direction
  • whip_left         — Horizontal smear + fast slide to left
  • whip_right        — Horizontal smear + fast slide to right
  • light_leak        — White bloom flash between slides (romantic)
  • dip_black         — Fade current → black → fade in next (outro)

Each transition function signature:
    frame = transition_fn(
        frame_a,        # current slide BGR frame
        frame_b,        # next slide BGR frame
        t,              # 0.0 → 1.0 (transition progress)
        w, h,           # output dimensions
    ) -> np.ndarray
"""

from __future__ import annotations

import math
import random
import cv2
import numpy as np
from typing import Callable


# ── Type alias ────────────────────────────────────────────────────────────────
TransitionFn = Callable[[np.ndarray, np.ndarray, float, int, int], np.ndarray]


# ── Helper utilities ──────────────────────────────────────────────────────────

def _blend(a: np.ndarray, b: np.ndarray, alpha: float) -> np.ndarray:
    """Linear blend: (1-alpha)*a + alpha*b, clipped to uint8."""
    return np.clip(
        a.astype(np.float32) * (1.0 - alpha) + b.astype(np.float32) * alpha,
        0, 255
    ).astype(np.uint8)


def _motion_blur_h(frame: np.ndarray, strength: int) -> np.ndarray:
    """Apply horizontal motion blur (ksize must be odd)."""
    k = max(3, strength | 1)   # force odd
    kernel = np.zeros((k, k), dtype=np.float32)
    kernel[k // 2, :] = 1.0 / k
    return cv2.filter2D(frame, -1, kernel)


def _motion_blur_v(frame: np.ndarray, strength: int) -> np.ndarray:
    """Apply vertical motion blur."""
    k = max(3, strength | 1)
    kernel = np.zeros((k, k), dtype=np.float32)
    kernel[:, k // 2] = 1.0 / k
    return cv2.filter2D(frame, -1, kernel)


def _ease_inout(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)

def _ease_out(t: float) -> float:
    return 1.0 - (1.0 - t) ** 2


# ── Transition implementations ─────────────────────────────────────────────────

def _cross_dissolve(a, b, t, w, h) -> np.ndarray:
    return _blend(a, b, _ease_inout(t))


def _zoom_in(a, b, t, w, h) -> np.ndarray:
    """Next slide zooms in from 110% → 100% while current fades."""
    te = _ease_inout(t)
    # Grow the 'b' frame from oversized to normal
    scale = 1.10 - 0.10 * te
    scaled_b = _scale_center(b, scale, w, h)
    return _blend(a, scaled_b, te)


def _zoom_out(a, b, t, w, h) -> np.ndarray:
    """Current slide shrinks away while next fades up."""
    te = _ease_inout(t)
    scale = 1.0 - 0.12 * te
    scaled_a = _scale_center(a, scale, w, h)
    return _blend(scaled_a, b, te)


def _directional_blur(a, b, t, w, h) -> np.ndarray:
    """Horizontal blur intensifies then resolves into next slide."""
    te = _ease_inout(t)
    # Blur peaks at mid-transition
    blur_intensity = int(min(t, 1 - t) * 2 * 45)  # 0 → 45 → 0
    if blur_intensity > 0:
        blurred_a = _motion_blur_h(a, blur_intensity)
        blurred_b = _motion_blur_h(b, blur_intensity)
        return _blend(blurred_a, blurred_b, te)
    return _blend(a, b, te)


def _whip_left(a, b, t, w, h) -> np.ndarray:
    """Fast horizontal slide-out to left with motion blur."""
    te = _ease_out(t)
    offset = int(te * w)
    blur_k = max(3, int(min(t, 1 - t) * 2 * 60) | 1)
    blurred_a = _motion_blur_h(a, blur_k) if blur_k > 3 else a
    blurred_b = _motion_blur_h(b, blur_k) if blur_k > 3 else b

    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    # Slide a out to the left
    a_left  = w - offset
    if a_left > 0:
        canvas[:, :a_left] = blurred_a[:, offset:]
    # Slide b in from the right
    b_right = offset
    if b_right > 0:
        canvas[:, w - b_right:] = blurred_b[:, :b_right]
    return canvas


def _whip_right(a, b, t, w, h) -> np.ndarray:
    """Fast horizontal slide-out to right with motion blur."""
    te = _ease_out(t)
    offset = int(te * w)
    blur_k = max(3, int(min(t, 1 - t) * 2 * 60) | 1)
    blurred_a = _motion_blur_h(a, blur_k) if blur_k > 3 else a
    blurred_b = _motion_blur_h(b, blur_k) if blur_k > 3 else b

    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    a_right = w - offset
    if a_right > 0:
        canvas[:, offset:] = blurred_a[:, :a_right]
    b_left = offset
    if b_left > 0:
        canvas[:, :b_left] = blurred_b[:, w - b_left:]
    return canvas


def _light_leak(a, b, t, w, h) -> np.ndarray:
    """
    Romantic light-leak: bloom to warm white at t=0.5, then resolve to b.
    """
    te = _ease_inout(t)
    # Build a warm white bloom that peaks at t=0.5
    bloom_intensity = math.sin(te * math.pi)   # 0 → 1 → 0
    # Warm tint: slight yellow-white (BGR: 210, 235, 255)
    bloom = np.full((h, w, 3), [210, 235, 255], dtype=np.float32) * bloom_intensity * 0.6

    # First half: a → bloom; second half: bloom → b
    if te < 0.5:
        base = _blend(a, np.clip(bloom, 0, 255).astype(np.uint8), te * 2)
    else:
        base = _blend(np.clip(bloom, 0, 255).astype(np.uint8), b, (te - 0.5) * 2)
    return base


def _dip_black(a, b, t, w, h) -> np.ndarray:
    """Fade current to black, then fade up to next. Elegant outro."""
    black = np.zeros((h, w, 3), dtype=np.uint8)
    te = _ease_inout(t)
    if te < 0.5:
        return _blend(a, black, te * 2)
    else:
        return _blend(black, b, (te - 0.5) * 2)


def _glitch(a, b, t, w, h) -> np.ndarray:
    """Cyberpunk glitch: random channel shifts and horizontal slicing."""
    te = _ease_inout(t)
    if te < 0.1 or te > 0.9:
        return a if te < 0.1 else b
    
    # Peak glitch at middle
    intensity = math.sin(te * math.pi)
    
    # Random slice offset
    shift = int(intensity * 30 * random.uniform(-1, 1))
    
    # Create glitch frame
    glitched = _blend(a, b, te)
    if random.random() > 0.7:
        # Shift channels
        rows, cols, _ = glitched.shape
        glitched[:, :, 0] = np.roll(glitched[:, :, 0], shift, axis=1)
        glitched[:, :, 1] = np.roll(glitched[:, :, 1], -shift, axis=1)
        
    return glitched


def _flash_white(a, b, t, w, h) -> np.ndarray:
    """Bright white flash transition."""
    te = _ease_inout(t)
    white = np.full((h, w, 3), 255, dtype=np.uint8)
    if te < 0.5:
        return _blend(a, white, te * 2)
    else:
        return _blend(white, b, (te - 0.5) * 2)


def _zoom_blur(a, b, t, w, h) -> np.ndarray:
    """Radial zoom blur that expands from center and resolves to next slide."""
    te = _ease_inout(t)
    # Radial blur effect via multi-scale blending
    canvas = _blend(a, b, te)
    
    # Peak intensity at t=0.5
    intensity = math.sin(te * math.pi)
    if intensity < 0.1:
        return canvas
        
    # Approximate zoom blur with 3 layers of scaling
    blended = canvas.astype(np.float32)
    scales = [1.02, 1.05, 1.10]
    for s in scales:
        s_val = 1.0 + (s - 1.0) * intensity
        scaled = _scale_center(canvas, s_val, w, h)
        blended += scaled.astype(np.float32)
    
    return (blended / (len(scales) + 1)).astype(np.uint8)



# ── Scale center helper ────────────────────────────────────────────────────────

def _scale_center(frame: np.ndarray, scale: float, out_w: int, out_h: int) -> np.ndarray:
    """Scale a frame about its center, then crop back to out_w × out_h."""
    h, w = frame.shape[:2]
    new_w = int(w * scale)
    new_h = int(h * scale)
    resized = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    # Center crop
    x0 = max(0, (new_w - out_w) // 2)
    y0 = max(0, (new_h - out_h) // 2)
    cropped = resized[y0:y0 + out_h, x0:x0 + out_w]
    # Pad if undersized
    if cropped.shape[0] < out_h or cropped.shape[1] < out_w:
        pad = np.zeros((out_h, out_w, 3), dtype=np.uint8)
        ph = min(cropped.shape[0], out_h)
        pw = min(cropped.shape[1], out_w)
        pad[:ph, :pw] = cropped[:ph, :pw]
        return pad
    return cropped


# ── Registry ──────────────────────────────────────────────────────────────────

_TRANSITIONS: dict[str, TransitionFn] = {
    "cross_dissolve":    _cross_dissolve,
    "zoom_in":           _zoom_in,
    "zoom_out":          _zoom_out,
    "directional_blur":  _directional_blur,
    "whip_left":         _whip_left,
    "whip_right":        _whip_right,
    "light_leak":        _light_leak,
    "dip_black":         _dip_black,
    "glitch":            _glitch,
    "flash_white":       _flash_white,
    "zoom_blur":         _zoom_blur,
}


def get_transition(name: str) -> TransitionFn:
    """Return a transition function by name. Defaults to cross_dissolve."""
    return _TRANSITIONS.get(name, _cross_dissolve)


def apply_transition(
    frame_a: np.ndarray,
    frame_b: np.ndarray,
    t: float,
    w: int,
    h: int,
    name: str = "cross_dissolve",
) -> np.ndarray:
    """
    Blend frame_a → frame_b at normalised progress t using the named transition.

    Args:
        frame_a:  Current slide frame (BGR uint8).
        frame_b:  Next slide frame (BGR uint8).
        t:        Transition progress 0.0 (start) → 1.0 (end).
        w, h:     Output dimensions.
        name:     Transition name string.

    Returns:
        Blended frame (BGR uint8).
    """
    fn = get_transition(name)
    return fn(frame_a, frame_b, max(0.0, min(1.0, t)), w, h)
