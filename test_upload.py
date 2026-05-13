import requests
import json
import os

url = "http://localhost:8000/images/upload"

# Create a dummy image
os.makedirs("test_images", exist_ok=True)
with open("test_images/test.jpg", "wb") as f:
    f.write(b"fake image data")

files = [
    ("files", ("test.jpg", open("test_images/test.jpg", "rb"), "image/jpeg"))
]

try:
    response = requests.post(url, files=files)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
