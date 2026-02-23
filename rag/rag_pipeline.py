from backend.utils import call_llm
from rag.retriever import retrieve_top_chunks

def rag_generate_itinerary(destination, days, budget, interests):
    """
    RAG pipeline: retrieves context and generates an itinerary.
    Uses the central call_llm helper to support both local and API modes.
    """
    interests_str = ", ".join(interests) if interests else "general"
    query = f"Plan {days} days in {destination} with focus on {interests_str} and {budget} budget"
    context_chunks = retrieve_top_chunks(query)
    
    context_text = "\n\n".join(context_chunks)
    
    if context_chunks:
        instruction = f"Using primarily the following Wikivoyage information provided below, but supplementing with your knowledge if necessary:"
        context_block = f"\n[WIKIVOYAGE CONTEXT]\n{context_text}\n"
    else:
        instruction = "Using your general travel knowledge (as no specific Wikivoyage data was found for this query):"
        context_block = ""

    prompt = f"""
You are a professional travel planner.
{instruction}

{context_block}

Generate a structured {days}-day itinerary for {destination} in JSON format.
Consider a {budget} budget and interests in {interests_str}.
Return strictly valid JSON with the following structure:
{{
  "city": "{destination}",
  "days": [
    {{
      "day": 1,
      "morning": "...",
      "afternoon": "...",
      "evening": "..."
    }},
    ...
  ]
}}
"""

    try:
        print(f"[RAG] Generating itinerary for {destination} using active LLM...")
        output = call_llm(prompt)
        print(f"[RAG] Generation complete ({len(output) if output else 0} chars).")
        return output
    except Exception as e:
        print(f"Error in RAG pipeline: {e}")
        return None

if __name__ == "__main__":
    itinerary = rag_generate_itinerary("Udaipur", 3, "Medium", ["history"])
    print(itinerary)
