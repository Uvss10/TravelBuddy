import os
import shutil

from models.vision.blur_detector import calculate_blur_score
from models.vision.brightness_score import calculate_brightness
from models.vision.sharpness_score import calculate_sharpness


SELECTED_DIR = "data/selected_images"
TOP_N = 3  # Change to 8 later for reel generation


def normalize(value, min_val, max_val):
    """
    Normalize value between 0 and 1.
    """
    if max_val == min_val:
        return 0.5  # neutral value if all images identical
    return (value - min_val) / (max_val - min_val)


def process_uploaded_images(image_paths):
    """
    Full image quality pipeline:
    1. Calculate blur, sharpness, brightness
    2. Normalize metrics
    3. Compute weighted final score
    4. Rank images
    5. Auto-select top N images
    """

    if not image_paths:
        return {
            "ranked_results": [],
            "selected_images": []
        }

    raw_data = []

    # Step 1: Collect raw metrics
    for path in image_paths:
        blur = float(calculate_blur_score(path))
        sharpness = float(calculate_sharpness(path))
        brightness = float(calculate_brightness(path))

        raw_data.append({
            "path": path,
            "blur": blur,
            "sharpness": sharpness,
            "brightness": brightness
        })

    # Step 2: Find min/max for normalization
    blur_vals = [x["blur"] for x in raw_data]
    sharp_vals = [x["sharpness"] for x in raw_data]
    bright_vals = [x["brightness"] for x in raw_data]

    min_blur, max_blur = min(blur_vals), max(blur_vals)
    min_sharp, max_sharp = min(sharp_vals), max(sharp_vals)
    min_bright, max_bright = min(bright_vals), max(bright_vals)

    results = []

    # Step 3: Normalize + combine
    for item in raw_data:
        norm_blur = normalize(item["blur"], min_blur, max_blur)
        norm_sharp = normalize(item["sharpness"], min_sharp, max_sharp)
        norm_bright = normalize(item["brightness"], min_bright, max_bright)

        # Weighted final quality score
        final_score = (
            0.5 * norm_blur +
            0.3 * norm_sharp +
            0.2 * norm_bright
        ) * 100

        if final_score < 40:
            quality = "Low"
        elif final_score < 70:
            quality = "Medium"
        else:
            quality = "High"

        results.append({
            "image_path": item["path"],
            "blur_score": round(item["blur"], 2),
            "sharpness_score": round(item["sharpness"], 2),
            "brightness": round(item["brightness"], 2),
            "final_quality_score": round(final_score, 2),
            "quality": quality
        })

    # Step 4: Sort best first
    results.sort(key=lambda x: x["final_quality_score"], reverse=True)

    # Step 5: Auto-select top N images
    os.makedirs(SELECTED_DIR, exist_ok=True)

    selected_images = []
    top_images = results[:min(TOP_N, len(results))]

    for img in top_images:
        filename = os.path.basename(img["image_path"])
        dest_path = os.path.join(SELECTED_DIR, filename)

        shutil.copy(img["image_path"], dest_path)
        selected_images.append(dest_path)

    return {
        "ranked_results": results,
        "selected_images": selected_images
    }
