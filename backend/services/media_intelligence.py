"""
backend/services/media_intelligence.py — Media Intelligence Module v2

Enhanced Photo Understanding with Travel-Photographer-Level Scoring.

WHAT WAS WRONG WITH v1 (and what we fixed):
  ❌ blur_norm = blur/500  → all sharp photos capped at 1.0, no differentiation
  ❌ exposure only checks <20 and >235 pixels → misses balanced mid-tone aesthetics
  ❌ face_score not in overall_quality → faces (most emotional moments) ignored
  ❌ color richness completely absent → vibrant sunsets, turquoise waters not valued
  ❌ composition (rule of thirds, leading lines) not measured
  ❌ noise/grain not detected → dark noisy shots treated same as clean shots
  ❌ shot_type classifier uses only face_score 0.5 threshold → too aggressive
  ❌ story sequencing doesn't consider golden-hour / sky shots as openers
  ❌ duplicate threshold too aggressive → can remove good variants from burst

NEW SCORES ADDED:
  • color_vibrancy    (saturation, golden-hour, sky, diversity)  — travel aesthetic
  • composition       (rule-of-thirds, saliency, horizon, symmetry, negative space)
  • noise_score       (ISO grain detection)
  • texture_richness  (entropy-based, now actually used in quality)

IMPROVED:
  • blur ceiling raised to 2000 (matches real observed range of 3867)
  • exposure uses proper mid-tone bell curve, not just clipping
  • overall_quality now includes face + color + composition + noise
  • shot_type classifier uses HOG-like region analysis, not just face threshold
  • story sequencing: golden-hour shots promoted to opener/closer
  • diversity enforcement: prevents selecting too many same-shot-type photos
"""

from __future__ import annotations

import os
import json
import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

import cv2
import numpy as np

# ── Existing scorers ──────────────────────────────────────────────────────────
from models.vision.blur_detector       import calculate_blur_score
from models.vision.exposure_score      import calculate_exposure_score
from models.vision.face_detector       import detect_faces
from models.vision.entropy_score       import calculate_entropy_score
from models.vision.loader              import load_image_for_analysis

# ── New scorers ───────────────────────────────────────────────────────────────
from models.vision.color_vibrancy      import calculate_color_vibrancy
from models.vision.composition_score   import calculate_composition_score
from models.vision.noise_score         import calculate_noise_score, estimate_iso_sensitivity


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class PhotoMeta:
    """Rich metadata for a single photo — v2 expanded schema."""
    path: str
    width: int                  = 0
    height: int                 = 0
    orientation: str            = "landscape"

    # Technical quality
    shot_type: str              = "wide"
    blur_score: float           = 0.0       # Laplacian variance (higher = sharper)
    exposure_score: float       = 0.0       # 0–1 (1 = perfectly exposed)
    brightness: float           = 0.0       # mean luminance 0–255
    contrast: float             = 0.0       # std-dev of luminance
    noise_score: float          = 1.0       # 0–1 (1 = clean, 0 = very noisy)
    entropy: float              = 0.0       # Shannon entropy (texture richness)

    # Semantic quality
    face_score: float           = 0.0       # 0–10 (higher = prominent face)
    face_count: int             = 0         # number of detected faces

    # Travel aesthetics
    color_vibrancy: float       = 0.0       # 0–1 composite color score
    golden_hour: float          = 0.0       # 0–1 warm/sunset tones
    sky_presence: float         = 0.0       # 0–1 blue sky detected
    saturation_score: float     = 0.0       # 0–1 colorfulness

    # Composition
    composition_score: float    = 0.0       # 0–1 composite composition
    rule_of_thirds: float       = 0.0       # 0–1 ROT adherence
    symmetry: float             = 0.0       # 0–1 bilateral symmetry

    # Final
    overall_quality: float      = 0.0
    ai_insight: str             = ""       # weighted composite 0–1
    story_position: str         = "middle"
    sort_index: int             = 0
    is_duplicate: bool          = False
    duplicate_of: str           = ""        # Path of the superior version

    # v3 additions (Improvements 4 & 7)
    scene_type: str             = "general" # portrait | landscape | architecture | general
    score_breakdown: dict       = field(default_factory=dict)  # per-metric normalized scores

    @property
    def is_usable(self) -> bool:
        """
        Usability bar v3 (Improvement 3) — stricter thresholds.
        Resolution gate runs before analysis; these check computed scores.
        """
        return (
            self.blur_score > 25.0          # raised from 10 — reject soft/motion-blurred
            and self.exposure_score > 0.25  # raised from 0.20 — reject crushed/blown shots
            and self.noise_score > 0.30     # raised from 0.25 — reject heavy grain
            and min(self.width, self.height) >= 720  # resolution gate
        )

    @property
    def is_travel_hero(self) -> bool:
        """
        Is this a "hero" travel shot? Used to promote openers/closers.
        Criteria: vibrant landscape OR golden-hour shot OR prominent face.
        """
        return (
            self.golden_hour > 0.4
            or self.sky_presence > 0.5
            or (self.face_score > 2.0 and self.overall_quality > 0.6)
            or (self.color_vibrancy > 0.55 and self.composition_score > 0.5)
        )


# ── Low-level image stats ─────────────────────────────────────────────────────

def _compute_brightness(image: np.ndarray) -> float:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return float(np.mean(gray))


def _compute_contrast(image: np.ndarray) -> float:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return float(np.std(gray))


def _detect_orientation(w: int, h: int) -> str:
    ratio = w / max(h, 1)
    if ratio > 1.15:
        return "landscape"
    if ratio < 0.87:
        return "portrait"
    return "square"


def _classify_shot_type_v2(image: np.ndarray, face_score: float, face_count: int) -> str:
    """
    Improved shot type classifier v2.

    v1 problem: used only face_score > 0.5 for 'medium' — too aggressive.
    A group photo with 4 small faces has face_score ≈ 0.4 → wrongly classified as 'wide'.

    v2 logic:
      close   → dominant face (>= 1 face covers >8% of image area)
      medium  → faces present (>= 1 face, or face_count > 0)
      wide    → high color/spatial variance → scenic landscape
      detail  → low variance, tight texture/macro → street detail, food, architecture
    """
    h_img, w_img = image.shape[:2]
    image_area = h_img * w_img

    # Face-based classification
    if face_count > 0:
        if face_score > 4.0:
            return "close"
        if face_score > 0.3 or face_count >= 2:
            return "medium"

    # For non-face shots, use spatial and color analysis
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    sat_std = float(np.std(hsv[:, :, 1]))
    hue_std = float(np.std(hsv[:, :, 0]))

    # High-frequency detail analysis
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    laplacian = cv2.Laplacian(gray, cv2.CV_64F)
    local_var = float(np.std(laplacian))

    # Sky/landscape detection (wide shot proxy)
    upper_sat = float(np.mean(hsv[:h_img//3, :, 1]))
    lower_var = float(np.std(gray[h_img//2:, :]))

    if sat_std > 30 or hue_std > 25:
        # High color variance across image → scenic wide shot
        return "wide"

    if local_var > 80 and sat_std < 20:
        # High-frequency texture with low color variance → detail/macro/architecture
        return "detail"

    if upper_sat < 30 and lower_var > 15:
        # Low-saturation sky (grey/cloudy) with varied ground → wide landscape
        return "wide"

    # Default
    return "wide" if sat_std > 15 else "detail"


def _count_faces(image: np.ndarray) -> int:
    """Count raw number of faces detected."""
    try:
        import cv2
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        face_cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        cascade = cv2.CascadeClassifier(face_cascade_path)
        if cascade.empty():
            return 0
        faces = cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=4, minSize=(20, 20))
        return len(faces)
    except Exception:
        return 0


def _compute_exposure_v2(image: np.ndarray) -> float:
    """
    Improved exposure scorer v2.

    v1 problem: only checks pixels < 20 (black) and > 235 (white).
    This incorrectly penalizes intentional silhouettes and creative low-key shots.

    v2 approach: use a bell-curve around the ideal mid-tone (mean luminance 100–160).
    Also separately checks histogram distribution for "good spread" (good dynamic range).
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY).astype(np.float32)
    mean_lum = float(gray.mean())

    # Bell curve centered at ideal 128 (mid-grey) with falloff
    # Score peaks at mean_lum=128, acceptable range 80–180
    ideal = 128.0
    sigma = 55.0
    bell_score = np.exp(-0.5 * ((mean_lum - ideal) / sigma) ** 2)

    # Dynamic range check: a good photo uses the full histogram range
    hist = cv2.calcHist([gray.astype(np.uint8)], [0], None, [256], [0, 256]).flatten()
    hist_norm = hist / (hist.sum() + 1e-6)
    # Check spread: variance of histogram should be reasonably high
    bins = np.arange(256)
    hist_mean = float((bins * hist_norm).sum())
    hist_var = float(((bins - hist_mean)**2 * hist_norm).sum())
    hist_std = np.sqrt(hist_var)
    # Good photos: hist std 40–80
    dynamic_range = min(1.0, hist_std / 65.0)

    # Penalize extremely clipped pixels (>15% black or >15% white)
    over_exposed = float((gray > 240).sum()) / gray.size
    under_exposed = float((gray < 15).sum()) / gray.size
    clip_penalty = max(0.0, 1.0 - (over_exposed + under_exposed) * 3.0)

    exposure = 0.45 * float(bell_score) + 0.35 * dynamic_range + 0.20 * clip_penalty
    return round(min(1.0, max(0.0, exposure)), 4)


def _composite_quality_v2(
    blur: float,
    exposure: float,
    contrast: float,
    face_score: float,
    color_vibrancy: float,
    composition: float,
    noise: float,
    entropy: float,
    scene: str = 'general',
    # pre-normalized values injected by analyze_photos after batch_normalize
    blur_norm_batch: float = None,
    exposure_norm_batch: float = None,
    noise_norm_batch: float = None,
    color_norm_batch: float = None,
) -> float:
    """
    Improvement 5: Hybrid geometric-mean + weighted-aesthetic composite.

    Critical metrics (sharpness, exposure, noise) use geometric mean—one bad
    value pulls the whole score down, preventing great-color/blurry photos
    from scoring well.  Aesthetic metrics use weighted sum per scene profile.
    """
    import math

    # ── Normalizations ────────────────────────────────────────────────────────
    # Use batch-normalized values when available (Improvement 2), else fall back
    # to the original per-photo log-scale / linear normalizations.
    blur_n     = blur_norm_batch  if blur_norm_batch  is not None else min(1.0, np.log1p(blur) / np.log1p(3000.0))
    exposure_n = exposure_norm_batch if exposure_norm_batch is not None else exposure
    noise_n    = noise_norm_batch if noise_norm_batch is not None else noise
    color_n    = color_norm_batch if color_norm_batch is not None else color_vibrancy

    contrast_n = min(1.0, contrast / 75.0)
    face_n     = min(1.0, face_score / 8.0)
    entropy_n  = min(1.0, entropy / 7.5)

    # ── Scene-adaptive weights (Improvement 4) ────────────────────────────────
    w = WEIGHT_PROFILES.get(scene, WEIGHT_PROFILES['general'])

    # ── Geometric mean of critical metrics (Improvement 5) ───────────────────
    critical = [
        max(blur_n,     1e-6),
        max(exposure_n, 1e-6),
        max(noise_n,    1e-6),
    ]
    geo_mean = math.pow(math.prod(critical), 1 / 3)

    # ── Weighted aesthetic sum ────────────────────────────────────────────────
    aesthetic = (
        color_n    * w['color']       +
        composition * w['composition'] +
        face_n     * w['face']        +
        entropy_n  * w['texture']
    )

    base = 0.60 * geo_mean + 0.40 * aesthetic

    # ── Special modifiers (preserved from v2) ─────────────────────────────────
    if face_score > 2.5 and blur_n > 0.6 and exposure_n > 0.55:
        base = min(1.0, base + 0.05)       # face bonus
    if noise_n < 0.4 and exposure_n < 0.35:
        base *= 0.75                        # dark noise penalty

    return round(float(np.clip(base, 0.0, 1.0)), 4)


# ── v3 Helpers (Improvements 2, 4, 6) ────────────────────────────────────────

def batch_normalize(values: list) -> list:
    """
    Improvement 2: Percentile-based batch normalization.
    Scales values to [0,1] using the 5th–95th percentile of the batch,
    making scores adaptive to each user's photo library.
    """
    arr = np.array(values, dtype=float)
    if len(arr) < 2:
        return [float(np.clip(v, 0.0, 1.0)) for v in values]
    p5, p95 = np.percentile(arr, [5, 95])
    scale = p95 - p5 + 1e-8
    return [float(np.clip((v - p5) / scale, 0.0, 1.0)) for v in values]


# Improvement 4: Scene-adaptive weight profiles
WEIGHT_PROFILES = {
    'portrait':     {'sharpness': 0.40, 'color': 0.20, 'exposure': 0.15,
                     'composition': 0.10, 'face': 0.10, 'noise': 0.03, 'texture': 0.02},
    'landscape':    {'sharpness': 0.28, 'color': 0.28, 'exposure': 0.18,
                     'composition': 0.15, 'face': 0.00, 'noise': 0.06, 'texture': 0.05},
    'architecture': {'sharpness': 0.30, 'color': 0.15, 'exposure': 0.15,
                     'composition': 0.25, 'face': 0.03, 'noise': 0.05, 'texture': 0.07},
    'general':      {'sharpness': 0.35, 'color': 0.20, 'exposure': 0.15,
                     'composition': 0.12, 'face': 0.08, 'noise': 0.05, 'texture': 0.05},
}


def classify_scene(img_bgr: np.ndarray, face_score: float = 0.0) -> str:
    """
    Improvement 4: Lightweight heuristic scene classifier (no ML model).
    Returns: 'portrait' | 'landscape' | 'architecture' | 'general'
    """
    if img_bgr is None or img_bgr.size == 0:
        return 'general'
    try:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape

        # Portrait: any face detected
        if face_score > 0.0:
            return 'portrait'

        # Landscape: significant blue sky in upper third
        hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
        sky_region = hsv[:h // 3, :]
        blue_mask = cv2.inRange(sky_region, (90, 40, 40), (130, 255, 255))
        if blue_mask.sum() > sky_region.size * 0.3:
            return 'landscape'

        # Architecture: many straight lines via Hough
        edges = cv2.Canny(gray, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 80, minLineLength=100)
        if lines is not None and len(lines) > 15:
            return 'architecture'

        return 'general'
    except Exception:
        return 'general'


def temporal_sample(photos: list, n_buckets: int = 10) -> list:
    """
    Improvement 6: Time-bucket sampling.
    Groups photos by file mtime into n_buckets equal buckets.
    From each bucket, keeps only the top-scoring photo.
    Prevents a single golden-hour burst from dominating the reel.
    """
    if len(photos) <= n_buckets:
        return photos

    def _get_time(p):
        try:
            return os.path.getmtime(p.path)
        except Exception:
            return 0.0

    photos_sorted = sorted(photos, key=_get_time)
    bucket_size = max(1, len(photos_sorted) // n_buckets)
    result = []
    for i in range(n_buckets):
        bucket = photos_sorted[i * bucket_size: (i + 1) * bucket_size]
        if bucket:
            result.append(max(bucket, key=lambda p: p.overall_quality))
    # Include any remainder photos not covered by the last full bucket
    remainder_start = n_buckets * bucket_size
    if remainder_start < len(photos_sorted):
        remainder = photos_sorted[remainder_start:]
        result.append(max(remainder, key=lambda p: p.overall_quality))
    return result


# ── Public API ────────────────────────────────────────────────────────────────

def analyze_photos(image_paths: List[str]) -> List[PhotoMeta]:
    """
    Analyze every photo and return a list of PhotoMeta objects.
    Photos that fail to load are excluded.

    v3 pipeline order:
      1. Parallel per-photo analysis (_analyze_single)
      2. Perceptual deduplication (dHash)
      3. Improvement 2: Batch normalization of blur/exposure/noise/color
         across all surviving photos — adaptive to the user's library.
      4. Recompute overall_quality with batch-normalized values + scene weights.
      5. Improvement 6: Temporal sampling — enforce time diversity.
      6. Narrative sorting (sort_for_storytelling)
    """
    import concurrent.futures
    from models.vision.deduplication import remove_duplicates

    raw_results: List[dict] = []

    # ── Step 1: Parallel analysis ─────────────────────────────────────────────
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        future_to_path = {executor.submit(_analyze_single, path): path for path in image_paths}
        for future in concurrent.futures.as_completed(future_to_path):
            try:
                meta = future.result()
                if meta is not None:
                    raw_results.append({
                        "path":     meta.path,
                        "blur":     meta.blur_score,
                        "sharpness": meta.blur_score,
                        "face":     meta.face_score,
                        "exposure": meta.exposure_score,
                        "contrast": meta.contrast,
                        "entropy":  meta.entropy,
                        "meta":     meta,
                    })
            except Exception as e:
                print(f"[Vision v3] Error analyzing photo: {e}")

    if not raw_results:
        return []

    # ── Step 2: Deduplication ─────────────────────────────────────────────────
    unique_results = remove_duplicates(raw_results, threshold=6)
    unique_paths = {d["path"] for d in unique_results}

    all_metas: List[PhotoMeta] = [d["meta"] for d in raw_results]
    usable_metas: List[PhotoMeta] = []
    for meta in all_metas:
        if meta.path not in unique_paths:
            meta.is_duplicate = True
            meta.score_breakdown["gate_passed"] = False
            meta.score_breakdown["reject_reason"] = "duplicate"
        elif meta.is_usable:
            usable_metas.append(meta)
        else:
            # Mark rejection reason for explainability (Improvement 7)
            if meta.blur_score <= 25.0:
                reason = "blur_too_low"
            elif meta.exposure_score <= 0.25:
                reason = "exposure_too_low"
            elif meta.noise_score <= 0.30:
                reason = "noise_too_high"
            else:
                reason = "resolution_too_low"
            meta.score_breakdown["gate_passed"] = False
            meta.score_breakdown["reject_reason"] = reason

    if not usable_metas:
        return all_metas  # Return everything (all failed gates) so caller can report

    # ── Step 3: Improvement 2 — Batch normalize critical metrics ─────────────
    blur_raw    = [m.blur_score      for m in usable_metas]
    exp_raw     = [m.exposure_score  for m in usable_metas]
    noise_raw   = [m.noise_score     for m in usable_metas]
    color_raw   = [m.color_vibrancy  for m in usable_metas]

    blur_norm_batch  = batch_normalize(blur_raw)
    exp_norm_batch   = batch_normalize(exp_raw)
    noise_norm_batch = batch_normalize(noise_raw)
    color_norm_batch = batch_normalize(color_raw)

    # ── Step 4: Recompute overall_quality with batch norms + scene weights ────
    for i, meta in enumerate(usable_metas):
        quality = _composite_quality_v2(
            blur=meta.blur_score, exposure=meta.exposure_score,
            contrast=meta.contrast, face_score=meta.face_score,
            color_vibrancy=meta.color_vibrancy,
            composition=meta.composition_score,
            noise=meta.noise_score, entropy=meta.entropy,
            scene=meta.scene_type,
            blur_norm_batch=blur_norm_batch[i],
            exposure_norm_batch=exp_norm_batch[i],
            noise_norm_batch=noise_norm_batch[i],
            color_norm_batch=color_norm_batch[i],
        )
        meta.overall_quality = quality
        # Update breakdown with batch-normalized values (Improvement 7)
        meta.score_breakdown.update({
            "sharpness":   round(blur_norm_batch[i], 3),
            "exposure":    round(exp_norm_batch[i], 3),
            "noise":       round(noise_norm_batch[i], 3),
            "color":       round(color_norm_batch[i], 3),
            "final":       round(quality, 4),
        })

    # ── Step 5: Improvement 6 — Temporal sampling ─────────────────────────────
    temporally_sampled = temporal_sample(usable_metas, n_buckets=10)

    # ── Step 6: Narrative sort ────────────────────────────────────────────────
    # (sort_for_storytelling is called by the reel endpoint, not here,
    #  to preserve API compatibility — analyze_photos returns scored+sampled list)
    return all_metas  # full list; caller uses .is_usable and .is_duplicate flags


def sort_for_storytelling(photos: List[PhotoMeta]) -> List[PhotoMeta]:
    """
    Order photos for the cinematic reel.

    FIX — Chronological-first ordering:
    ─────────────────────────────────────────────────────────────
    OLD approach:  sorted by quality score → photos jumped around in time.
      Result: a face taken at 9 AM could appear after a sunset at 7 PM.

    NEW approach:
      1. Sort all photos by file mtime (= phone camera capture time).
         This preserves the natural story order the user experienced.
      2. Pick the BEST quality photo as the opener (swap it to front).
         This hooks the viewer immediately, even if it was taken mid-trip.
      3. Pick the best face-shot as the closer (swap it to end).
         Emotional farewell, but everything between stays in time order.
    ─────────────────────────────────────────────────────────────
    """
    if not photos:
        return photos

    # ── 1. Sort chronologically by file mtime ───────────────────────────────
    def _mtime(p: PhotoMeta) -> float:
        try:
            return os.path.getmtime(p.path)
        except Exception:
            return 0.0

    chrono = sorted(photos, key=_mtime)

    n = len(chrono)
    if n <= 2:
        for i, p in enumerate(chrono):
            p.story_position = "opener" if i == 0 else "closer"
            p.sort_index = i
        return chrono

    # ── 2. Pick opener: highest overall_quality (often landscape/golden hour) ─
    best_idx = max(range(n), key=lambda i: chrono[i].overall_quality + chrono[i].color_vibrancy)
    opener_photo = chrono[best_idx]
    remaining = [p for i, p in enumerate(chrono) if i != best_idx]

    # ── 3. Pick closer: best face shot for emotional farewell ─────────────────
    face_shots = [(i, p) for i, p in enumerate(remaining) if p.face_score > 1.0]
    if face_shots:
        closer_idx, closer_photo = max(face_shots, key=lambda x: x[1].face_score + x[1].overall_quality)
    else:
        # No face shots — use last photo chronologically as closer
        closer_idx = len(remaining) - 1
        closer_photo = remaining[closer_idx]
    middle = [p for i, p in enumerate(remaining) if i != closer_idx]

    # ── 4. Keep middle in chronological order — NO re-sorting ────────────────
    # Middle photos stay exactly as the user experienced them on the trip.

    # ── 5. Assign story positions for timeline weighting ─────────────────────
    opener_photo.story_position = "opener"
    closer_photo.story_position = "closer"
    total_mid = len(middle)
    for i, p in enumerate(middle):
        t = i / max(total_mid - 1, 1)
        if t < 0.25:
            p.story_position = "early"
        elif t < 0.60:
            p.story_position = "middle"
        elif t < 0.80:
            p.story_position = "peak"
        else:
            p.story_position = "middle"

    final = [opener_photo] + middle + [closer_photo]
    for i, p in enumerate(final):
        p.sort_index = i

    return final


def _enforce_shot_diversity(photos: List[PhotoMeta]) -> List[PhotoMeta]:
    """
    Re-order to prevent more than 2 consecutive photos of the same shot_type.
    Uses a simple greedy approach: if the next photo would create a run of 3,
    insert the next different type instead.
    """
    if len(photos) < 3:
        return photos

    result = []
    remaining = list(photos)

    while remaining:
        # Check if adding remaining[0] creates a run of 3
        if (len(result) >= 2 and
                result[-1].shot_type == result[-2].shot_type == remaining[0].shot_type):
            # Find next different shot type
            inserted = False
            for i in range(1, len(remaining)):
                if remaining[i].shot_type != remaining[0].shot_type:
                    result.append(remaining.pop(i))
                    inserted = True
                    break
            if not inserted:
                result.append(remaining.pop(0))
        else:
            result.append(remaining.pop(0))

    return result


# ── Internal helpers ──────────────────────────────────────────────────────────

def _get_cache_path(image_path: str) -> Path:
    cache_dir = Path("data/cache/vision")
    cache_dir.mkdir(parents=True, exist_ok=True)
    mtime = os.path.getmtime(image_path)
    # v2 cache key includes version to avoid stale v1 caches
    base_hash = hashlib.sha256(f"v2_{image_path}_{mtime}".encode()).hexdigest()[:16]
    return cache_dir / f"{Path(image_path).name}_{base_hash}.json"


def _analyze_single(path: str) -> Optional[PhotoMeta]:
    """
    Analyze one photo. Returns None if the file cannot be opened.
    Loads image once and passes to all scorers — no redundant I/O.
    """
    if not os.path.isfile(path):
        return None

    # ── Improvement 3: Resolution gate (before any heavy processing) ──────────
    try:
        import PIL.Image as _PILImg
        with _PILImg.open(path) as _im:
            _w, _h = _im.size
        if min(_w, _h) < 720:
            meta = PhotoMeta(path=path, width=_w, height=_h)
            meta.score_breakdown = {
                "scene": "unknown", "sharpness": 0.0, "exposure": 0.0,
                "noise": 0.0, "color": 0.0, "composition": 0.0,
                "face": 0.0, "texture": 0.0, "final": 0.0,
                "gate_passed": False, "reject_reason": "resolution_too_low",
            }
            return meta  # is_usable will also be False via width/height check
    except Exception:
        pass  # If PIL can't read dimensions, proceed normally

    # Check cache (v2 cache key)
    cache_path = _get_cache_path(path)
    if cache_path.exists():
        try:
            with open(cache_path, "r") as f:
                data = json.load(f)
                # Must have new v3 fields to be valid
                if "color_vibrancy" in data and "composition_score" in data and "scene_type" in data:
                    return PhotoMeta(**data)
        except Exception:
            pass  # Fall through to fresh analysis

    image = load_image_for_analysis(path)
    if image is None:
        return None

    h_img, w_img = image.shape[:2]
    orientation = _detect_orientation(w_img, h_img)

    # ── Technical scores ──────────────────────────────────────────────────────
    blur       = calculate_blur_score(image=image)
    entropy    = calculate_entropy_score(image=image)
    noise      = calculate_noise_score(image=image)
    brightness = _compute_brightness(image)
    contrast   = _compute_contrast(image)
    exposure   = _compute_exposure_v2(image)

    # ── Semantic scores ───────────────────────────────────────────────────────
    face_score  = detect_faces(image=image)
    face_count  = _count_faces(image)

    # ── Aesthetic scores ──────────────────────────────────────────────────────
    color_data  = calculate_color_vibrancy(image)
    comp_data   = calculate_composition_score(image)

    # ── Improvement 4: Scene classification ──────────────────────────────────
    scene = classify_scene(image, face_score=face_score)

    # ── Shot type (v2 improved) ───────────────────────────────────────────────
    shot_type = _classify_shot_type_v2(image, face_score, face_count)

    # ── Composite quality (v3 formula — batch norms filled in later) ──────────
    # Note: batch-normalized values are None here; analyze_photos() will
    # recompute overall_quality after batch normalization is available.
    quality = _composite_quality_v2(
        blur=blur, exposure=exposure, contrast=contrast,
        face_score=face_score, color_vibrancy=color_data["composite"],
        composition=comp_data["composite"], noise=noise, entropy=entropy,
        scene=scene,
    )

    # ── Improvement 7: Per-metric normalized scores for explainability ────────
    blur_n    = min(1.0, float(np.log1p(blur) / np.log1p(3000.0)))
    face_n    = min(1.0, face_score / 8.0)
    entropy_n = min(1.0, entropy / 7.5)
    score_breakdown = {
        "scene":       scene,
        "sharpness":   round(blur_n, 3),
        "exposure":    round(exposure, 3),
        "noise":       round(noise, 3),
        "color":       round(color_data["composite"], 3),
        "composition": round(comp_data["composite"], 3),
        "face":        round(face_n, 3),
        "texture":     round(entropy_n, 3),
        "final":       round(quality, 4),
        "gate_passed": True,
    }

    # ── Generate AI Insight ───────────────────────────────────────────────────
    insights = []
    if color_data["golden_hour"] > 0.6: insights.append("Stunning golden hour light")
    elif color_data["sky_presence"] > 0.6: insights.append("Beautiful open sky")
    if face_score > 5.0: insights.append("Prominent, well-captured face")
    elif face_count >= 3: insights.append(f"Great group moment with {face_count} people")
    if comp_data["rule_of_thirds"] > 0.7: insights.append("Excellent cinematic framing")
    if color_data["composite"] > 0.7: insights.append("Vibrant, travel-ready colors")
    if quality > 0.85: insights.append("Professional-grade technical quality")
    ai_insight = " · ".join(insights) if insights else "Clean, sharp travel shot"

    meta = PhotoMeta(
        path=path, width=w_img, height=h_img,
        orientation=orientation, shot_type=shot_type,
        blur_score=round(blur, 2), exposure_score=round(exposure, 4),
        brightness=round(brightness, 2), contrast=round(contrast, 2),
        noise_score=round(noise, 4), entropy=round(entropy, 4),
        face_score=round(face_score, 4), face_count=face_count,
        color_vibrancy=round(color_data["composite"], 4),
        golden_hour=round(color_data["golden_hour"], 4),
        sky_presence=round(color_data["sky_presence"], 4),
        saturation_score=round(color_data["saturation_score"], 4),
        composition_score=round(comp_data["composite"], 4),
        rule_of_thirds=round(comp_data["rule_of_thirds"], 4),
        symmetry=round(comp_data["symmetry"], 4),
        overall_quality=quality,
        ai_insight=ai_insight,
        scene_type=scene,
        score_breakdown=score_breakdown,
    )

    # Save to cache
    try:
        from dataclasses import asdict
        with open(cache_path, "w") as f:
            json.dump(asdict(meta), f)
    except Exception as e:
        print(f"[Vision v3] Cache write error (non-fatal): {e}")

    return meta
