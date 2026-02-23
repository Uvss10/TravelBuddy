"""
RAG Chunker & Ranker — filters and formats retrieved data.
=========================================================
• Splits retrieved text into logical chunks.
• Ranks chunks by relevance to user's interests (keyword-based).
• Formats the top chunks into a single context block for the generator.
"""

import re
from typing import List

def rank_and_format_context(retrieved_data: dict, interests: List[str], max_chars: int = 4000) -> str:
    """
    Take raw sections and listings, rank them based on interests, and format for prompt.
    """
    sections = retrieved_data.get("sections", {})
    listings = retrieved_data.get("listings", {})
    destination = retrieved_data.get("destination", "the destination")
    source = retrieved_data.get("source", "Wikivoyage")

    if not sections and not listings:
        return ""

    # 1. Scoring sections based on interest keywords
    scored_sections = []
    interest_keywords = [i.lower() for i in interests]
    
    # Common synonyms/related words for better matching
    extra_keywords = {
        "food": ["eat", "restaurant", "cuisine", "street food", "dining", "dish"],
        "history": ["temple", "monument", "fort", "museum", "ancient", "heritage", "king", "dynasty"],
        "adventure": ["trek", "hike", "rafting", "climb", "safari", "nature", "wildlife"],
        "photography": ["view", "sunset", "panoramic", "scenic", "landscape", "stunning"],
        "shopping": ["market", "bazaar", "shop", "handicraft", "souvenir", "buy"]
    }
    
    full_search_list = set(interest_keywords)
    for i in interest_keywords:
        if i in extra_keywords:
            full_search_list.update(extra_keywords[i])

    for name, content in sections.items():
        score = 0
        # Check section title
        for word in full_search_list:
            if word in name.lower():
                score += 10
        
        # Check content (simple word count)
        content_lower = content.lower()
        for word in full_search_list:
            score += content_lower.count(word)
            
        # Give a base score to high-priority sections
        priority_sections = ["see", "do", "eat", "understand", "sights"]
        if name.lower() in priority_sections:
            score += 5
            
        scored_sections.append({"name": name, "content": content, "score": score})

    # Sort sections by score descending
    scored_sections.sort(key=lambda x: x["score"], reverse=True)

    # 2. Build the context block
    context_lines = [
        f"=== REAL VERIFIED DATA FOR {destination.upper()} ===",
        f"(Source: {source} — Priority based on interests: {', '.join(interests)})\n"
    ]

    # Add Listings first (very concise POIs)
    has_listings = any(v for v in listings.values())
    if has_listings:
        context_lines.append("[VERIFIED PLACES]")
        cat_map = {
            "see": "Top Sights",
            "eat": "Food & Drink",
            "do": "Activities",
            "buy": "Shopping",
            "sleep": "Stay"
        }
        for cat, label in cat_map.items():
            items = listings.get(cat, [])
            if items:
                context_lines.append(f"• {label}: {', '.join(items[:6])}")
        context_lines.append("")

    # Add sections until we hit max_chars
    current_length = sum(len(line) for line in context_lines)
    for sec in scored_sections:
        section_text = f"[{sec['name'].upper()}]\n{sec['content']}\n\n"
        if current_length + len(section_text) > max_chars:
            # Try to add at least a snippet
            remaining = max_chars - current_length - 50
            if remaining > 200:
                context_lines.append(f"[{sec['name'].upper()}]\n{sec['content'][:remaining]}... (truncated)\n")
            break
        
        context_lines.append(section_text)
        current_length += len(section_text)

    return "\n".join(context_lines)
