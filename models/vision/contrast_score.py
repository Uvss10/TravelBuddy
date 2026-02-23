import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

def calculate_contrast_score(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Calculates contrast score using standard deviation of pixel intensities.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Standard deviation of pixel intensities
    contrast_score = np.std(gray)
    
    return float(contrast_score)
