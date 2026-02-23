import os
import urllib.request
import urllib.error
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "ok"}


@router.post("/llm/toggle_mode")
def toggle_llm_mode():
    from backend import utils
    current = utils.get_prefer_local()
    new_val = not current
    
    # Persist to .env so it survives reloads and is picked up by get_prefer_local()
    try:
        with open(utils._ENV_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()
        
        found = False
        with open(utils._ENV_PATH, "w", encoding="utf-8") as f:
            for line in lines:
                if line.startswith("PREFER_LOCAL_LLM="):
                    f.write(f"PREFER_LOCAL_LLM={'true' if new_val else 'false'}\n")
                    found = True
                else:
                    f.write(line)
            if not found:
                f.write(f"\nPREFER_LOCAL_LLM={'true' if new_val else 'false'}\n")
    except Exception as e:
        print(f"[LLM] Failed to persist preference: {e}")

    print(f"[LLM] Mode toggled. Prefer Local: {new_val}")
    return {"prefer_local": new_val}


@router.get("/llm/status")
def llm_status():
    """
    Returns which LLM provider is ready to use.
    Frontend calls this on load to show a status badge.
    """
    from backend import utils
    groq_key = utils.get_groq_key()
    # Check for empty or common placeholder strings
    is_fake = not groq_key or groq_key.lower() in ["", "your_groq_api_key_here", "your_key", "your_groq_key"]
    groq_ready = not is_fake

    ollama_ready = False
    try:
        urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=2)
        ollama_ready = True
    except Exception:
        pass

    current_preference = utils.get_prefer_local()

    if ollama_ready and current_preference:
        provider = "ollama"
        label    = "Mode: Local AI (Private)"
        detail   = "Running on your CPU. Slow but 100% Private. CLICK to switch to Cloud API (Fast)."
    elif groq_ready:
        provider = "groq"
        label    = "Mode: Cloud API (Fast)"
        detail   = "Using Groq for lightning speed. CLICK to switch to Local AI (Private)."
    else:
        provider = "mock"
        label    = "Offline: No AI Found"
        detail   = "Add your Groq Key to .env or start Ollama to enable AI."

    return {
        "provider":     provider,
        "label":        label,
        "detail":       detail,
        "groq_ready":   groq_ready,
        "ollama_ready": ollama_ready,
        "prefer_local": current_preference,
    }
