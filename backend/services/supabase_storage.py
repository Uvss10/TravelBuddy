import os
from pathlib import Path
from typing import Optional
from backend.supabase_client import supabase

class SupabaseStorage:
    def __init__(self):
        self.bucket_name = "travelbuddy" # Default bucket
        self.enabled = bool(os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_KEY"))

    def upload_file(self, local_path: str, remote_name: str, bucket: str = "travelbuddy") -> Optional[str]:
        """
        Uploads a file to Supabase Storage and returns the public URL.
        """
        if not self.enabled:
            print("Supabase Storage disabled: credentials missing.")
            return None

        try:
            with open(local_path, 'rb') as f:
                # Upsert = True allows overwriting if same name
                response = supabase.storage.from_(bucket).upload(
                    path=remote_name,
                    file=f,
                    file_options={"cache-control": "3600", "upsert": "true"}
                )
            
            # Get public URL
            public_url = supabase.storage.from_(bucket).get_public_url(remote_name)
            return public_url
        except Exception as e:
            print(f"Supabase Upload Error: {e}")
            return None

supabase_storage = SupabaseStorage()
