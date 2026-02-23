import os
import bz2
import xml.etree.ElementTree as ET
import mwparserfromhell
import re
from tqdm import tqdm
from rag.embedder import generate_embedding
from rag.vector_store import add_chunks_to_store

DUMP_PATH = os.path.join("data", "enwikivoyage-latest-pages-articles.xml.bz2")
NAMESPACE = "{http://www.mediawiki.org/xml/export-0.10/}"

def clean_wiki_text(text):
    """Cleans wiki markup into plain text."""
    wikicode = mwparserfromhell.parse(text)
    # Remove templates, but keep their text content if relevant (optional)
    # For travel guides, templates often contain important info, but for RAG plain text is safer
    text = wikicode.strip_code()
    # Basic regex cleanup
    text = re.sub(r'\n+', '\n', text)
    return text.strip()

def chunk_text(text, title, chunk_size=700, overlap=100):
    """Splits text into chunks with overlap."""
    words = text.split()
    chunks = []
    
    for i in range(0, len(words), chunk_size - overlap):
        chunk_words = words[i:i + chunk_size]
        if len(chunk_words) < 100: # Skip tiny chunks
            continue
        chunks.append(" ".join(chunk_words))
        if i + chunk_size >= len(words):
            break
            
    return chunks

def process_wikivoyage_dump(limit=None):
    """Parses XML and ingests data into vector store."""
    if not os.path.exists(DUMP_PATH):
        print(f"Dump file not found at {DUMP_PATH}. Please run download_dump.py first.")
        return

    print("Starting XML parsing (streaming)...")
    
    count = 0
    with bz2.open(DUMP_PATH, "rb") as f:
        context = ET.iterparse(f, events=("end",))
        
        for event, elem in tqdm(context, desc="Processing pages"):
            if elem.tag == f"{NAMESPACE}page":
                title = elem.find(f"{NAMESPACE}title").text
                ns = elem.find(f"{NAMESPACE}ns").text
                
                # Filter: ns '0' is main namespace (articles)
                # Skip meta pages, lists, etc.
                if ns == "0" and not any(skip in title for skip in [":", "Main Page", "List of"]):
                    revision = elem.find(f"{NAMESPACE}revision")
                    text_elem = revision.find(f"{NAMESPACE}text")
                    
                    if text_elem is not None and text_elem.text:
                        raw_text = text_elem.text
                        
                        # Only process pages with significant content
                        if len(raw_text) > 2000:
                            clean_text = clean_wiki_text(raw_text)
                            chunks = chunk_text(clean_text, title)
                            
                            if chunks:
                                print(f"\nProcessing {title} ({len(chunks)} chunks)...")
                                embeddings = []
                                valid_chunks = []
                                
                                for chunk in chunks:
                                    emb = generate_embedding(chunk)
                                    if emb:
                                        embeddings.append(emb)
                                        valid_chunks.append(chunk)
                                
                                if valid_chunks:
                                    add_chunks_to_store(title, valid_chunks, embeddings)
                                    count += 1
                
                # Free memory
                elem.clear()
                
                if limit and count >= limit:
                    break
    
    print(f"Finished processing {count} pages.")

if __name__ == "__main__":
    # Test with 5 pages first
    process_wikivoyage_dump(limit=5)
