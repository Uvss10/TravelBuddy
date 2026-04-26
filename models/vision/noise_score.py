"""
models/vision/noise_score.py — Image Noise Estimator

Thinking like a travel photographer:
  - Night shots, indoor restaurant photos, and cave/temple shots often suffer from
    heavy ISO noise. They look terrible in a reel even when they're compositionally good.
  - High noise = grainy, low-quality feel on a phone screen.
  - We want to identify noise-free shots and penalize extremely noisy ones.

Method: High-frequency noise estimation using the residual between the image
and its Gaussian-blurred version (noise residual). A clean photo has very low
residual variance; a noisy one has high residual.

Returns:
  noise_level:  0.0 = very noisy,  1.0 = very clean
"""

from __future__ import annotations
import cv2
import numpy as np


def calculate_noise_score(image: np.ndarray) -> float:
    """
    Returns a noise cleanliness score: 1.0 = clean, 0.0 = very noisy.
    Works directly on the already-loaded BGR image array.
    """
    if image is None or image.size == 0:
        return 0.5

    # Convert to float grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY).astype(np.float32)

    # Estimate noise using the high-frequency residual method
    # Blur the image to get a smooth version
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Residual = original - smooth (this is the "noise" signal)
    residual = gray - blurred

    # Standard deviation of the residual = noise level
    noise_std = float(residual.std())

    # Calibrate: 
    #   noise_std < 3  → pristine (1.0)
    #   noise_std ~ 8  → acceptable (0.7)
    #   noise_std ~ 15 → noisy (0.4)
    #   noise_std > 25 → very noisy (0.1)
    noise_score = max(0.05, 1.0 - (noise_std / 25.0))
    return round(min(1.0, noise_score), 4)


def estimate_iso_sensitivity(image: np.ndarray) -> float:
    """
    Estimates how much the image looks like it was shot at very high ISO.
    Returns 0–1: 0 = likely high ISO / noisy, 1 = likely low ISO / clean.
    Uses local patch variance estimation (known technique from DnCNN papers).
    """
    if image is None or image.size == 0:
        return 0.5

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY).astype(np.float32)
    h, w = gray.shape

    # Sample 16x16 patches from flat/smooth areas and measure variance
    patch_variances = []
    for _ in range(20):
        # Random patch
        py = np.random.randint(0, max(1, h - 16))
        px = np.random.randint(0, max(1, w - 16))
        patch = gray[py:py+16, px:px+16]
        patch_variances.append(float(patch.var()))

    # The minimum variance patches are most likely to be "flat" areas
    # High variance in "flat" areas → noise
    min_variances = sorted(patch_variances)[:8]  # Take the 8 most uniform patches
    avg_flat_variance = float(np.mean(min_variances))

    # Calibrate: flat_var < 10 = clean, > 100 = very noisy
    iso_cleanliness = max(0.0, 1.0 - (avg_flat_variance / 100.0))
    return round(min(1.0, iso_cleanliness), 4)
