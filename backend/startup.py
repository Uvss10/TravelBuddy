"""
backend/startup.py — Auto IP Registration on Server Start

Every time you run the backend, this script:
  1. Detects the laptop's current Wi-Fi IPv4 address.
  2. Pushes it to Supabase → app_config table (key = 'backend_url').
  3. The mobile app reads this on launch — always connects to the right IP.

Usage:
  python backend/startup.py        # update IP then exit
  python backend/startup.py --run  # update IP then start uvicorn
"""

import os
import socket
import sys
import subprocess
from pathlib import Path

# ── Load .env ──────────────────────────────────────────────────────────────────
_ROOT = Path(__file__).resolve().parent.parent
_ENV  = _ROOT / ".env"

def _load_env():
    if not _ENV.exists():
        return
    with open(_ENV, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

_load_env()

PORT = int(os.getenv("BACKEND_PORT", "8080"))

# ── Detect Wi-Fi IP ────────────────────────────────────────────────────────────
def get_local_ip() -> str:
    """Return the machine's outbound IPv4 address (what the phone will use)."""
    try:
        # Connect to a public address just to find the right interface; no data sent
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


# ── Push URL to Supabase ───────────────────────────────────────────────────────
def update_supabase(url: str) -> bool:
    supabase_url = os.getenv("SUPABASE_URL", "")
    # Service role key bypasses Row Level Security — needed for server-side writes
    supabase_key = (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or
                    os.getenv("SUPABASE_SERVICE_KEY") or
                    os.getenv("SUPABASE_KEY", ""))

    if not supabase_url or not supabase_key:
        print("[Startup] SUPABASE_URL / SUPABASE_KEY not set -- skipping Supabase update.")
        return False

    try:
        from supabase import create_client
        client = create_client(supabase_url, supabase_key)

        # Upsert into app_config: key='backend_url', value=<url>
        client.table("app_config").upsert(
            {"key": "backend_url", "value": url},
            on_conflict="key"
        ).execute()

        print(f"[Startup] OK  Supabase updated: backend_url = {url}")
        return True
    except Exception as e:
        print(f"[Startup] WARN Supabase update failed: {e}")
        print("[Startup] TIP: Set SUPABASE_SERVICE_KEY in .env (found in Supabase Dashboard -> Settings -> API -> service_role key)")
        return False


# ── Main ───────────────────────────────────────────────────────────────────────
def main():
    ip  = get_local_ip()
    url = f"http://{ip}:{PORT}"

    print("=" * 55)
    print(f"  TravelBuddy Backend Startup")
    print(f"  Current IP  : {ip}")
    print(f"  Backend URL : {url}")
    print("=" * 55)

    # Push to Supabase so the phone always knows the current address
    update_supabase(url)

    # If --run flag provided, start uvicorn automatically
    if "--run" in sys.argv:
        print(f"\n[Startup] Starting uvicorn on {url} ...\n")
        env = os.environ.copy()
        env["PYTHONPATH"] = str(_ROOT)
        subprocess.run(
            [sys.executable, "-m", "uvicorn", "backend.main:app",
             "--host", "0.0.0.0", "--port", str(PORT)],
            env=env,
            cwd=str(_ROOT),
        )
    else:
        print("\n[Startup] IP registered. Start the server with:")
        print(f"  uvicorn backend.main:app --host 0.0.0.0 --port {PORT}")
        print("\n  Or use the one-command launcher:")
        print("  python backend/startup.py --run\n")


if __name__ == "__main__":
    main()
