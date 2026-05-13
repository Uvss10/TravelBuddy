
import os
import re
import sys
import json
import io
from pathlib import Path

# Force UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Google Drive Auth
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# CONFIG
ROOT          = Path(__file__).resolve().parent.parent
MOBILE_DIR    = ROOT / "mobile"
PUBSPEC       = MOBILE_DIR / "pubspec.yaml"
APK_SRC       = MOBILE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
VERSION_JSON  = ROOT / "version.json"
HEALTH_PY     = ROOT / "backend" / "api" / "health.py"
CLIENT_SECRET = ROOT / "client_secret.json"
TOKEN_FILE    = ROOT / "token.json"
DRIVE_FOLDER  = "1sU2AWrjt4awlYBzcP6f97N-qMpAfr-Sq"
APK_FILENAME  = "app-release.apk"

SCOPES = [
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/drive.metadata.readonly",
]

def log(msg: str, icon: str = "▶"):
    print(f"\n{icon}  {msg}")

def ok(msg: str):
    print(f"   [OK] {msg}")

def fail(msg: str):
    print(f"\n   [FATAL] {msg}")
    sys.exit(1)

def get_drive_service():
    log("Authenticating with Google Drive…", "🔑")
    if not CLIENT_SECRET.exists():
        fail(f"client_secret.json not found at {CLIENT_SECRET}")

    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
            ok("Token refreshed from cache.")
        else:
            flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_SECRET), SCOPES)
            creds = flow.run_local_server(port=0)
            ok("Browser auth completed.")
        TOKEN_FILE.write_text(creds.to_json())

    ok("Google Drive authenticated.")
    return build("drive", "v3", credentials=creds)

def upload_apk_to_drive(service) -> str:
    log("Uploading EXISTING APK to Google Drive...", "")
    if not APK_SRC.exists():
        fail(f"APK not found at {APK_SRC}")

    existing = service.files().list(
        q=f"name='{APK_FILENAME}' and '{DRIVE_FOLDER}' in parents and trashed=false",
        fields="files(id, name)",
    ).execute().get("files", [])

    for f in existing:
        try:
            service.files().delete(fileId=f["id"]).execute()
            print(f"   [DEL] Deleted old APK from Drive (id={f['id']})")
        except Exception as e:
            print(f"   [WARN] Could not delete old APK ({f['id']}): {e}")

    metadata = {"name": APK_FILENAME, "parents": [DRIVE_FOLDER]}
    media    = MediaFileUpload(
        str(APK_SRC),
        mimetype="application/vnd.android.package-archive",
        resumable=True,
        chunksize=5 * 1024 * 1024,
    )
    request  = service.files().create(body=metadata, media_body=media, fields="id")

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            pct = int(status.progress() * 100)
            print(f"   Uploading... {pct}%", end="\r", flush=True)

    apk_id = response["id"]
    print()
    service.permissions().create(fileId=apk_id, body={"type": "anyone", "role": "reader"}).execute()
    apk_url = f"https://drive.google.com/uc?export=download&id={apk_id}"
    ok(f"APK uploaded: {apk_url}")
    return apk_url

def update_version_json(new_build: int, apk_url: str):
    log("Updating version.json…", "📝")
    existing_url = "http://10.249.251.50:8000"
    if VERSION_JSON.exists():
        try:
            existing = json.loads(VERSION_JSON.read_text())
            existing_url = existing.get("backend_url", existing_url)
        except: pass
    data = {
        "latest_version": new_build,
        "backend_url":    existing_url,
        "apk_url":        apk_url,
        "update_message": f"TravelBuddy v{new_build} is here! Update now for the latest features. 🚀",
    }
    VERSION_JSON.write_text(json.dumps(data, indent=4))
    ok(f"version.json updated with build={new_build}")

def patch_health_py(new_build: int, apk_url: str):
    log("Patching backend/api/health.py…", "⚙️")
    text = HEALTH_PY.read_text(encoding="utf-8")
    text = re.sub(r"LATEST_VERSION\s*=\s*.+", f'LATEST_VERSION = {new_build}', text)
    drive_file_id = apk_url.split("id=")[-1]
    text = re.sub(r"DRIVE_FILE_ID\s*=\s*.+", f'DRIVE_FILE_ID  = "{drive_file_id}"', text)
    HEALTH_PY.write_text(text, encoding="utf-8")
    ok(f"health.py updated.")

if __name__ == "__main__":
    # Get current build number from pubspec
    text = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"^version:\s+(\d+\.\d+\.\d+)\+(\d+)", text, re.MULTILINE)
    if not match: fail("Could not find version in pubspec.yaml")
    build_num = int(match.group(2))
    
    service = get_drive_service()
    apk_url = upload_apk_to_drive(service)
    update_version_json(build_num, apk_url)
    patch_health_py(build_num, apk_url)
    print(f"\n🚀 UPLOAD COMPLETE! APK URL: {apk_url}")
