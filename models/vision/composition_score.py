"""
models/vision/composition_score.py — Photographic Composition Scorer

Thinking like a travel photographer:
  - Rule of Thirds: subject not dead-center is more cinematic.
  - Horizon alignment: level horizon = professional shot.
  - Leading lines: edges that draw the eye into the scene.
  - Subject saliency: is there a clear visual subject vs cluttered mess?
  - Symmetry: architectural photos benefit from bilateral symmetry (temples, bridges).

All scores 0–1.
"""

from __future__ import annotations
import cv2
import numpy as np


def calculate_composition_score(image: np.ndarray) -> dict:
    """
    Returns composition analysis scores, all 0–1.

    Args:
        image: BGR ndarray

    Returns:
        {
            'rule_of_thirds':   float,  # subject near ROT intersections
            'saliency_clarity': float,  # clear subject vs noise
            'horizon_level':    float,  # horizontal edges near mid = leveled horizon
            'symmetry':         float,  # bilateral symmetry (good for architecture)
            'negative_space':   float,  # clean sky/water areas = breathing room
            'composite':        float,  # weighted composition score
        }
    """
    if image is None or image.size == 0:
        return {k: 0.0 for k in ['rule_of_thirds', 'saliency_clarity',
                                   'horizon_level', 'symmetry', 'negative_space', 'composite']}

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # ── 1. Rule of Thirds ─────────────────────────────────────────────────────
    # Find the strongest edge points and check if they land near ROT intersections
    # ROT intersections at: (w*1/3, h*1/3), (w*2/3, h*1/3), (w*1/3, h*2/3), (w*2/3, h*2/3)
    edges = cv2.Canny(gray, 50, 150)

    rot_points = [
        (int(w * 1/3), int(h * 1/3)),
        (int(w * 2/3), int(h * 1/3)),
        (int(w * 1/3), int(h * 2/3)),
        (int(w * 2/3), int(h * 2/3)),
    ]

    # For each ROT intersection, count edge density in a 15% radius window
    zone_size_x = max(1, int(w * 0.15))
    zone_size_y = max(1, int(h * 0.15))
    rot_density = []
    for px, py in rot_points:
        x1 = max(0, px - zone_size_x)
        x2 = min(w, px + zone_size_x)
        y1 = max(0, py - zone_size_y)
        y2 = min(h, py + zone_size_y)
        zone = edges[y1:y2, x1:x2]
        density = float(zone.sum()) / max(zone.size * 255, 1)
        rot_density.append(density)

    # Center density
    cx1, cx2 = int(w * 0.35), int(w * 0.65)
    cy1, cy2 = int(h * 0.35), int(h * 0.65)
    center_density = float(edges[cy1:cy2, cx1:cx2].sum()) / max((cx2-cx1)*(cy2-cy1)*255, 1)

    max_rot = max(rot_density) if rot_density else 0
    # ROT score: reward if ROT zones have more edges than center
    rule_of_thirds = min(1.0, max(0.0, (max_rot - center_density * 0.5) * 10))

    # ── 2. Saliency Clarity ───────────────────────────────────────────────────
    # Simple saliency: spectral residual approximation using edge map
    # A clear subject = concentrated edge region, not scattered everywhere
    edge_float = edges.astype(np.float32) / 255.0
    total_edge = edge_float.sum()
    if total_edge > 50:
        # Compute the centroid of edges
        ys, xs = np.where(edges > 0)
        cy_e = float(ys.mean()) / h
        cx_e = float(xs.mean()) / w
        # Edge spread: lower spread = more concentrated subject
        cy_std = float(ys.std()) / h
        cx_std = float(xs.std()) / w
        spread = (cy_std + cx_std) / 2.0
        saliency_clarity = min(1.0, max(0.0, 1.0 - spread * 2.0))
    else:
        saliency_clarity = 0.3  # very few edges = almost empty scene

    # ── 3. Horizon Level ──────────────────────────────────────────────────────
    # Use Hough lines to detect dominant horizontal lines
    # A well-leveled photo = long horizontal line near vertical center
    horizon_level = 0.5  # default neutral
    try:
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=60,
                                minLineLength=int(w * 0.25), maxLineGap=20)
        if lines is not None:
            horizontal_lines = []
            for line in lines:
                x1, y1, x2, y2 = line[0]
                angle = abs(np.degrees(np.arctan2(y2 - y1, x2 - x1)))
                if angle < 10 or angle > 170:  # nearly horizontal
                    length = np.sqrt((x2-x1)**2 + (y2-y1)**2)
                    mid_y = (y1 + y2) / 2.0 / h  # normalized 0–1 vertical position
                    horizontal_lines.append((length, mid_y))

            if horizontal_lines:
                # Weight lines by length — longer lines matter more
                total_len = sum(l for l, _ in horizontal_lines)
                weighted_y = sum(l * y for l, y in horizontal_lines) / total_len
                # Horizon near 33–67% vertical = well-composed
                if 0.25 < weighted_y < 0.75:
                    horizon_level = 1.0 - abs(weighted_y - 0.5) * 1.5
                    horizon_level = min(1.0, max(0.5, horizon_level))
    except Exception:
        horizon_level = 0.5

    # ── 4. Symmetry ───────────────────────────────────────────────────────────
    # Bilateral (left-right) symmetry: great for architecture, bridges, tunnels
    if w > 10:
        left_half = gray[:, :w//2]
        right_half = cv2.flip(gray[:, w//2:], 1)
        # Resize right to match left if w is odd
        if left_half.shape[1] != right_half.shape[1]:
            right_half = right_half[:, :left_half.shape[1]]
        diff = cv2.absdiff(left_half, right_half).astype(np.float32)
        # Symmetry score: 1 - normalized mean diff
        symmetry = max(0.0, 1.0 - float(diff.mean()) / 60.0)
    else:
        symmetry = 0.0

    # ── 5. Negative Space (clean sky/water areas) ─────────────────────────────
    # Negative space = areas with very low edge density → breathing room in the photo
    # Great for travel portraits against sky / landscapes with clear water
    # Check for large smooth regions (low-frequency areas)
    blur_check = cv2.GaussianBlur(gray, (21, 21), 0)
    smooth_diff = cv2.absdiff(gray, blur_check)
    low_detail_ratio = float((smooth_diff < 12).sum()) / max(gray.size, 1)
    # 40–80% smooth area = good negative space
    if low_detail_ratio < 0.2:
        negative_space = 0.2    # too cluttered
    elif low_detail_ratio > 0.90:
        negative_space = 0.2    # too empty / blank
    else:
        # Peak at ~0.55 smooth ratio
        negative_space = min(1.0, 1.0 - abs(low_detail_ratio - 0.55) * 2.5)

    # ── Composite ─────────────────────────────────────────────────────────────
    composite = round(
        0.30 * rule_of_thirds +
        0.25 * saliency_clarity +
        0.20 * horizon_level +
        0.15 * negative_space +
        0.10 * symmetry,
        4
    )

    return {
        'rule_of_thirds':   round(rule_of_thirds, 4),
        'saliency_clarity': round(saliency_clarity, 4),
        'horizon_level':    round(horizon_level, 4),
        'symmetry':         round(symmetry, 4),
        'negative_space':   round(negative_space, 4),
        'composite':        composite,
    }
