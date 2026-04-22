import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

# Global cache for the classifier to avoid reloading XML for every single photo (HUGE speed boost)
_FACE_CASCADE = None

def _get_cascade():
    global _FACE_CASCADE
    if _FACE_CASCADE is None:
        path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        _FACE_CASCADE = cv2.CascadeClassifier(path)
    return _FACE_CASCADE

def detect_faces(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Detects faces using cached Haar Cascade. Fast and optimized for batches.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    try:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        cascade = _get_cascade()
        
        if cascade.empty():
            return 0.0
            
        faces = cascade.detectMultiScale(
            gray,
            scaleFactor=1.3, # Faster than 1.1
            minNeighbors=4,
            minSize=(20, 20)
        )
        
        num_faces = len(faces)
        if num_faces == 0:
            return 0.0
            
        image_area = gray.shape[0] * gray.shape[1]
        max_face_area = 0
        for (x, y, w, h) in faces:
            max_face_area = max(max_face_area, w * h)
                
        relative_size = max_face_area / image_area
        return float((np.log1p(num_faces) * 0.4) + (relative_size * 0.6) * 10)
    except Exception:
        return 0.0
