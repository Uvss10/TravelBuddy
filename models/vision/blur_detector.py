import cv2

def calculate_blur_score(image_path: str) -> float:
    """
    Returns blur score using Laplacian variance.
    Lower value = more blurry.
    Higher value = sharper.
    """
    image = cv2.imread(image_path)
    
    if image is None:
        return 0.0

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()

    return laplacian_var
