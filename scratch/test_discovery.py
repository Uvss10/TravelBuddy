import requests
import time

URL = "http://127.0.0.1:8001/discovery/nearby"
PARAMS = {"location": "Jodhpur"}

print(f"Testing {URL}...")
try:
    start = time.time()
    response = requests.get(URL, params=PARAMS, timeout=120)
    end = time.time()
    print(f"Status: {response.status_code}")
    print(f"Time: {end - start:.2f}s")
    if response.status_code == 200:
        print("Success!")
        # print(response.json())
    else:
        print(f"Error: {response.text}")
except Exception as e:
    print(f"Request failed: {e}")
