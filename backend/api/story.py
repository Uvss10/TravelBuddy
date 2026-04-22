from fastapi import APIRouter
from backend.schemas.story_schema import StoryRequest, StoryResponse
from backend.services.story_service import generate_story

router = APIRouter()


@router.get("/status")
def story_status():
    return {"message": "Story generation module ready"}


@router.post("/generate", response_model=StoryResponse)
def generate_story_api(request: StoryRequest):
    """
    Generate a cinematic Instagram reel narration for a travel destination.

    - **destination**: Name of the travel destination (e.g. "Jaisalmer")
    - **scene_tags**: List of image themes/scenes in the reel (e.g. ["golden fort", "camel safari", "sunset dunes"])
    - **tone**: Emotional tone for the narration (default: "adventurous and inspiring")
    """
    return generate_story(request)
