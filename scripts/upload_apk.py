import os
import sys
from supabase import create_client, Client

# Hardcoded from .env for this one-time task
SUPABASE_URL = "https://nevijvoyvxcquvueabrp.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ldmlqdm95dnhjcXV2dWVhYnJwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Njg0MTExNSwiZXhwIjoyMDkyNDE3MTE1fQ.Cvna-ZPIdM7QSmFca8gIMRKS-0adyu8VUYszsNXUtSU"

APK_PATH = r"c:\Users\mansi\TravelBuddy\mobile\build\app\outputs\flutter-apk\app-release.apk"
BUCKET_NAME = "app-updates"
DEST_PATH = "app-release.apk"

def upload():
    if not os.path.exists(APK_PATH):
        print(f"Error: APK file not found at {APK_PATH}")
        return

    print(f"Connecting to Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    print(f"Uploading {APK_PATH} to bucket '{BUCKET_NAME}'...")
    try:
        with open(APK_PATH, 'rb') as f:
            response = supabase.storage.from_(BUCKET_NAME).upload(
                path=DEST_PATH,
                file=f,
                file_options={"cache-control": "3600", "upsert": "true"}
            )
        print(f"Success! File uploaded to {BUCKET_NAME}/{DEST_PATH}")
        print(f"Public URL: {SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{DEST_PATH}")
    except Exception as e:
        print(f"Failed to upload: {e}")

if __name__ == "__main__":
    upload()
