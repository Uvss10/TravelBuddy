from fastapi import APIRouter

router = APIRouter()

@router.get("/status")
def video_status():
    return {"message": "Video generation module ready"}
