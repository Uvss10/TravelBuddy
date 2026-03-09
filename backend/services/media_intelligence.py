"""
backend/services/media_intelligence.py — Media Intelligence Module

Module 1 of the cinematic upgrade: Photo Understanding & Smart Sequencing.

Uses existing models/vision/* scorers to analyze every uploaded photo and build
a sorted, story-aware photo sequence before any rendering begins.

Scores computed per photo:
  • blur_score       (higher = sharper)
  • exposure_score   (higher = well-exposed)
  • brightness_score
  • contrast_score
  • face_score       (higher = prominent faces)
  • orientation      ('landscape' | 'portrait' | 'square')
  • shot_type        ('wide' | 'medium' | 'close' | 'detail')
  • overall_quality  (weighted composite 0–1)

Sequencing logic:
  Storytelling arc = Opener → Wide shots → Movement → Faces → Detail → Closer
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List, Optional

import cv2
import numpy as np

# Reuse existing vision scorers
from models.vision.blur_detector       import calculate_blur_score
from models.vision.exposure_score      import calculate_exposure_score
from models.vision.face_detector       import detect_faces
from models.vision.loader              import load_image_for_analysis


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class PhotoMeta:
    """Rich metadata for a single photo."""
    path: str
    width: int                  = 0
    height: int                 = 0
    orientation: str            = "landscape"   # 'landscape' | 'portrait' | 'square'
    shot_type: str              = "wide"         # 'wide' | 'medium' | 'close' | 'detail'
    blur_score: float           = 0.0           # Laplacian variance (higher = sharper)
    exposure_score: float       = 0.0           # 0–1 (1 = perfectly exposed)
    brightness: float           = 0.0           # mean luminance 0–255
    contrast: float             = 0.0           # std-dev of luminance
    face_score: float           = 0.0           # 0–10 (higher = prominent face(s))
    overall_quality: float      = 0.0           # weighted composite 0–1
    story_position: str         = "middle"      # 'opener' | 'early' | 'middle' | 'peak' | 'closer'
    sort_index: int             = 0             # final narrative position

    @property
    def is_usable(self) -> bool:
        """A photo is usable if it passes minimum quality bar."""
        return self.blur_score > 20.0 and self.exposure_score > 0.30


# ── Low-level image stats ──────────────────────────────────────────────────────

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


def _classify_shot_type(image: np.ndarray, face_score: float) -> str:
    """
    Classify photo shot type using face prominence and color variation.
    • close   – large face, tight crop
    • medium  – faces present but not dominant
    • wide    – sweeping scene, low face_score, high color variance
    • detail  – macro / texture, low variance but no faces
    """
    if face_score > 3.0:
        return "close"
    if face_score > 0.5:
        return "medium"
    # Color variance as proxy for scenic complexity
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    sat_var = float(np.std(hsv[:, :, 1]))
    if sat_var > 35:
        return "wide"
    return "detail"


def _composite_quality(blur: float, exposure: float, contrast: float) -> float:
    """
    Weighted composite quality score normalized 0–1.
    Blur is most important (image must be sharp to be usable).
    """
    blur_norm    = min(blur / 500.0, 1.0)         # 500 = excellent sharpness ceiling
    exposure_n   = exposure                         # already 0–1
    contrast_n   = min(contrast / 80.0, 1.0)       # std-dev ~60–80 = good contrast
    score = 0.50 * blur_norm + 0.30 * exposure_n + 0.20 * contrast_n
    return round(min(1.0, score), 4)


# ── Public API ─────────────────────────────────────────────────────────────────

def analyze_photos(image_paths: List[str]) -> List[PhotoMeta]:
    """
    Analyze every photo and return a list of PhotoMeta objects.
    Photos that fail to load are excluded. Includes perceptual deduplication.
    """
    from models.vision.deduplication import remove_duplicates
    
    raw_results: List[dict] = []

    for path in image_paths:
        meta = _analyze_single(path)
        if meta is not None:
            # Convert to dict for the deduplicator
            d = {
                "path": meta.path,
                "blur": meta.blur_score,
                "sharpness": meta.blur_score, # use blur as proxy for sharpness
                "face": meta.face_score,
                "exposure": meta.exposure_score,
                "contrast": meta.contrast,
                "meta": meta
            }
            raw_results.append(d)

    if not raw_results:
        return []

    # Run deduplication using the improved multi-metric scoring
    unique_results = remove_duplicates(raw_results, threshold=12) # Slightly more aggressive for cinematic
    
    return [d["meta"] for d in unique_results]


def sort_for_storytelling(photos: List[PhotoMeta]) -> List[PhotoMeta]:
    """
    Re-order photos into a cinematic narrative arc:
        Opener → Wide → Medium → Peak (faces) → Detail → Closer

    The function also sets each photo's .story_position and .sort_index.

    Returns:
        Sorted list of PhotoMeta objects.
    """
    if not photos:
        return photos

    n = len(photos)

    # 1) Score each photo with a "dramatic arc" value
    #    We want: best quality openers/closers, face shots near peak, landscapes early
    def _arc_score(p: PhotoMeta) -> float:
        """Higher = better candidate for mid-reel peak moment."""
        return (p.face_score * 2.0) + (p.overall_quality * 5.0) + (p.contrast / 80.0)

    scored = [(p, _arc_score(p)) for p in photos]
    scored.sort(key=lambda x: x[1], reverse=True)   # best quality first

    # 2) Assign narrative positions
    #    Top-2 quality photos → opener and closer
    #    Remaining → middle sorted by shot_type
    if n < 3:
        for i, (p, _) in enumerate(scored):
            p.story_position = "opener" if i == 0 else "closer"
            p.sort_index = i
        return [p for p, _ in scored]

    opener_photo  = scored[0][0]
    closer_photo  = scored[1][0]
    middle_photos = [p for p, _ in scored[2:]]

    opener_photo.story_position = "opener"
    closer_photo.story_position = "closer"

    # Sort middles by shot_type for natural storytelling flow:
    # wide → wide → medium → close → detail
    shot_order = {"wide": 0, "medium": 1, "close": 2, "detail": 3}
    middle_photos.sort(key=lambda p: (shot_order.get(p.shot_type, 2), -p.overall_quality))

    # Assign story positions within middles
    for i, p in enumerate(middle_photos):
        t = i / max(len(middle_photos) - 1, 1)   # 0 → 1
        if t < 0.3:
            p.story_position = "early"
        elif t < 0.7:
            p.story_position = "middle"
        elif t < 0.9:
            p.story_position = "peak"
        else:
            p.story_position = "middle"

    # 3) Assemble final list
    final = [opener_photo] + middle_photos + [closer_photo]
    for i, p in enumerate(final):
        p.sort_index = i

    return final


# ── Internal helpers ───────────────────────────────────────────────────────────

def _analyze_single(path: str) -> Optional[PhotoMeta]:
    """
    Analyze one photo. Returns None if the file cannot be opened.
    Loads image once and passes the array to all scorers to avoid I/O overhead.
    """
    if not os.path.isfile(path):
        return None

    image = load_image_for_analysis(path)
    if image is None:
        return None

    h, w = image.shape[:2]
    orientation = _detect_orientation(w, h)

    blur      = calculate_blur_score(image=image)
    exposure  = calculate_exposure_score(image=image)
    brightness = _compute_brightness(image)
    contrast  = _compute_contrast(image)
    face_score = detect_faces(image=image)

    shot_type = _classify_shot_type(image, face_score)
    quality   = _composite_quality(blur, exposure, contrast)

    return PhotoMeta(
        path          = path,
        width         = w,
        height        = h,
        orientation   = orientation,
        shot_type     = shot_type,
        blur_score    = round(blur, 2),
        exposure_score= round(exposure, 4),
        brightness    = round(brightness, 2),
        contrast      = round(contrast, 2),
        face_score    = round(face_score, 4),
        overall_quality = quality,
    )
