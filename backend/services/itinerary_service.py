from backend.schemas.itinerary_schema import ItineraryRequest
from backend.utils import call_llm
from backend.services.budget_service import estimate_budget

def generate_itinerary(request: ItineraryRequest):
    prompt = f"""
    Create a day-wise travel itinerary.

    Destination: {request.destination}
    Duration: {request.days} days
    Budget: {request.budget}
    Interests: {', '.join(request.interests)}

    Return output in this JSON format:
    {{
        "Day 1": ["Activity 1", "Activity 2"],
        "Day 2": ["Activity 1", "Activity 2"]
    }}
    """

    ai_itinerary = call_llm(prompt)
    budget_estimation = estimate_budget(request.days, request.budget)

    return {
        "destination": request.destination,
        "total_days": request.days,
        "budget_category": request.budget,
        "itinerary_ai_output": ai_itinerary,
        "hotel_and_budget_estimation": budget_estimation
    }
