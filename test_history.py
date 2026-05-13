import requests
import json
import uuid

url = "http://localhost:8000/history/save"
data = {
    "user_id": str(uuid.uuid4()),
    "destination": "Test",
    "title": "Test Title",
    "narration": "Test Narration",
    "captions": [],
    "hashtags": [],
    "video_url": None,
    "itinerary_output": "test output"
}

try:
    response = requests.post(url, json=data)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
