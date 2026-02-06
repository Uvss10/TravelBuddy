from fastapi import APIRouter

router = APIRouter()

@router.get("/status")
def image_status():
    return {"message": "Image analysis module ready"}
