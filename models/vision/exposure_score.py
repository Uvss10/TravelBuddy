import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

def calculate_exposure_score(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Calculates exposure balance score based on under/over-exposed pixel ratios.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    total_pixels = gray.size
    
    # Calculate ratios
    under_exposed = np.sum(gray < 20)
    over_exposed = np.sum(gray > 235)
    
    under_ratio = under_exposed / total_pixels
    over_ratio = over_exposed / total_pixels
    
    exposure_penalty = under_ratio + over_ratio
    exposure_score = 1.0 - exposure_penalty
    
    return max(0.0, exposure_score)
