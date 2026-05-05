from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from backend.services.google_drive_service import update_app_version

router = APIRouter()

class VersionUpdateRequest(BaseModel):
    version_code: int
    backend_url: str
    apk_url: str
    message: str = "A new version of TravelBuddy is available!"

@router.post("/update-version")
def update_version_api(request: VersionUpdateRequest):
    try:
        file_id = update_app_version(
            request.version_code,
            request.backend_url,
            request.apk_url,
            request.message
        )
        if file_id:
            return {"status": "success", "file_id": file_id}
        else:
            raise HTTPException(status_code=500, detail="Failed to upload to Google Drive")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
