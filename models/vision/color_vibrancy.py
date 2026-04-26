"""
models/vision/color_vibrancy.py — Color Richness & Travel Aesthetics Scorer

Thinking like a travel photographer:
  - A vibrant Santorini sunset, a turquoise Maldives lagoon, a red-and-gold Jaipur
    market, or a lush green Bali rice terrace MUST score high.
  - A grey, washed-out, or flat photo should score lower even if technically sharp.

Metrics computed:
  1. saturation_score    — mean HSV saturation (colorfulness of the image)
  2. vibrancy_score      — weighted by saturation + value (bright AND colorful = travel gold)
  3. color_diversity     — how many distinct hue regions exist (variety = scenic landscape)
  4. golden_hour_score   — warm orange/amber tones → sunrise/sunset → very reelable
  5. sky_presence        — blue sky in upper region → landscape opener shot
"""

from __future__ import annotations
import cv2
import numpy as np


def calculate_color_vibrancy(image: np.ndarray) -> dict:
    """
    Returns a dict of color-based travel aesthetics scores (all 0–1).

    Args:
        image: BGR ndarray (already loaded)

    Returns:
        {
            'saturation_score': float,   # 0–1: colorfulness
            'vibrancy_score':   float,   # 0–1: bright + colorful
            'color_diversity':  float,   # 0–1: variety of hues
            'golden_hour':      float,   # 0–1: warm sunset/sunrise tones
            'sky_presence':     float,   # 0–1: blue sky detected in upper third
            'composite':        float,   # 0–1: weighted travel aesthetic score
        }
    """
    if image is None or image.size == 0:
        return {k: 0.0 for k in ['saturation_score', 'vibrancy_score', 'color_diversity',
                                   'golden_hour', 'sky_presence', 'composite']}

    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV).astype(np.float32)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]

    # 1. Saturation score: mean saturation (0–255 → 0–1)
    # Ignore very dark pixels (value < 30) — they're always desaturated
    bright_mask = v > 30
    if bright_mask.sum() > 100:
        sat_mean = float(s[bright_mask].mean()) / 255.0
    else:
        sat_mean = float(s.mean()) / 255.0
    saturation_score = min(1.0, sat_mean * 1.8)   # boost: 0.55 sat → 0.99 score

    # 2. Vibrancy score: mean(sat * val) over bright pixels — "glowing" photos
    sv_product = (s * v) / (255.0 * 255.0)
    vibrancy_score = min(1.0, float(sv_product.mean()) * 4.5)

    # 3. Color diversity: number of distinct hue clusters (0–180 OpenCV hue range)
    # Count non-grey pixels (sat > 40) and bucket them into 12 hue segments
    non_grey = s > 40
    if non_grey.sum() > 200:
        hues = h[non_grey]
        # 12 hue segments: each 15° wide in OpenCV (0–180)
        hist, _ = np.histogram(hues, bins=12, range=(0, 180))
        # Diversity = fraction of non-empty buckets, weighted by spread
        active_bins = int((hist > (hues.size * 0.02)).sum())  # bucket must have >2% of hues
        color_diversity = min(1.0, active_bins / 8.0)  # 8+ distinct hues = maximum diversity
    else:
        color_diversity = 0.1  # mostly grey = low diversity

    # 4. Golden Hour detection
    # Hue range in OpenCV: Orange ≈ 10–25, Yellow ≈ 25–35, Red ≈ 0–10 or 165–180
    # These are the classic sunrise/sunset tones beloved by travel photographers
    warm_mask = (
        ((h >= 0) & (h <= 25) & (s > 60) & (v > 80)) |    # orange-red warm
        ((h >= 165) & (h <= 180) & (s > 60) & (v > 80))   # deep red
    )
    warm_ratio = float(warm_mask.sum()) / max(image.shape[0] * image.shape[1], 1)
    # Golden hour when 8%+ of the image has warm tones
    golden_hour = min(1.0, warm_ratio / 0.08)

    # 5. Sky presence: detect blue sky in the UPPER THIRD of the image
    upper_third = hsv[:image.shape[0] // 3, :, :]
    uh, us, uv = upper_third[:, :, 0], upper_third[:, :, 1], upper_third[:, :, 2]
    # Blue sky hue: ~100–130 in OpenCV, high saturation, high value
    sky_mask = (uh >= 95) & (uh <= 135) & (us > 50) & (uv > 100)
    sky_ratio = float(sky_mask.sum()) / max(upper_third.shape[0] * upper_third.shape[1], 1)
    sky_presence = min(1.0, sky_ratio / 0.35)  # 35%+ sky → full score

    # Composite travel aesthetic score
    # Golden hour and vibrancy are weighted most heavily
    composite = round(
        0.25 * vibrancy_score +
        0.20 * saturation_score +
        0.20 * golden_hour +
        0.20 * sky_presence +
        0.15 * color_diversity,
        4
    )

    return {
        'saturation_score': round(saturation_score, 4),
        'vibrancy_score':   round(vibrancy_score, 4),
        'color_diversity':  round(color_diversity, 4),
        'golden_hour':      round(golden_hour, 4),
        'sky_presence':     round(sky_presence, 4),
        'composite':        composite,
    }
