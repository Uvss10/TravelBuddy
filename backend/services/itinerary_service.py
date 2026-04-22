import os
import json
from backend.schemas.itinerary_schema import ItineraryRequest, ItineraryEditRequest
from backend.utils import call_llm
from backend.services.budget_service import estimate_budget
from rag.rag_pipeline import rag_generate_itinerary, rag_edit_itinerary

# Load prompt template once
_PROMPT_PATH = os.path.join(
    os.path.dirname(__file__),
    "..", "..", "models", "llm", "prompts", "itinerary_prompt.txt"
)

def _load_prompt() -> str:
    try:
        with open(_PROMPT_PATH, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        # Inline fallback
        return (
            "Create a specific day-wise itinerary for {destination}, {days} days, "
            "{budget} budget, interests: {interests}. "
            "{rag_context} "
            "Name every real place. Return JSON: {\"Day 1\": [\"activity\"]}"
        )

_PROMPT_TEMPLATE = _load_prompt()


def _parse_itinerary_json(raw: str):
    """Extract JSON from LLM output, stripping markdown if present."""
    raw = raw.strip()
    # Remove markdown fences
    if raw.startswith("```"):
        lines = raw.splitlines()
        raw = "\n".join(l for l in lines if not l.strip().startswith("```"))
    # Find outermost { }
    start = raw.find("{")
    end   = raw.rfind("}") + 1
    if start < 0 or end <= 0:
        raise ValueError("No JSON found")
    return json.loads(raw[start:end])


def generate_itinerary(request: ItineraryRequest):
    # 1. RUN RAG PIPELINE
    # This now directly generates the itinerary using the retrieved context
    raw_output = rag_generate_itinerary(
        request.destination, 
        request.days, 
        request.budget, 
        request.interests,
        travel_style=request.travel_style,
        group_type=request.group_type,
        starting_location=request.starting_location,
        custom_constraints=request.custom_constraints
    )

    budget_estimation = estimate_budget(request.days, request.budget)

    # 2. PARSE OUTPUT
    try:
        itinerary_output = _parse_itinerary_json(raw_output)
    except (ValueError, json.JSONDecodeError, TypeError):
        # Fallback to a structured object so Flutter doesn't crash on type cast
        itinerary_output = {
            "trip_summary": {
                "destination": request.destination,
                "duration_days": request.days,
                "note": "AI generated a text-only itinerary."
            },
            "raw_text": raw_output
        }

    return {
        "destination": request.destination,
        "total_days": request.days,
        "budget_category": request.budget,
        "interests": request.interests,
        "itinerary_ai_output": itinerary_output,
        "hotel_and_budget_estimation": budget_estimation,
        "meta": {
            "is_rag": True,
            "pipeline": "new_chroma_rag"
        }
    }


def edit_itinerary(request: ItineraryEditRequest):
    """
    Handles partial editing of an itinerary.
    """
    raw_output = rag_edit_itinerary(request.existing_plan, request.modification, request.interests)
    
    try:
        updated_json = _parse_itinerary_json(raw_output)
    except Exception:
        updated_json = raw_output

    return {
        "itinerary_ai_output": updated_json,
        "meta": {
            "is_edit": True,
            "modification": request.modification
        }
    }
