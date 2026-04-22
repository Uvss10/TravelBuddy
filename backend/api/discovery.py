from fastapi import APIRouter
from backend import utils
import json

router = APIRouter()

from rag.retriever import retrieve_top_chunks

@router.get("/nearby")
def get_nearby_discovery(location: str = "Your World", lat: float = 0.0, lon: float = 0.0):
    """
    Find photography, heritage, and nature spots using RAG from Wikivoyage data.
    """
    query = f"Photography heritage and nature spots in {location}"
    context_chunks = retrieve_top_chunks(query, n_results=10)
    context_text = "\n\n".join(context_chunks)
    
    instruction = "Using the following Wikivoyage information provided below (and your knowledge only for gaps):" if context_chunks else "Using your knowledge:"
    context_block = f"\n[WIKIVOYAGE CONTEXT]\n{context_text}\n" if context_chunks else ""

    prompt = f"""
    SYSTEM: You are a Professional AI Travel Scout.
    Find 6 'Instagrammable' and significant spots near {location} (coordinates: {lat}, {lon}).
    {instruction}
    {context_block}

    Return ONLY a JSON object:
    {{
      "spots": [
        {{
          "name": "Spot Name",
          "category": "Photography | Heritage | Nature",
          "description": "Short catchy description",
          "photography_tip": "Specific pro tip",
          "image_url": "https://images.unsplash.com/photo-<id>?w=800",
          "distance_km": [Float],
          "importance": "Must-Visit | Recommended | Hidden Gem",
          "recommendation": "Expert insight"
        }}
      ]
    }}
    """
    
    try:
        raw_output = utils.call_llm(prompt)
        start = raw_output.find("{")
        end   = raw_output.rfind("}") + 1
        return json.loads(raw_output[start:end])
    except Exception:
        # Static fallback if RAG and LLM both struggle
        return {"spots": [{"name": "Local Landmark", "category": "Heritage", "description": "Beautiful site.", "photography_tip": "Morning light.", "image_url": "https://images.unsplash.com/photo-1548013146-72479768bada?w=800", "distance_km": 0.5, "importance": "Recommended", "recommendation": "Truly iconic."}]}
