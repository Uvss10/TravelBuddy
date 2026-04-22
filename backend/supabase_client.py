import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    # We allow it to be empty during setup, but it will fail at runtime
    print("Warning: SUPABASE_URL or SUPABASE_KEY not set in .env")

supabase: Client = create_client(SUPABASE_URL or "", SUPABASE_KEY or "")

def get_supabase() -> Client:
    return supabase
