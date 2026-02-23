import cv2
import numpy as np
from PIL import Image, ImageOps
import io

def load_image_for_analysis(image_path: str, max_dim: int = 600) -> np.ndarray:
    """
    ULTRA-FAST image loader for quality analysis:
    - For RAW: Extracts embedded JPEG thumbnail (100x faster than development).
    - For Standard: Uses aggressive downsampling (600px).
    - Returns BGR array for OpenCV.
    """
    try:
        ext = image_path.lower().split('.')[-1]
        is_raw = ext in ['nef', 'cr2', 'arw', 'dng', 'raw', 'orf', 'sr2', 'raf', 'rw2', 'pef']

        if is_raw:
            import rawpy
            with rawpy.imread(image_path) as raw:
                try:
                    # Try extracting embedded thumbnail first - extremely fast
                    thumb = raw.extract_thumb()
                    if thumb.format == rawpy.ThumbFormat.JPEG:
                        img = Image.open(io.BytesIO(thumb.data))
                    else:
                        # Fallback to fast development if no JPEG thumb
                        rgb = raw.postprocess(use_camera_wb=True, half_size=True, no_auto_bright=True, fast_formatting=True)
                        img = Image.fromarray(rgb)
                except Exception:
                    # Last resort development
                    rgb = raw.postprocess(use_camera_wb=True, half_size=True, no_auto_bright=True, fast_formatting=True)
                    img = Image.fromarray(rgb)
        else:
            img = Image.open(image_path)

        # Fix orientation (Fast in PIL on small images)
        img = ImageOps.exif_transpose(img)
        
        # Aggressive down-sample for speed (600px is plenty for blur/sharpness)
        if max(img.size) > max_dim:
            img.thumbnail((max_dim, max_dim), Image.Resampling.NEAREST)

        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    except Exception as e:
        print(f"[Loader] FastLoad failed for {image_path}: {e}")
        return cv2.imread(image_path)
