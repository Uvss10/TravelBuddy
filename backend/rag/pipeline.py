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

def rag_generate_itinerary(destination: str, days: int, budget: str, interests: List[str]) -> tuple:
    """
    Complete RAG workflow for itinerary generation.
    Returns: (raw_llm_output, meta_data)
    """
    print(f"[RAG:Pipeline] Starting RAG flow for {destination} ({days} days)...")

    # 1. RETRIEVAL
    retrieved_data = retrieve(destination)
    
    # 2. SELECTION / RANKING
    context_block = rank_and_format_context(retrieved_data, interests)
    
    # 3. GENERATION AUGMENTATION
    # The actual prompt template is handled in itinerary_service.py to keep formatting consistent.
    # We return the context block and metadata to the service.
    
    meta = {
        "source": retrieved_data.get("source", "none"),
        "has_context": bool(context_block),
        "context_len": len(context_block)
    }
    
    return context_block, meta
