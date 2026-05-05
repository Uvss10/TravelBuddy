"""
scripts/release.py — TravelBuddy One-Command Release Pipeline
═══════════════════════════════════════════════════════════════

USAGE (from the project root — c:\\Users\\mansi\\TravelBuddy):
    python scripts/release.py

WHAT IT DOES (fully automatic, zero manual steps):
  1.  Reads current build number from mobile/pubspec.yaml
  2.  Bumps the build number by +1  (1.0.0+5 → 1.0.0+6)
  3.  Runs: flutter build apk --release  (inside mobile/)
  4.  Deletes old APK from Google Drive (the previous version)
  5.  Uploads new APK to Google Drive  → makes it public
  6.  Updates version.json with new build number + Drive APK URL
  7.  Updates backend/api/health.py with the new build number
  8.  Prints the public APK URL so you can verify it

When users next open the old APK:
  • Splash screen calls GET /version
  • Backend returns the new build number
  • App shows "Update Available" dialog with download button
  • User taps → browser downloads the new APK from Drive
"""

import os
import re
import sys
import json
import subprocess
from pathlib import Path

# Force UTF-8 output on Windows (avoids UnicodeEncodeError in PowerShell)
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# ── Google Drive Auth ─────────────────────────────────────────────────────────
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG — edit once, never touch again
# ─────────────────────────────────────────────────────────────────────────────
ROOT          = Path(__file__).resolve().parent.parent   # c:\Users\mansi\TravelBuddy
MOBILE_DIR    = ROOT / "mobile"
PUBSPEC       = MOBILE_DIR / "pubspec.yaml"
APK_SRC       = MOBILE_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
VERSION_JSON  = ROOT / "version.json"
HEALTH_PY     = ROOT / "backend" / "api" / "health.py"
CLIENT_SECRET = ROOT / "client_secret.json"
TOKEN_FILE    = ROOT / "token.json"
DRIVE_FOLDER  = "1sU2AWrjt4awlYBzcP6f97N-qMpAfr-Sq"   # your existing Drive folder
APK_FILENAME  = "app-release.apk"

SCOPES = [
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/drive.metadata.readonly",
]

SEPARATOR = "=" * 60


# ─────────────────────────────────────────────────────────────────────────────
# -----------------------------------------------------------------------------
# STEP 0: Pretty logger
# -----------------------------------------------------------------------------
def log(msg: str, icon: str = "▶"):
    print(f"\n{icon}  {msg}")

def ok(msg: str):
    print(f"   [OK] {msg}")

def fail(msg: str):
    print(f"\n   [FATAL] {msg}")
    sys.exit(1)


# -----------------------------------------------------------------------------
# STEP 1: Bump version in pubspec.yaml
# -----------------------------------------------------------------------------
def bump_version() -> tuple[str, int, str]:
    """Returns (new_version_string, new_build_number, original_pubspec_text)."""
    log("Reading current version from pubspec.yaml", "📋")
    original_text = PUBSPEC.read_text(encoding="utf-8")

    match = re.search(r"^version:\s+(\d+\.\d+\.\d+)\+(\d+)", original_text, re.MULTILINE)
    if not match:
        fail("Could not find 'version: x.y.z+N' in pubspec.yaml")

    semver      = match.group(1)
    old_build   = int(match.group(2))
    new_build   = old_build + 1
    new_ver_str = f"{semver}+{new_build}"

    updated = original_text.replace(
        f"version: {semver}+{old_build}",
        f"version: {semver}+{new_build}",
    )
    PUBSPEC.write_text(updated, encoding="utf-8")

    ok(f"Version bumped: {semver}+{old_build}  →  {new_ver_str}")
    return new_ver_str, new_build, original_text


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Build release APK
# ─────────────────────────────────────────────────────────────────────────────
def build_apk(original_pubspec_text: str):
    """
    Runs flutter build apk --release.
    On failure, rolls back pubspec.yaml to avoid a phantom version bump.
    Uses shell=True so Python finds flutter.bat on Windows PATH.
    """
    log("Building Flutter release APK (this takes 2–4 minutes)…", "🔨")
    result = subprocess.run(
        "flutter build apk --release",
        cwd=str(MOBILE_DIR),
        shell=True,   # Required on Windows: flutter is a .bat file
        text=True,
    )
    if result.returncode != 0:
        # Rollback the version bump so retrying starts from the same number
        PUBSPEC.write_text(original_pubspec_text, encoding="utf-8")
        fail("flutter build apk failed. pubspec.yaml has been restored. Fix the error above and retry.")
    if not APK_SRC.exists():
        PUBSPEC.write_text(original_pubspec_text, encoding="utf-8")
        fail(f"APK not found after build: {APK_SRC}  — pubspec.yaml restored.")
    size_mb = APK_SRC.stat().st_size / (1024 * 1024)
    ok(f"APK built successfully ({size_mb:.1f} MB)")


# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Authenticate with Google Drive
# ─────────────────────────────────────────────────────────────────────────────
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
            # First-time: opens browser once to authorize, then saves token.json
            flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_SECRET), SCOPES)
            creds = flow.run_local_server(port=0)
            ok("Browser auth completed.")
        TOKEN_FILE.write_text(creds.to_json())

    ok("Google Drive authenticated.")
    return build("drive", "v3", credentials=creds)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Delete old APK from Drive, upload new one
# ─────────────────────────────────────────────────────────────────────────────
def upload_apk_to_drive(service) -> str:
    """Returns the public direct-download URL of the newly uploaded APK."""
    log("Uploading APK to Google Drive (57 MB — may take a few minutes)...", "")

    # Delete any existing APK with the same name in the folder
    existing = service.files().list(
        q=f"name='{APK_FILENAME}' and '{DRIVE_FOLDER}' in parents and trashed=false",
        fields="files(id, name)",
    ).execute().get("files", [])

    for f in existing:
        service.files().delete(fileId=f["id"]).execute()
        print(f"   [DEL] Deleted old APK from Drive (id={f['id']})")

    # Upload new APK with progress reporting
    metadata = {"name": APK_FILENAME, "parents": [DRIVE_FOLDER]}
    media    = MediaFileUpload(
        str(APK_SRC),
        mimetype="application/vnd.android.package-archive",
        resumable=True,
        chunksize=5 * 1024 * 1024,   # 5 MB chunks
    )
    request  = service.files().create(body=metadata, media_body=media, fields="id")

    apk_id   = None
    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            pct = int(status.progress() * 100)
            print(f"   Uploading... {pct}%", end="\r", flush=True)

    apk_id = response["id"]
    print()   # newline after progress

    # Make public
    service.permissions().create(
        fileId=apk_id,
        body={"type": "anyone", "role": "reader"},
    ).execute()

    apk_url = f"https://drive.google.com/uc?export=download&id={apk_id}"
    print(f"   [OK] APK uploaded and made public.")
    print(f"   [OK] APK Download URL: {apk_url}")
    return apk_url


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Update version.json (the local config file)
# ─────────────────────────────────────────────────────────────────────────────
def update_version_json(new_build: int, apk_url: str):
    log("Updating version.json…", "📝")

    # Read backend_url from existing version.json if available
    existing_url = "http://10.196.231.234:8000"
    if VERSION_JSON.exists():
        try:
            existing = json.loads(VERSION_JSON.read_text())
            existing_url = existing.get("backend_url", existing_url)
        except Exception:
            pass

    data = {
        "latest_version": new_build,
        "backend_url":    existing_url,
        "apk_url":        apk_url,
        "update_message": f"TravelBuddy v{new_build} is here! Update now for the latest features. 🚀",
    }
    VERSION_JSON.write_text(json.dumps(data, indent=4))
    ok(f"version.json updated with build={new_build}")


# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Patch backend/api/health.py with new build number + APK URL
# ─────────────────────────────────────────────────────────────────────────────
def patch_health_py(new_build: int, apk_url: str):
    log("Patching backend/api/health.py…", "⚙️")
    text = HEALTH_PY.read_text(encoding="utf-8")

    # Replace LATEST_VERSION
    text = re.sub(
        r"LATEST_VERSION\s*=\s*.+",
        f'LATEST_VERSION = {new_build}',
        text,
    )
    # Replace DRIVE_FILE_ID (extract ID from apk_url)
    drive_file_id = apk_url.split("id=")[-1]
    text = re.sub(
        r"DRIVE_FILE_ID\s*=\s*.+",
        f'DRIVE_FILE_ID  = "{drive_file_id}"',
        text,
    )
    HEALTH_PY.write_text(text, encoding="utf-8")
    ok(f"health.py → LATEST_VERSION = {new_build}, DRIVE_FILE_ID = {drive_file_id}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"\n{SEPARATOR}")
    print("  TravelBuddy Automated Release Pipeline")
    print(SEPARATOR)

    new_ver_str, new_build, original_pubspec = bump_version()
    build_apk(original_pubspec)
    service  = get_drive_service()
    apk_url  = upload_apk_to_drive(service)
    update_version_json(new_build, apk_url)
    patch_health_py(new_build, apk_url)

    print(f"\n{SEPARATOR}")
    print(f"  🚀 RELEASE v{new_ver_str} COMPLETE!")
    print(f"{SEPARATOR}")
    print(f"  Build Number : {new_build}")
    print(f"  APK URL      : {apk_url}")
    print(f"\n  ✅ Old APK users will see the update dialog on next launch.")
    print(f"  ✅ No manual steps required.")
    print(f"  ✅ Restart your FastAPI backend to serve the new /version data.")
    print(f"\n  To restart backend:  uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload")
    print(SEPARATOR + "\n")
