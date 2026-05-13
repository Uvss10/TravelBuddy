import os
import json
from backend.schemas.itinerary_schema import ItineraryRequest, ItineraryEditRequest
from backend.utils import call_llm
from backend.services.budget_service import estimate_budget
from backend.rag.pipeline import rag_generate_itinerary, rag_edit_itinerary

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
    import re
    raw = raw.strip()
    # Try to find a JSON block within markdown fences (handling both { } and [ ])
    match = re.search(r'```(?:json)?\s*([\{\[].*?[\}\]])\s*```', raw, re.DOTALL)
    if match:
        raw_json = match.group(1)
    else:
        # Find outermost { } or [ ]
        # We look for the first { or [ and the last } or ]
        first_brace = raw.find("{")
        first_bracket = raw.find("[")
        
        start = -1
        if first_brace >= 0 and (first_bracket < 0 or first_brace < first_bracket):
            start = first_brace
            end = raw.rfind("}") + 1
        elif first_bracket >= 0:
            start = first_bracket
            end = raw.rfind("]") + 1
            
        if start < 0 or end <= 0:
            # Last ditch effort: see if the whole thing is just a JSON string
            try:
                return json.loads(raw)
            except:
                raise ValueError("No JSON found")
        raw_json = raw[start:end]
        
    return json.loads(raw_json)


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

    budget_estimation = estimate_budget(request.destination, request.days, request.budget)

    # 2. PARSE OUTPUT
    try:
        itinerary_output = _parse_itinerary_json(raw_output)
    except (ValueError, json.JSONDecodeError, TypeError) as e:
        print(f"[ItineraryService] JSON Parse Error: {e}. Raw output: {raw_output}")
        # Fallback to a structured object that the Flutter app can parse as legacy format
        itinerary_output = {
            "Day 1": ["AI generated a text-only itinerary or encountered an error parsing it.", "Please try regenerating the itinerary."],
            "Raw Response": raw_output.split('\n')[:10]  # Just send a bit of it so we don't overwhelm the UI
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
