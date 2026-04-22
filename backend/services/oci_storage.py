import os
import oci
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

class OCIStorageService:
    def __init__(self):
        # We try to load OCI config from .env
        self.config = {
            "user": os.getenv("OCI_USER_OCID"),
            "key_file": os.getenv("OCI_KEY_PATH"),
            "fingerprint": os.getenv("OCI_FINGERPRINT"),
            "tenancy": os.getenv("OCI_TENANCY_OCID"),
            "region": os.getenv("OCI_REGION", "ap-mumbai-1")
        }
        
        self.bucket_name = os.getenv("OCI_BUCKET_NAME")
        self.namespace = os.getenv("OCI_NAMESPACE")
        self.enabled = all([self.config["user"], self.config["key_file"], self.bucket_name, self.namespace])
        
        if self.enabled:
            try:
                self.client = oci.object_storage.ObjectStorageClient(self.config)
                print(f"✅ OCI Storage initialized on bucket: {self.bucket_name}")
            except Exception as e:
                print(f"❌ OCI Storage initialization failed: {e}")
                self.enabled = False
        else:
            print("⚠️ OCI Storage not configured in .env. Falling back to local storage.")

    def upload_file(self, local_path: str, object_name: str) -> Optional[str]:
        """Uploads a file to Oracle Cloud Object Storage and returns the public URL."""
        if not self.enabled:
            return None
            
        try:
            with open(local_path, "rb") as f:
                self.client.put_object(
                    self.namespace,
                    self.bucket_name,
                    object_name,
                    f
                )
            
            # Construct the permanent OCI URL (requires bucket to be public or use pre-signed URLs)
            # For simplicity, we assume a public bucket or structured path:
            url = f"https://objectstorage.{self.config['region']}.oraclecloud.com/n/{self.namespace}/b/{self.bucket_name}/o/{object_name}"
            return url
        except Exception as e:
            print(f"❌ OCI Upload failed: {e}")
            return None

# Singleton instance
oci_storage = OCIStorageService()
