from fastapi import APIRouter
from backend.schemas.itinerary_schema import ItineraryRequest, ItineraryEditRequest
from backend.services.itinerary_service import generate_itinerary, edit_itinerary

router = APIRouter()

@router.post("/generate")
def generate_itinerary_api(request: ItineraryRequest):
    return generate_itinerary(request)

@router.post("/edit")
def edit_itinerary_api(request: ItineraryEditRequest):
    return edit_itinerary(request)
