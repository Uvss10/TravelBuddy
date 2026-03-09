"""
backend/services/caption_renderer.py — Lyric / Caption Synchronization System

Phase 4: Animated caption / lyric overlays drawn directly onto video frames.

Supports two caption modes:
  A. Timeline captions   — one caption string per TimelineSlot (from user or AI).
  B. LRC lyric file      — parses .lrc timestamped lyric format and syncs to video.

Text animations:
  • fade_up    — text fades in while moving upward (cinema title style)
  • fade_in    — simple alpha fade in
  • scale_in   — text scales from 80% to 100% while fading in
  • none       — instant display

Rendering:
  All caption rendering is pure Pillow (PIL) — no ImageMagick / fonttools / LaTeX.
  Falls back gracefully to OpenCV putText if Pillow is not installed.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from typing import List, Optional

import numpy as np
import cv2

from backend.config.themes import TextStyle


# ── LRC parser ────────────────────────────────────────────────────────────────

@dataclass
class LyricLine:
    """One timestamped lyric line."""
    time_s: float
    text: str


def parse_lrc(lrc_content: str) -> List[LyricLine]:
    """
    Parse .lrc lyric file content into a list of LyricLine objects.

    LRC format:
        [mm:ss.xx]lyric text
        [01:23.45]Here comes the sun
    """
    lines: List[LyricLine] = []
    pattern = re.compile(r'\[(\d+):(\d+\.\d+)\](.*)')

    for raw_line in lrc_content.splitlines():
        m = pattern.match(raw_line.strip())
        if m:
            minutes = int(m.group(1))
            seconds = float(m.group(2))
            text    = m.group(3).strip()
            if text:   # skip empty lyric lines
                lines.append(LyricLine(
                    time_s=minutes * 60.0 + seconds,
                    text=text,
                ))

    return sorted(lines, key=lambda l: l.time_s)


def get_lyric_at(lyrics: List[LyricLine], time_s: float) -> Optional[str]:
    """Return the lyric line active at time_s (most recent line whose time ≤ time_s)."""
    active = None
    for line in lyrics:
        if line.time_s <= time_s:
            active = line.text
        else:
            break
    return active


# ── Animation helpers ─────────────────────────────────────────────────────────

def _easing_fade(t: float) -> float:
    """Smooth ease-in alpha for first 30% of slide duration."""
    t_clamped = min(t / 0.30, 1.0)
    return t_clamped * t_clamped * (3.0 - 2.0 * t_clamped)


def _animation_params(
    animation: str,
    t: float,
    base_y: int,
    font_h: int,
) -> tuple[float, int]:
    """
    Returns (alpha, y_offset) based on animation type and normalised time t.

    Args:
        animation:  'fade_up' | 'fade_in' | 'scale_in' | 'none'
        t:          Normalised time within slide [0→1]
        base_y:     Target Y position in pixels
        font_h:     Approximate font height in pixels

    Returns:
        (alpha 0–1, y_offset relative to base_y)
    """
    if animation == "none":
        return 1.0, 0

    alpha = _easing_fade(t)

    if animation == "fade_up":
        # Drift up by ~16px over first 30% of slide
        drift = int((1.0 - _easing_fade(t)) * 16)
        return alpha, drift

    if animation == "scale_in":
        # No position change, alpha fades in
        return alpha, 0

    # fade_in (default)
    return alpha, 0


# ── Pillow renderer ────────────────────────────────────────────────────────────

def _render_pillow(
    frame: np.ndarray,
    text: str,
    style: TextStyle,
    alpha: float,
    y_offset: int,
    w: int,
    h: int,
) -> np.ndarray:
    """Render caption using Pillow for high-quality antialiased text."""
    from PIL import Image, ImageDraw, ImageFont

    # Convert BGR -> RGBA
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    pil_img   = Image.fromarray(frame_rgb).convert("RGBA")
    overlay   = Image.new("RGBA", pil_img.size, (0, 0, 0, 0))
    draw      = ImageDraw.Draw(overlay)

    # Font size in pixels
    font_px = max(20, int(w * style.font_size_ratio))

    # Try to load system font, fall back to default
    font = None
    try:
        font_name = {
            "bold":     "arialbd.ttf",
            "semibold": "arial.ttf",
            "light":    "arial.ttf",
        }.get(style.font_weight, "arial.ttf")
        font = ImageFont.truetype(font_name, font_px)
    except Exception:
        try:
            font = ImageFont.truetype("DejaVuSans-Bold.ttf", font_px)
        except Exception:
            font = ImageFont.load_default()

    # Word-wrap text
    max_width = int(w * 0.80)
    lines     = _wrap_text(draw, text, font, max_width)
    line_gap  = int(font_px * 1.4)
    total_h   = len(lines) * line_gap

    # Position — always bottom-third for story captions
    if style.position == "center":
        y_start = (h - total_h) // 2 + y_offset
    elif style.position == "top":
        y_start = int(h * 0.08) + y_offset
    else:  # bottom (default)
        y_start = h - int(h * 0.14) - total_h + y_offset

    # ── Solid black pill background ──────────────────────────────────────────
    # Padding around the text block
    pad_x = int(font_px * 0.9)
    pad_y = int(font_px * 0.45)
    box_w = max_width + pad_x * 2
    box_h = total_h + pad_y * 2
    box_x = (w - box_w) // 2
    box_y = y_start - pad_y
    r     = int(font_px * 0.45)   # corner radius

    # Draw rounded-rect background (85% opacity black)
    bg_alpha = int(215 * alpha)   # 0–255, scaled by caption animation alpha
    draw.rounded_rectangle(
        [box_x, box_y, box_x + box_w, box_y + box_h],
        radius=r,
        fill=(0, 0, 0, bg_alpha),
    )

    # Parse text color
    try:
        hex_c      = style.color.lstrip('#')
        r_c, g_c, b_c = int(hex_c[0:2], 16), int(hex_c[2:4], 16), int(hex_c[4:6], 16)
        text_color = (r_c, g_c, b_c, int(alpha * 255))
    except Exception:
        text_color = (255, 255, 255, int(alpha * 255))

    # ── Thin shadow stroke (1 px offset for crispness on white text) ─────────
    shadow_color = (0, 0, 0, int(alpha * 160))
    for i, line in enumerate(lines):
        bbox   = draw.textbbox((0, 0), line, font=font)
        line_w = bbox[2] - bbox[0]
        x      = (w - line_w) // 2
        y      = y_start + i * line_gap
        for dx, dy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
            draw.text((x + dx, y + dy), line, font=font, fill=shadow_color)

    # ── Main text ─────────────────────────────────────────────────────────────
    for i, line in enumerate(lines):
        bbox   = draw.textbbox((0, 0), line, font=font)
        line_w = bbox[2] - bbox[0]
        x      = (w - line_w) // 2
        y      = y_start + i * line_gap
        draw.text((x, y), line, font=font, fill=text_color)

    # Composite overlay onto frame
    pil_img = Image.alpha_composite(pil_img, overlay)
    result  = np.array(pil_img.convert("RGB"))
    return cv2.cvtColor(result, cv2.COLOR_RGB2BGR)


def _wrap_text(draw, text: str, font, max_w: int) -> List[str]:
    """Break text into lines that fit within max_w pixels."""
    words = text.split()
    lines: List[str] = []
    current = ""
    for word in words:
        test = f"{current} {word}".strip() if current else word
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] > max_w and current:
            lines.append(current)
            current = word
        else:
            current = test
    if current:
        lines.append(current)
    return lines


# ── OpenCV fallback renderer ──────────────────────────────────────────────────

def _render_opencv(
    frame: np.ndarray,
    text: str,
    style: TextStyle,
    alpha: float,
    y_offset: int,
    w: int,
    h: int,
) -> np.ndarray:
    """Simple OpenCV text fallback if Pillow is not installed."""
    overlay = frame.copy()
    font_scale = max(0.5, w * style.font_size_ratio / 30.0)
    thickness  = 2 if style.font_weight == "bold" else 1
    font       = cv2.FONT_HERSHEY_DUPLEX

    # Word-wrap (approximate)
    words    = text.split()
    lines    = []
    current  = ""
    for word in words:
        test = f"{current} {word}".strip() if current else word
        (tw, _), _ = cv2.getTextSize(test, font, font_scale, thickness)
        if tw > int(w * 0.80) and current:
            lines.append(current)
            current = word
        else:
            current = test
    if current:
        lines.append(current)

    line_h = int(font_scale * 36)
    total_h = len(lines) * line_h
    y_start = h - int(h * 0.12) - total_h + y_offset

    for i, line in enumerate(lines):
        (tw, th), _ = cv2.getTextSize(line, font, font_scale, thickness)
        x = (w - tw) // 2
        y = y_start + i * line_h
        # Shadow
        cv2.putText(overlay, line, (x + 2, y + 2), font, font_scale, (0, 0, 0), thickness + 1, cv2.LINE_AA)
        cv2.putText(overlay, line, (x, y), font, font_scale, (255, 255, 255), thickness, cv2.LINE_AA)

    return cv2.addWeighted(overlay, alpha, frame, 1.0 - alpha, 0)


# ── Public API ────────────────────────────────────────────────────────────────

def render_caption(
    frame: np.ndarray,
    text: str,
    style: TextStyle,
    t: float,                   # normalised slide time 0→1
    w: int,
    h: int,
) -> np.ndarray:
    """
    Overlay an animated caption on a video frame.

    Args:
        frame:   BGR uint8 video frame.
        text:    Caption string (may be empty — returns frame unchanged).
        style:   TextStyle from active Theme.
        t:       Normalised time within slide [0→1] for animation.
        w, h:    Output frame dimensions.

    Returns:
        Frame with caption composited.
    """
    if not text or not text.strip():
        return frame

    # Approximate base Y for animation
    font_px = max(16, int(w * style.font_size_ratio))
    alpha, y_offset = _animation_params(style.animation, t, h - 100, font_px)

    if alpha < 0.02:
        return frame   # invisible — skip rendering

    try:
        import PIL  # noqa
        return _render_pillow(frame, text, style, alpha, y_offset, w, h)
    except ImportError:
        return _render_opencv(frame, text, style, alpha, y_offset, w, h)
