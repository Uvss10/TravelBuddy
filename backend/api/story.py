from fastapi import APIRouter

router = APIRouter()

@router.get("/status")
def story_status():
    return {"message": "Story generation module ready"}
