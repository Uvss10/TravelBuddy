from fastapi import APIRouter
from backend import utils
import json

router = APIRouter()

from backend.rag.retriever import retrieve_top_chunks
from backend.rag.image_retriever import enrich_spots_with_images

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
        data = json.loads(raw_output[start:end])
        
        # Enrich with REAL images from Wikimedia/Unsplash
        if "spots" in data:
            data["spots"] = enrich_spots_with_images(data["spots"])
            
        return data
    except Exception:
        # Static fallback if RAG and LLM both struggle
        fallback = {"spots": [{"name": "Mehrangarh Fort", "category": "Heritage", "description": "Majestic fort of Jodhpur.", "photography_tip": "Shoot from blue city roofs.", "distance_km": 0.5, "importance": "Must-Visit", "recommendation": "Iconic history."}]}
        fallback["spots"] = enrich_spots_with_images(fallback["spots"])
        return fallback
