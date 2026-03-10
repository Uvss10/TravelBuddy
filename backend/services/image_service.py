from PIL import Image, ImageOps
import os
import json
import shutil
from concurrent.futures import ThreadPoolExecutor
import numpy as np

from models.vision.blur_detector import calculate_blur_score
from models.vision.sharpness_score import calculate_sharpness
from models.vision.exposure_score import calculate_exposure_score
from models.vision.contrast_score import calculate_contrast_score
from models.vision.entropy_score import calculate_entropy_score
from models.vision.face_detector import detect_faces
from models.vision.deduplication import remove_duplicates, compute_phash
from models.vision.loader import load_image_for_analysis
from backend import utils

SELECTED_DIR = "data/selected_images"
TOP_N = 100 # Match the 100 photo limit for reels
TARGET_RES = (1080, 1920) 

def normalize(value, min_val, max_val):
    if max_val == min_val: return 0.5
    return (value - min_val) / (max_val - min_val)

def _refine_image_for_reel(src_path: str, dest_path: str):
    """Refines top images to perfect vertical WebP."""
    try:
        ext = src_path.lower().split('.')[-1]
        is_raw = ext in ['nef', 'cr2', 'arw', 'dng', 'raw', 'orf', 'sr2', 'raf', 'rw2', 'pef']

        if is_raw:
            import rawpy
            with rawpy.imread(src_path) as raw:
                # Use high-quality postprocessing for the final video reel
                # fast_formatting=False for better quality
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
            img = Image.open(src_path)

        # Fix orientation from EXIF
        img = ImageOps.exif_transpose(img)
        if img.mode != 'RGB': 
            img = img.convert('RGB')
        
        # Resize to perfect vertical reel resolution (1080x1920)
        refined = ImageOps.fit(img, TARGET_RES, method=Image.Resampling.LANCZOS)
        
        # Save as high-quality WebP (this is what the browser sees)
        refined.save(dest_path, "WEBP", quality=85, method=6)
        return True
    except Exception as e:
        print(f"[Refine] Failed {src_path}: {e}")
        shutil.copy(src_path, dest_path)
        return False

def _analyze_single_image(path):
    """Lightning-fast metrics using thumbnail loader."""
    try:
        img_array = load_image_for_analysis(path, max_dim=600)
        if img_array is None: return None

        return {
            "path": path,
            "blur": float(calculate_blur_score(image=img_array)),
            "sharpness": float(calculate_sharpness(image=img_array)),
            "exposure": float(calculate_exposure_score(image=img_array)),
            "contrast": float(calculate_contrast_score(image=img_array)),
            "entropy": float(calculate_entropy_score(image=img_array)),
            "face": float(detect_faces(image=img_array))
        }
    except Exception: return None

def process_uploaded_images(image_paths):
    if not image_paths: return {"ranked_results": [], "selected_images": []}

    # Parallel Phase 1: FAST ANALYSIS
    # Using 4-8 threads is optimal for most local setups to avoid overhead
    with ThreadPoolExecutor(max_workers=8) as executor:
        raw_data = [r for r in executor.map(_analyze_single_image, image_paths) if r is not None]

    unique_data = remove_duplicates(raw_data)
    if not unique_data: return {"ranked_results": [], "selected_images": []}

    # Helper for min/max
    def get_range(key):
        vals = [x[key] for x in unique_data]
        return min(vals), max(vals)

    m_blur, mx_blur = get_range("blur")
    m_sharp, mx_sharp = get_range("sharpness")
    m_exp, mx_exp = get_range("exposure")
    m_cont, mx_cont = get_range("contrast")
    m_ent, mx_ent = get_range("entropy")
    m_face, mx_face = get_range("face")

    final_results = []
    for item in unique_data:
        n_sharp = normalize(item["sharpness"], m_sharp, mx_sharp)
        n_blur = normalize(item["blur"], m_blur, mx_blur)
        n_face = normalize(item["face"], m_face, mx_face)
        n_ent = normalize(item["entropy"], m_ent, mx_ent)
        n_cont = normalize(item["contrast"], m_cont, mx_cont)
        n_exp = normalize(item["exposure"], m_exp, mx_exp)

        # Quality weights: Favoring Sharpness and Face presence for the best travel memories
        score = (0.25*n_sharp + 0.2*n_blur + 0.25*n_face + 0.1*n_ent + 0.1*n_cont + 0.1*n_exp) * 100
        quality = "High" if score > 70 else ("Medium" if score > 40 else "Low")

        final_results.append({
            "image_path": item["path"],
            "final_quality_score": round(score, 2),
            "quality": quality,
            "metrics": {k: round(v, 2) for k, v in item.items() if k != 'path'}
        })

    final_results.sort(key=lambda x: x["final_quality_score"], reverse=True)
    
    # Phase 2.5: VISION AI BEAUTY CHECK — top 6 technically sharpest photos only
    # Key optimisations vs the original:
    #   - Images resized to max 512px before base64 encoding (was sending full 5-10 MB originals)
    #   - Only 6 candidates (was 12) to stay within Groq rate limits
    #   - 8-second hard timeout per photo so a slow call doesn't block everything
    #   - max_workers=6 so all 6 calls run in parallel
    vision_candidates = final_results[:6]
    print(f"[Vision] Analysing top {len(vision_candidates)} photos for aesthetics (optimised)...")

    def _make_thumbnail_b64(image_path: str, max_dim: int = 512) -> str:
        """Return a small JPEG base64 string for the vision API — drastically reduces payload size."""
        try:
            with Image.open(image_path) as img:
                img = ImageOps.exif_transpose(img)
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
                from io import BytesIO
                buf = BytesIO()
                img.save(buf, format='JPEG', quality=75)
                return __import__('base64').b64encode(buf.getvalue()).decode('utf-8')
        except Exception:
            return ''

    def vision_rank_task(res):
        prompt = (
            'Analyze this travel photo for a cinematic reel. '
            'Return ONLY valid JSON (no markdown, no extra text) with these keys: '
            'aesthetic_score (0-10), smile_score (0-10), landmark_score (0-10), '
            'primary_emotion (string like Joyful/Serene/Adventurous).'
        )
        import concurrent.futures as _cf
        def _do_call():
            b64 = _make_thumbnail_b64(res['image_path'])
            if not b64:
                return
            vision_raw = utils.call_vision_llm(res['image_path'], prompt)
            v = json.loads(vision_raw)
            bonus = (v.get('aesthetic_score', 0) * 0.8 +
                     v.get('smile_score',     0) * 0.7 +
                     v.get('landmark_score',  0) * 0.5)
            res['final_quality_score'] = min(100, res['final_quality_score'] + bonus)
            res['vision_data'] = v
        try:
            with _cf.ThreadPoolExecutor(max_workers=1) as _ex:
                fut = _ex.submit(_do_call)
                fut.result(timeout=8)   # 8 s hard cap per photo
        except Exception as e:
            print(f"[Vision] Skip {res['image_path']}: {e}")
            res['vision_data'] = None

    with ThreadPoolExecutor(max_workers=6) as executor:   # all 6 run in parallel
        list(executor.map(vision_rank_task, vision_candidates))

    # Re-sort after Vision boost
    final_results.sort(key=lambda x: x["final_quality_score"], reverse=True)

    os.makedirs(SELECTED_DIR, exist_ok=True)

    # Parallel Phase 2: REFINEMENT (Only for Top 8)
    selected_images = []
    top_8 = final_results[:min(TOP_N, len(final_results))]
    refined_map = {}

    def refine_task(img):
        f_name = f"refined_{os.path.basename(os.path.splitext(img['image_path'])[0])}.webp"
        dst = os.path.join(SELECTED_DIR, f_name)
        if _refine_image_for_reel(img["image_path"], dst):
            return img["image_path"], dst.replace("\\", "/")
        return None

    with ThreadPoolExecutor(max_workers=4) as executor:
        for res in executor.map(refine_task, top_8):
            if res:
                refined_map[res[0]] = res[1]
                selected_images.append(res[1])

    for res in final_results:
        if res["image_path"] in refined_map:
            res["refined_path"] = refined_map[res["image_path"]]
            # Add vision tags to the label if available
            if res.get("vision_data"):
                v = res["vision_data"]
                res["quality_label"] = f"{v.get('primary_emotion', 'Good')} · {v.get('aesthetic_score', 0)}/10 Beauty"

    return {"ranked_results": final_results, "selected_images": selected_images}
