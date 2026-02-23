import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

def calculate_entropy_score(image_path: str = None, image: np.ndarray = None) -> float:
    """
    Calculates Shannon entropy from grayscale histogram.
    """
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Calculate histogram
    hist = cv2.calcHist([gray], [0], None, [256], [0, 256])
    
    # Normalize histogram to get probabilities
    hist_norm = hist.flatten() / hist.sum()
    
    # Filter out zero probabilities to avoid log(0)
    probabilities = hist_norm[hist_norm > 0]
    
    # Calculate entropy manually
    entropy = -np.sum(probabilities * np.log2(probabilities))
    
    return float(entropy)
