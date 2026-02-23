import os
import json
from backend.schemas.story_schema import StoryRequest
from backend.utils import call_llm

# Load the prompt template once at module import time
_PROMPT_PATH = os.path.join(
    os.path.dirname(__file__),
    "..", "..", "models", "llm", "prompts", "story_prompt.txt"
)

def _load_prompt_template() -> str:
    try:
        with open(_PROMPT_PATH, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        # Inline fallback if file is missing
        return """You are a cinematic travel storyteller.
Create a 1-minute engaging reel narration for a trip to {destination}.
Scene themes: {scene_tags}
Emotional tone: {tone}
Return ONLY valid JSON: {{"title":"","narration":"","captions":[],"hashtags":[]}}"""

_PROMPT_TEMPLATE = _load_prompt_template()


def _mock_story(destination: str, tone: str) -> dict:
    """Fallback mock story when LLM is unavailable."""
    dest = destination.title()
    return {
        "title": f"Lost in {dest}",
        "narration": (
            f"There are places that don't just fill your camera roll — they fill your soul. "
            f"{dest} is one of them. From the first golden ray of dawn painting ancient walls, "
            f"to the hush of twilight settling over timeless landscapes, every moment here feels "
            f"like a scene from a dream you never want to wake from. The air carries stories "
            f"centuries old. The people, the flavors, the colors — they pull you in and refuse "
            f"to let go. This is not just a trip. This is a transformation. "
            f"Pack your bags. {dest} is calling."
        ),
        "captions": [
            f"Where time stands still",
            f"Golden hour magic ✨",
            f"Ancient walls, new stories",
            f"Every corner, a postcard",
            f"Flavors you'll never forget",
            f"Wander without a map",
            f"Sunsets that steal your breath",
            f"This is the life",
            f"Come back changed",
            f"Your next chapter starts here",
        ],
        "hashtags": [
            f"#{dest.replace(' ', '')}",
            "#TravelReel",
            "#CinematicTravel",
            "#InstagramTravel",
            "#WanderlustVibes",
            "#TravelBuddy",
            "#ExploreMore",
            "#ReelItFeelIt",
        ],
    }


def _parse_llm_output(raw: str) -> dict:
    """Extract JSON from LLM output, stripping any surrounding markdown."""
    raw = raw.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        lines = raw.splitlines()
        raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
    # Find the first { and last } to extract JSON
    start = raw.find("{")
    end = raw.rfind("}") + 1
    if start == -1 or end == 0:
        raise ValueError("No JSON object found in LLM output")
    return json.loads(raw[start:end])


def generate_story(request: StoryRequest) -> dict:
    scene_tags_str = ", ".join(request.scene_tags)
    # Use manual replacement instead of str.format() to avoid KeyError
    # from literal { } braces in the JSON example inside the prompt template.
    prompt = (
        _PROMPT_TEMPLATE
        .replace("{destination}", request.destination)
        .replace("{scene_tags}", scene_tags_str)
        .replace("{tone}", request.tone)
    )

    raw_output = call_llm(prompt)

    # Try to parse LLM output; fall back to mock if it fails or is missing story fields
    try:
        story_data = _parse_llm_output(raw_output)
        # Validate that the parsed JSON actually has story fields, not itinerary fields
        if not story_data.get("title") and not story_data.get("narration"):
            raise ValueError("LLM returned non-story JSON")
    except (ValueError, json.JSONDecodeError):
        story_data = _mock_story(request.destination, request.tone)

    return {
        "destination": request.destination,
        "title": story_data.get("title", ""),
        "narration": story_data.get("narration", ""),
        "captions": story_data.get("captions", []),
        "hashtags": story_data.get("hashtags", []),
    }
