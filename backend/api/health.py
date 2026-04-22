import os
import urllib.request
import urllib.error
from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "ok"}


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
