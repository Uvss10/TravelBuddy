"""
models/vision/blur_detector.py — Sharpness Scorer v2

Improvement 1: ROI-based sharpness + Tenengrad dual-measure.

Problem fixed:
  ❌ v1: Laplacian on FULL image → penalizes intentional bokeh / portrait-mode shots
         where the background is blurred by design.

Solution:
  ✅ v2: Laplacian + Tenengrad computed on the central 60% ROI only.
         This measures the subject sharpness, not background blur.
         Final score = 0.6 * Laplacian + 0.4 * Tenengrad (averaged then log-normalized).
"""

import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis


def _tenengrad(roi: np.ndarray) -> float:
    """
    Tenengrad sharpness measure: sum of squared Sobel gradient magnitudes.
    High value = sharp edges = focused image.
    """
    gx = cv2.Sobel(roi, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(roi, cv2.CV_64F, 0, 1, ksize=3)
    return float(np.mean(gx**2 + gy**2))


def calculate_blur_score(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Returns sharpness score using a dual-measure on the central 60% ROI.

    - Laplacian variance: detects fine focus-plane sharpness.
    - Tenengrad (Sobel gradient energy): detects edge crispness.
    - Final = 0.6 * laplacian + 0.4 * tenengrad

    Using ROI avoids penalizing portrait-mode bokeh backgrounds.
    The raw score is in the same range as v1 (Laplacian variance units)
    so all downstream log-scale normalization remains compatible.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)

    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # ── Central 60% ROI (±1/3 from center on each axis) ──────────────────────
    cy, cx = h // 2, w // 2
    y1, y2 = max(0, cy - h // 3), min(h, cy + h // 3)
    x1, x2 = max(0, cx - w // 3), min(w, cx + w // 3)
    roi = gray[y1:y2, x1:x2]

    if roi.size == 0:
        # Extremely small image — fall back to full image
        roi = gray

    # ── Dual sharpness measures ───────────────────────────────────────────────
    laplacian_score = float(cv2.Laplacian(roi, cv2.CV_64F).var())
    tenengrad_score = _tenengrad(roi)

    # Blend: Laplacian is more sensitive to focus; Tenengrad to edge crispness.
    # Tenengrad values are ~100× larger — normalize to same scale before blending.
    # We keep the output in "Laplacian variance units" for backward compatibility
    # with the log-scale normalization in _composite_quality_v2 (ceiling 3000).
    tenengrad_norm = tenengrad_score / 100.0   # empirical scale alignment

    final_sharpness = 0.6 * laplacian_score + 0.4 * tenengrad_norm
    return float(final_sharpness)
