from fastapi import APIRouter
from backend.schemas.itinerary_schema import ItineraryRequest
from backend.services.itinerary_service import generate_itinerary

router = APIRouter()

@router.post("/generate")
def generate_itinerary_api(request: ItineraryRequest):
    return generate_itinerary(request)
