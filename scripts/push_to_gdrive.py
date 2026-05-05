import os
import json
import webbrowser
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# SCOPES for Google Drive access
SCOPES = ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive.metadata.readonly']

# YOUR FOLDER ID
FOLDER_ID = '1sU2AWrjt4awlYBzcP6f97N-qMpAfr-Sq'

# FILE PATHS
APK_PATH = r"mobile\build\app\outputs\flutter-apk\app-release.apk"
VERSION_JSON_PATH = "version.json"

def get_credentials():
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            # Note: You need a 'client_secret.json' from Google Cloud Console to run this
            # Since we don't have it, I'll provide a simpler way if this fails.
            try:
                flow = InstalledAppFlow.from_client_secrets_file('client_secret.json', SCOPES)
                creds = flow.run_local_server(port=0)
            except FileNotFoundError:
                print("\n❌ Error: 'client_secret.json' not found.")
                print("1. Go to https://console.cloud.google.com/")
                print("2. Create a project and enable 'Google Drive API'")
                print("3. Create 'OAuth Client ID' (Desktop App)")
                print("4. Download the JSON and save it as 'client_secret.json' in this folder.")
                return None

        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    return creds

def upload_file(service, file_path, name, folder_id):
    print(f"Uploading {name}...")
    file_metadata = {'name': name, 'parents': [folder_id]}
    media = MediaFileUpload(file_path, resumable=True)
    file = service.files().create(body=file_metadata, media_body=media, fields='id').execute()
    print(f"✅ Success! File ID: {file.get('id')}")
    return file.get('id')

def push():
    creds = get_credentials()
    if not creds: return

    service = build('drive', 'v3', credentials=creds)

    # 1. Create version.json content
    version_data = {
        "latest_version": 5,
        "backend_url": "http://10.196.231.234:8000",
        "update_message": "History Delete & Global Search updates are live! 🚀"
    }

    # 2. Upload APK
    apk_id = upload_file(service, APK_PATH, 'app-release.apk', FOLDER_ID)
    
    # 3. Add APK URL to version data
    version_data["apk_url"] = f"https://docs.google.com/uc?export=download&id={apk_id}"

    # 4. Save and Upload version.json
    with open(VERSION_JSON_PATH, 'w') as f:
        json.dump(version_data, f, indent=2)
    
    json_id = upload_file(service, VERSION_JSON_PATH, 'version.json', FOLDER_ID)
    
    print("\n" + "="*40)
    print("✨ ALL UPDATES PUSHED TO GOOGLE DRIVE ✨")
    print(f"FOLDER: https://drive.google.com/drive/folders/{FOLDER_ID}")
    print(f"VERSION JSON ID: {json_id}")
    print("="*40)
    print("\nCopy the VERSION JSON ID and give it to me to finalize the app code!")

if __name__ == "__main__":
    push()
