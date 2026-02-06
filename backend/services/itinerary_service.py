from backend.schemas.itinerary_schema import ItineraryRequest
from backend.utils import call_llm

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

    llm_output = call_llm(prompt)

    return {
        "destination": request.destination,
        "total_days": request.days,
        "budget": request.budget,
        "itinerary_ai_output": llm_output
    }
