"""
RAG Pipeline — Orchestrates Retrieval, Selection, and Generation.
================================================================
Steps:
1. Retrieve: Fetch Wikivoyage data for the destination.
2. Select: Rank and format sections by relevance to user interests.
3. Generate: Augment the prompt and call Sarvam-1 via Ollama.
"""

from backend.rag.retriever import retrieve
from backend.rag.chunker import rank_and_format_context
from backend.utils import call_llm
from typing import List

def rag_generate_itinerary(
    destination: str, 
    days: int, 
    budget: str, 
    interests: List[str],
    travel_style: str = "balanced",
    group_type: str = "solo",
    starting_location: str = "",
    custom_constraints: str = ""
) -> str:
    """
    Complete RAG workflow for itinerary generation.
    Retrieves real-world data and uses it to augment the LLM prompt.
    """
    print(f"[RAG:Pipeline] Starting RAG flow for {destination} ({days} days)...")

    # 1. RETRIEVAL
    retrieved_data = retrieve(destination)
    
    # 2. SELECTION / RANKING
    context_block = rank_and_format_context(retrieved_data, interests)
    
    # 3. GENERATION AUGMENTATION
    # We construct a detailed prompt using the user's specific preferences and the retrieved context.
    prompt = (
        f"You are a local travel expert. Create a detailed {days}-day itinerary for {destination}.\n\n"
        f"User Profile:\n"
        f"- Budget: {budget}\n"
        f"- Interests: {', '.join(interests)}\n"
        f"- Travel Style: {travel_style}\n"
        f"- Group: {group_type}\n"
        f"- Starting from: {starting_location}\n"
        f"- Special Requests: {custom_constraints}\n\n"
        f"Real-world data for {destination} (use this for specific landmarks/food):\n"
        f"{context_block if context_block else 'No specific local data available; use your general knowledge.'}\n\n"
        f"Instructions:\n"
        f"1. Provide a specific, actionable plan for every day.\n"
        f"2. Return ONLY valid JSON in this format: "
        f"{{\"Day 1\": [\"activity 1\", \"activity 2\"], \"Day 2\": [...]}}\n"
        f"3. Do not include markdown code blocks or extra text."
    )

    print(f"[RAG:Pipeline] Calling LLM with augmented context...")
    raw_output = call_llm(prompt)
    
    return raw_output


def rag_edit_itinerary(existing_plan, modification, interests):
    """
    Partial RAG for editing. For now, it performs a simple LLM call.
    """
    prompt = (
        f"Update the following travel plan based on this request: {modification}\n\n"
        f"Original Plan:\n{existing_plan}\n\n"
        f"Interests: {', '.join(interests)}\n"
        f"Return the updated plan in the same JSON format."
    )
    return call_llm(prompt)
