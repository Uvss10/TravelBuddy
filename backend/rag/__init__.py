"""
TravelBuddy RAG (Retrieval-Augmented Generation) Pipeline
==========================================================

Architecture:
  ┌────────────┐     ┌────────────┐     ┌────────────┐
  │  RETRIEVER │ ──▶ │  CHUNKER   │ ──▶ │ GENERATOR  │
  │ Wikivoyage │     │ Rank+Split │     │ Sarvam-1   │
  │ Wikipedia  │     │ by user    │     │ via Ollama  │
  └────────────┘     │  interests │     └────────────┘
                     └────────────┘

- Retriever : Fetches live travel data from Wikivoyage / Wikipedia (free, no key)
- Chunker   : Splits into sections, ranks by relevance to user interests
- Generator : Injects top-ranked context into prompt, sends to Sarvam-1 via Ollama

Usage:
    from backend.rag import rag_generate_itinerary
    result = rag_generate_itinerary("Hampi", 3, "Low", ["history", "photography"])
"""

from backend.rag.pipeline import rag_generate_itinerary

__all__ = ["rag_generate_itinerary"]
