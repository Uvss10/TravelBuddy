import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

def calculate_blur_score(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Returns blur score using Laplacian variance.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()

    return float(laplacian_var)
