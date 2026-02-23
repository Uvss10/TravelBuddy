"""
RAG Retriever — fetches real travel data from Wikivoyage and Wikipedia.
=====================================================================
• Zero API keys required
• Wikivoyage = travel-specific wiki (best for itinerary context)
• Wikipedia  = fallback for cities without a Wikivoyage page
• Returns structured data: sections, listings (POIs), raw text
"""

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional

WIKIVOYAGE_API = "https://en.wikivoyage.org/w/api.php"
WIKIPEDIA_API  = "https://en.wikipedia.org/w/api.php"
USER_AGENT     = "TravelBuddy/2.0 (open-source travel app; RAG pipeline)"


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

def retrieve(destination: str, timeout: int = 12) -> dict:
    """
    Retrieve travel data for a destination.

    Returns:
        {
            "destination": str,
            "source": "wikivoyage" | "wikipedia" | "none",
            "sections": { "see": "...", "eat": "...", ... },
            "listings": { "see": [...], "eat": [...], ... },
            "raw_text": str,   # full cleaned text (for chunking)
        }
    """
    print(f"[RAG:Retriever] Fetching: {destination}")

    # 1. Try Wikivoyage (travel-specific — best quality)
    data = _fetch_wikivoyage(destination, timeout)
    if data and data.get("raw_text") and len(data["raw_text"]) > 200:
        n_sec = len(data.get("sections", {}))
        n_lst = sum(len(v) for v in data.get("listings", {}).values())
        print(f"[RAG:Retriever] Wikivoyage OK — {n_sec} sections, {n_lst} listings, {len(data['raw_text'])} chars")
        return data

    # 2. Fallback: Wikipedia
    print(f"[RAG:Retriever] No Wikivoyage article — trying Wikipedia")
    data = _fetch_wikipedia(destination, timeout)
    if data and data.get("raw_text") and len(data["raw_text"]) > 100:
        print(f"[RAG:Retriever] Wikipedia OK — {len(data['raw_text'])} chars")
        return data

    print(f"[RAG:Retriever] No data found for: {destination}")
    return {
        "destination": destination,
        "source": "none",
        "sections": {},
        "listings": {"see": [], "eat": [], "do": [], "buy": [], "sleep": []},
        "raw_text": "",
    }


# ─────────────────────────────────────────────────────────────────────────────
# WIKIVOYAGE
# ─────────────────────────────────────────────────────────────────────────────

def _fetch_wikivoyage(destination: str, timeout: int) -> Optional[dict]:
    """Fetch and parse a Wikivoyage article."""
    params = {
        "action": "query", "titles": destination,
        "prop": "revisions", "rvprop": "content", "rvslots": "main",
        "format": "json", "formatversion": "2", "redirects": "1",
    }
    url = WIKIVOYAGE_API + "?" + urllib.parse.urlencode(params)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = json.loads(resp.read().decode("utf-8"))

        pages = raw.get("query", {}).get("pages", [])
        if not pages or pages[0].get("missing"):
            return None

        wikitext = (
            pages[0].get("revisions", [{}])[0]
            .get("slots", {}).get("main", {}).get("content", "")
        )
        if not wikitext or len(wikitext) < 200:
            return None

        return _parse_wikivoyage(wikitext, destination)

    except Exception as e:
        print(f"[RAG:Retriever] Wikivoyage fetch error: {e}")
        return None


def _parse_wikivoyage(wikitext: str, destination: str) -> dict:
    """Parse Wikivoyage wikitext into structured data."""

    # ── Extract level-2 sections ──
    section_re = re.compile(
        r"==\s*([^=\n]+?)\s*==\s*\n(.*?)(?=\n==\s[^=]|\Z)", re.DOTALL
    )
    sections = {}
    for m in section_re.finditer(wikitext):
        name = m.group(1).strip().lower()
        body = _clean_wikitext(m.group(2))
        if body and len(body) > 30:
            sections[name] = body[:3000]

    # ── Extract structured listing items ──
    listings = _extract_listings(wikitext)

    # ── Build full raw text for chunking ──
    all_text_parts = []
    for name, body in sections.items():
        all_text_parts.append(f"[{name.upper()}]\n{body}")
    raw_text = "\n\n".join(all_text_parts)

    return {
        "destination": destination,
        "source": "wikivoyage",
        "sections": sections,
        "listings": listings,
        "raw_text": raw_text,
    }


def _extract_listings(wikitext: str) -> dict:
    """
    Extract structured POI listings from Wikivoyage templates like
    {{see|name=...|content=...}}, {{eat|...}}, {{do|...}}, etc.
    """
    results = {"see": [], "eat": [], "do": [], "buy": [], "sleep": []}

    listing_re = re.compile(
        r"\{\{(?P<type>listing|see|do|eat|drink|buy|sleep)\b[^|]*"
        r"\|[^}]*?name\s*=\s*(?P<name>[^|}\n]+)"
        r"(?:[^}]*?(?:content|description)\s*=\s*(?P<desc>[^|}]{0,300}))?",
        re.IGNORECASE | re.DOTALL,
    )

    for m in listing_re.finditer(wikitext):
        ttype = m.group("type").lower()
        name  = m.group("name").strip()
        desc  = _clean_wikitext((m.group("desc") or "").strip())[:200]
        entry = f"{name} — {desc}" if desc else name

        if ttype in ("see",):
            results["see"].append(entry)
        elif ttype in ("eat", "drink"):
            results["eat"].append(entry)
        elif ttype in ("do",):
            results["do"].append(entry)
        elif ttype in ("buy",):
            results["buy"].append(entry)
        elif ttype in ("sleep",):
            results["sleep"].append(entry)
        else:
            # listing type — classify by surrounding section heading
            ctx = wikitext[max(0, m.start() - 400):m.start()].lower()
            if any(k in ctx for k in ("== see", "== sight", "attraction")):
                results["see"].append(entry)
            elif any(k in ctx for k in ("== eat", "== food", "restaurant")):
                results["eat"].append(entry)
            elif any(k in ctx for k in ("== do",)):
                results["do"].append(entry)
            elif any(k in ctx for k in ("== buy", "== shop")):
                results["buy"].append(entry)

    # Deduplicate and cap at 12 per category
    for key in results:
        seen, deduped = set(), []
        for item in results[key]:
            if item not in seen:
                seen.add(item)
                deduped.append(item)
        results[key] = deduped[:12]

    return results


# ─────────────────────────────────────────────────────────────────────────────
# WIKIPEDIA FALLBACK
# ─────────────────────────────────────────────────────────────────────────────

def _fetch_wikipedia(destination: str, timeout: int) -> Optional[dict]:
    """Fetch Wikipedia extract for a city (intro paragraphs)."""
    for title in [destination, f"{destination} (city)", f"{destination}, India"]:
        result = _wiki_extract(title, timeout)
        if result:
            return result
    return None


def _wiki_extract(title: str, timeout: int) -> Optional[dict]:
    params = {
        "action": "query", "titles": title,
        "prop": "extracts", "exintro": True, "explaintext": True,
        "format": "json", "redirects": "1",
    }
    url = WIKIPEDIA_API + "?" + urllib.parse.urlencode(params)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = json.loads(resp.read().decode("utf-8"))

        pages = raw.get("query", {}).get("pages", {})
        page  = next(iter(pages.values()), {})
        if page.get("missing"):
            return None

        extract = page.get("extract", "").strip()
        if not extract or len(extract) < 100:
            return None

        return {
            "destination": title,
            "source": "wikipedia",
            "sections": {"understand": extract[:3000]},
            "listings": {"see": [], "eat": [], "do": [], "buy": [], "sleep": []},
            "raw_text": extract[:3000],
        }
    except Exception as e:
        print(f"[RAG:Retriever] Wikipedia error for '{title}': {e}")
        return None


# ─────────────────────────────────────────────────────────────────────────────
# WIKITEXT CLEANER
# ─────────────────────────────────────────────────────────────────────────────

def _clean_wikitext(text: str) -> str:
    """Remove wikitext markup, producing readable plain text."""
    text = re.sub(r"<ref[^/]*/?>", "", text, flags=re.DOTALL)
    text = re.sub(r"<ref[^>]*>.*?</ref>", "", text, flags=re.DOTALL)
    text = re.sub(r"<nowiki>.*?</nowiki>", "", text, flags=re.DOTALL)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
    for _ in range(6):
        text = re.sub(r"\{\{[^{}]*\}\}", "", text)
    text = re.sub(r"\{\|.*?\|\}", "", text, flags=re.DOTALL)
    text = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"\[https?://\S+\s+([^\]]+)\]", r"\1", text)
    text = re.sub(r"\[https?://\S+\]", "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"'{2,}", "", text)
    text = re.sub(r"={2,}[^=]+=+", "", text)
    text = re.sub(r"^[*#:;]+\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()
