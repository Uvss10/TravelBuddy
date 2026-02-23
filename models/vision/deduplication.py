import cv2
from models.vision.loader import load_image_for_analysis

def compute_phash(image_path, hash_size=8):
    """
    Compute a perceptual hash for an image.
    """
    image = load_image_for_analysis(image_path)
    if image is None:
        return None

    # Gradient-based dHash
    # Resize to (width=9, height=8) for 8x8 hash
    resized = cv2.resize(image, (hash_size + 1, hash_size))
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    
    # Compute differences between adjacent columns
    diff = gray[:, 1:] > gray[:, :-1]
    
    # Convert binary array to integer hash
    return sum([2**i for (i, v) in enumerate(diff.flatten()) if v])

def remove_duplicates(image_data, threshold=5):
    """
    Filters out near-duplicate images based on dHash from image_data list.
    image_data: List of dicts, each must have 'path' and 'sharpness' keys.
    Returns: Filtered list of image_data.
    
    Logic:
    1. Group images by hash similarity (Hamming distance <= threshold).
    2. In each group, keep the one with the highest sharpness score.
    """
    
    # Pre-compute hashes
    for img in image_data:
        img['phash'] = compute_phash(img['path'])
        
    unique_groups = []
    
    # Iterate through images and group them
    # Simple O(N^2) approach is fine for small batches (~100 images)
    # For large datasets, use BK-tree or similar
    
    processed_indices = set()
    
    for i in range(len(image_data)):
        if i in processed_indices:
            continue
            
        current_group = [image_data[i]]
        processed_indices.add(i)
        
        if image_data[i]['phash'] is None:
            unique_groups.append(image_data[i])
            continue

        for j in range(i + 1, len(image_data)):
            if j in processed_indices:
                continue
                
            if image_data[j]['phash'] is None:
                continue
                
            # Hamming distance (Check bit differences)
            hash1 = image_data[i]['phash']
            hash2 = image_data[j]['phash']
            hamming_dist = bin(hash1 ^ hash2).count('1')
            
            if hamming_dist <= threshold:
                current_group.append(image_data[j])
                processed_indices.add(j)
        
        # Select best image from group (highest sharpness)
        best_image = max(current_group, key=lambda x: x['sharpness'])
        unique_groups.append(best_image)
        
    return unique_groups
