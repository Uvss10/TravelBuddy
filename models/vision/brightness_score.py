import cv2
import numpy as np

def calculate_brightness(image_path: str) -> float:
    image = cv2.imread(image_path)
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return float(np.mean(gray))
