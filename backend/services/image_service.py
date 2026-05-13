from PIL import Image, ImageOps
import os
import json
import shutil
import threading
from concurrent.futures import ThreadPoolExecutor
import numpy as np

from models.vision.blur_detector import calculate_blur_score
from models.vision.sharpness_score import calculate_sharpness
from models.vision.exposure_score import calculate_exposure_score
from models.vision.contrast_score import calculate_contrast_score
from models.vision.entropy_score import calculate_entropy_score
from models.vision.face_detector import detect_faces
from models.vision.composition_score import calculate_composition_score
from models.vision.deduplication import remove_duplicates, compute_phash
from models.vision.loader import load_image_for_analysis
from backend import utils

SELECTED_DIR = "data/selected_images"
TOP_N = 100  # Match the 100 photo limit for reels
TARGET_RES = (1080, 1920)


def normalize(value, min_val, max_val):
    if max_val == min_val:
        return 0.5
    return (value - min_val) / (max_val - min_val)


def _refine_image_for_reel(src_path: str, dest_path: str, needs_contrast_boost: bool = False):
    """
    Refines top images to reel-ready vertical WebP.
    
    Key improvements vs old version:
    - Quality 95 (was 85) — near-lossless
    - Pad instead of crop where possible to preserve full image
    - Gentle sharpening (unsharp mask) instead of aggressive resize
    - Mild contrast/vibrance boost — cinematic but not over-processed
    """
    try:
        from PIL import ImageFilter, ImageEnhance
        import numpy as np

        ext = src_path.lower().split('.')[-1]
        is_raw = ext in ['nef', 'cr2', 'arw', 'dng', 'raw', 'orf', 'sr2', 'raf', 'rw2', 'pef']

        if is_raw:
            import rawpy
            with rawpy.imread(src_path) as raw:
                rgb = raw.postprocess(
                    use_camera_wb=True,
                    no_auto_bright=False,
                    bright=1.0,
                    user_flip=0,
                    output_bps=8
                )
                img = Image.fromarray(rgb)
                print(f"[Refine] Successfully developed RAW: {src_path}")
        else:
            with Image.open(src_path) as _img:
                img = _img.copy()
                img.info = _img.info.copy()
        img = ImageOps.exif_transpose(img)
        if img.mode != 'RGB':
            img = img.convert('RGB')

        # ── Smart resize: fit into TARGET_RES maintaining aspect ratio ───────
        target_w, target_h = TARGET_RES
        orig_w, orig_h = img.size
        orig_ratio = orig_w / orig_h
        target_ratio = target_w / target_h

        if abs(orig_ratio - target_ratio) < 0.15:
            # Close enough — simple high-quality resize, no crop needed
            refined = img.resize(TARGET_RES, Image.Resampling.LANCZOS)
        elif orig_ratio < target_ratio:
            # Image is more portrait than target — scale to height, pad sides
            new_h = target_h
            new_w = int(orig_ratio * new_h)
            img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
            refined = Image.new('RGB', TARGET_RES, (0, 0, 0))
            offset = ((target_w - new_w) // 2, 0)
            refined.paste(img_resized, offset)
        else:
            # Image is wider — minimal center crop (only 10% max) then pad
            crop_ratio = min(orig_ratio / target_ratio, 1.1)
            cropped_w = int(orig_w / crop_ratio)
            left = (orig_w - cropped_w) // 2
            img = img.crop((left, 0, left + cropped_w, orig_h))
            refined = img.resize(TARGET_RES, Image.Resampling.LANCZOS)

        # ── Subtle professional enhancement ONLY if needed ───────────────────
        if needs_contrast_boost:
            # 1. Gentle unsharp mask (edge crispness without halos)
            refined = refined.filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=3))
            # 2. Slight contrast boost
            refined = ImageEnhance.Contrast(refined).enhance(1.08)
            # 3. Slight color saturation
            refined = ImageEnhance.Color(refined).enhance(1.1)

        # ── Save at highest quality ───────────────────────────────────────────
        refined.save(dest_path, "WEBP", quality=95, method=6, lossless=False)
        return True

    except Exception as e:
        print(f"[Refine] Failed {src_path}: {e}")
        shutil.copy(src_path, dest_path)
        return False


def _analyze_single_image(path):
    """Lightning-fast metrics using thumbnail loader."""
    try:
        img_array = load_image_for_analysis(path, max_dim=600)
        if img_array is None:
            return None
        return {
            "path":      path,
            "blur":      float(calculate_blur_score(image=img_array)),
            "sharpness": float(calculate_sharpness(image=img_array)),
            "exposure":  float(calculate_exposure_score(image=img_array)),
            "contrast":  float(calculate_contrast_score(image=img_array)),
            "entropy":   float(calculate_entropy_score(image=img_array)),
            "face":      float(detect_faces(image=img_array)),
            "composition": float(calculate_composition_score(img_array)["composite"]),
        }
    except Exception as e:
        print(f"[Analyze Single] Failed for {path}: {e}")
        import traceback
        traceback.print_exc()
        return None


def process_uploaded_images(image_paths):
    if not image_paths:
        return {"ranked_results": [], "selected_images": []}

    # ── Phase 1: FAST LOCAL QUALITY ANALYSIS (no network calls) ──────────────
    with ThreadPoolExecutor(max_workers=8) as executor:
        raw_data = [r for r in executor.map(_analyze_single_image, image_paths) if r is not None]

    unique_data = remove_duplicates(raw_data)
    if not unique_data:
        return {"ranked_results": [], "selected_images": []}

    def get_range(key):
        vals = [x[key] for x in unique_data]
        return min(vals), max(vals)

    m_blur,  mx_blur  = get_range("blur")
    m_sharp, mx_sharp = get_range("sharpness")
    m_exp,   mx_exp   = get_range("exposure")
    m_cont,  mx_cont  = get_range("contrast")
    m_ent,   mx_ent   = get_range("entropy")
    m_face,  mx_face  = get_range("face")
    m_comp,  mx_comp  = get_range("composition")

    final_results = []
    for item in unique_data:
        n_sharp = normalize(item["sharpness"], m_sharp, mx_sharp)
        n_blur  = normalize(item["blur"],      m_blur,  mx_blur)
        n_face  = normalize(item["face"],      m_face,  mx_face)
        n_ent   = normalize(item["entropy"],   m_ent,   mx_ent)
        n_cont  = normalize(item["contrast"],  m_cont,  mx_cont)
        n_exp   = normalize(item["exposure"],  m_exp,   mx_exp)
        n_comp  = normalize(item["composition"], m_comp, mx_comp)

        # Quality weights: include Aesthetic/Composition scores
        score   = (0.20*n_sharp + 0.15*n_blur + 0.20*n_comp + 0.15*n_face + 0.10*n_ent + 0.10*n_cont + 0.10*n_exp) * 100
        quality = "High" if score > 70 else ("Medium" if score > 40 else "Low")

        final_results.append({
            "image_path":         item["path"],
            "final_quality_score": round(score, 2),
            "quality":            quality,
            "metrics":            {k: round(v, 2) for k, v in item.items() if k != "path"},
        })

    final_results.sort(key=lambda x: x["final_quality_score"], reverse=True)

    # ── Phase 2: IMAGE REFINEMENT — convert to reel-ready vertical WebP ───────
    os.makedirs(SELECTED_DIR, exist_ok=True)
    selected_images = []
    top_n           = final_results[:min(TOP_N, len(final_results))]
    refined_map     = {}

    def _refine_task(img):
        f_name = f"refined_{os.path.basename(os.path.splitext(img['image_path'])[0])}.webp"
        dst    = os.path.join(SELECTED_DIR, f_name)
        
        # Only boost contrast if it's in the lower 30% of the batch's contrast range
        # OR if absolute contrast is low (e.g. < 40)
        n_cont = normalize(img["metrics"]["contrast"], m_cont, mx_cont)
        needs_boost = n_cont < 0.3 or img["metrics"]["contrast"] < 40.0

        if _refine_image_for_reel(img["image_path"], dst, needs_contrast_boost=needs_boost):
            return img["image_path"], dst.replace("\\", "/")
        return None

    with ThreadPoolExecutor(max_workers=4) as executor:
        for res in executor.map(_refine_task, top_n):
            if res:
                refined_map[res[0]] = res[1]
                selected_images.append(res[1])

    for res in final_results:
        if res["image_path"] in refined_map:
            res["refined_path"] = refined_map[res["image_path"]]

    # ── Phase 2.5: VISION AI — FIRE-AND-FORGET BACKGROUND THREAD ─────────────
    # The upload response returns IMMEDIATELY after Phase 2.
    # Groq Vision calls run in background, updating scores in-place.
    # Only top 6 photos · 8 s hard timeout each · 6 parallel workers.
    def _make_thumbnail_b64(image_path: str, max_dim: int = 512) -> str:
        try:
            from io import BytesIO
            import base64
            with Image.open(image_path) as img:
                img = ImageOps.exif_transpose(img)
                if img.mode != "RGB":
                    img = img.convert("RGB")
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
                buf = BytesIO()
                img.save(buf, format="JPEG", quality=75)
                return base64.b64encode(buf.getvalue()).decode("utf-8")
        except Exception:
            return ""

    def _vision_task(res):
        import concurrent.futures as _cf
        prompt = (
            "Analyze this travel photo for a cinematic reel. "
            "Return ONLY valid JSON (no markdown, no extra text) with these keys: "
            "aesthetic_score (0-10), smile_score (0-10), landmark_score (0-10), "
            "primary_emotion (string like Joyful/Serene/Adventurous)."
        )
        def _call():
            if not _make_thumbnail_b64(res["image_path"]):
                return
            raw  = utils.call_vision_llm(res["image_path"], prompt)
            
            # Robust JSON parsing since Vision models cannot use response_format={"type":"json_object"}
            cleaned_raw = raw.strip()
            if "```json" in cleaned_raw:
                cleaned_raw = cleaned_raw.split("```json")[1].split("```")[0].strip()
            elif "```" in cleaned_raw:
                cleaned_raw = cleaned_raw.split("```")[1].split("```")[0].strip()
            
            v = json.loads(cleaned_raw)
            bonus = (v.get("aesthetic_score", 0) * 0.8 +
                     v.get("smile_score",     0) * 0.7 +
                     v.get("landmark_score",  0) * 0.5)
            res["final_quality_score"] = min(100, res["final_quality_score"] + bonus)
            res["vision_data"]         = v
            if res.get("image_path") in refined_map:
                res["quality_label"] = f"{v.get('primary_emotion', 'Good')} · {v.get('aesthetic_score', 0)}/10 Beauty"
        try:
            with _cf.ThreadPoolExecutor(max_workers=1) as _ex:
                _ex.submit(_call).result(timeout=8)
        except Exception as e:
            print(f"[Vision] Skip {res['image_path']}: {e}")
            res["vision_data"] = None

    def _vision_background(candidates, results_list):
        print(f"[Vision] Background: Groq Vision on top {len(candidates)} photos…")
        with ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(_vision_task, candidates))
        results_list.sort(key=lambda x: x["final_quality_score"], reverse=True)
        print("[Vision] Background Groq Vision complete.")

    vision_candidates = final_results[:6]
    threading.Thread(
        target=_vision_background,
        args=(vision_candidates, final_results),
        daemon=True,
    ).start()

    # Return immediately — vision scores update in-place in background
    return {"ranked_results": final_results, "selected_images": selected_images}
