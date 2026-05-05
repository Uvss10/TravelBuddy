import os
import urllib.request
import urllib.error
from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "ok"}

@router.get("/version")
def get_version():
    """
    Over-The-Air (OTA) Update Endpoint.

    HOW TO PUSH AN UPDATE TO ALL USERS:
    ─────────────────────────────────────
    1.  Build new APK:  flutter build apk --release  (in mobile/)
    2.  Upload APK to Google Drive → Share → "Anyone with the link" → Copy Link ID
        Link ID is the part after /d/ and before /view in the share URL.
        e.g. https://drive.google.com/file/d/THIS_PART_HERE/view
    3.  Paste the ID into DRIVE_FILE_ID below.
    4.  Bump LATEST_VERSION (e.g. "2.0.0" → "2.1.0").
    5.  Save this file. Every user gets the update dialog on next app launch.
    ─────────────────────────────────────
    """

    # ── EDIT ONLY THESE TWO LINES TO PUSH AN UPDATE ──────────────────────────
    LATEST_VERSION = "2.0.0"
    DRIVE_FILE_ID  = "YOUR_GOOGLE_DRIVE_FILE_ID_HERE"  # Paste your Drive file ID
    # ─────────────────────────────────────────────────────────────────────────

    RELEASE_NOTES  = (
        "✨ Dynamic IP: App auto-discovers backend — no more rebuild on IP change.\n"
        "🔒 Stay Logged In: Session is now persistent across restarts.\n"
        "🚀 OTA Updates: You are now receiving over-the-air updates!"
    )
    IS_MANDATORY   = True   # True = user MUST update before using the app

    # Constructs a direct-download URL (bypasses Google Drive preview page)
    apk_url = f"https://drive.google.com/uc?export=download&id={DRIVE_FILE_ID}"

    return {
        "latest_version": LATEST_VERSION,
        "is_mandatory":   IS_MANDATORY,
        "release_notes":  RELEASE_NOTES,
        "apk_url":        apk_url,
    }


@router.post("/llm/toggle_mode")
def toggle_llm_mode():
    from backend import utils
    current = utils.get_prefer_local()
    new_val = not current
    new_str = 'true' if new_val else 'false'

    # 1. Update in-process os.environ immediately (no restart required)
    os.environ["PREFER_LOCAL_LLM"] = new_str

    # 2. Persist to .env so it survives server restarts
    try:
        env_path = utils._ENV_PATH
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except FileNotFoundError:
            lines = []

        found = False
        new_lines = []
        for line in lines:
            if line.startswith("PREFER_LOCAL_LLM="):
                new_lines.append(f"PREFER_LOCAL_LLM={new_str}\n")
                found = True
            else:
                new_lines.append(line)
        if not found:
            new_lines.append(f"\nPREFER_LOCAL_LLM={new_str}\n")

        with open(env_path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

        print(f"[LLM] .env updated: PREFER_LOCAL_LLM={new_str}")
    except Exception as e:
        print(f"[LLM] Failed to persist preference to .env: {e}")

    print(f"[LLM] Mode toggled => prefer_local={new_val}")
    return {
        "prefer_local": new_val,
        "mode": "local" if new_val else "cloud",
        "message": f"Switched to {'Local AI (Private)' if new_val else 'Cloud API (Fast)'}"
    }


@router.get("/llm/status")
def llm_status():
    """
    Returns which LLM provider is active.
    Frontend polls this to display the AI mode pill in the header.
    """
    from backend import utils

    groq_key = utils.get_groq_key()
    FAKE_KEYS = {"", "your_groq_api_key_here", "your_key", "your_groq_key", "none"}
    groq_ready = bool(groq_key) and groq_key.lower() not in FAKE_KEYS

    ollama_ready = False
    try:
        urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=1)
        ollama_ready = True
    except Exception:
        pass

    # Read preference fresh from os.environ (updated in-process by toggle)
    prefer_local = os.environ.get("PREFER_LOCAL_LLM", "false").lower() == "true"

    # Determine active provider based on preference + availability
    if prefer_local and ollama_ready:
        provider = "ollama"
        label    = "[LOCAL] Local AI (Private)"
        detail   = "Ollama running locally — 100% private. Click to switch to Cloud API (Fast)."
    elif prefer_local and not ollama_ready and groq_ready:
        # Prefer local but Ollama offline — using cloud as fallback
        provider = "groq"
        label    = "[CLOUD] Cloud Fallback"
        detail   = "Prefer Local set but Ollama not running — falling back to Cloud (Groq). Start Ollama to go private."
    elif groq_ready:
        provider = "groq"
        label    = "[CLOUD] Cloud API (Fast)"
        detail   = "Using Groq API for fast responses. Click to switch to Local AI (Private)."
    elif ollama_ready:
        provider = "ollama"
        label    = "[LOCAL] Local AI (Private)"
        detail   = "Using Ollama locally. Click to switch to Cloud API (Fast)."
    else:
        provider = "mock"
        label    = "[OFFLINE] Offline Mode"
        detail   = "No AI connected. Add GROQ_API_KEY to .env or start Ollama to enable AI."

    return {
        "provider":     provider,
        "label":        label,
        "detail":       detail,
        "groq_ready":   groq_ready,
        "ollama_ready": ollama_ready,
        "prefer_local": prefer_local,
    }
