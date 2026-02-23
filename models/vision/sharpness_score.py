import cv2
import numpy as np
from models.vision.loader import load_image_for_analysis

def calculate_sharpness(image_path: str = None, image: np.ndarray = None) -> float:
    if image is None and image_path:
        image = load_image_for_analysis(image_path)
        
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1)

    magnitude = np.sqrt(sobelx**2 + sobely**2)
    return float(np.mean(magnitude))
