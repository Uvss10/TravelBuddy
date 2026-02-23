import os
import sys
from rag.download_dump import download_wikivoyage_dump
from rag.process_dump import process_wikivoyage_dump

def main():
    """
    Sets up the full RAG knowledge base.
    1. Downloads the latest Wikivoyage XML dump.
    2. Parses, cleans, chunks, and embeds the data.
    3. Stores it in ChromaDB.
    """
    print("=== TravelBuddy RAG Setup (Large Knowledge Base) ===")
    
    # 1. Download
    try:
        download_wikivoyage_dump()
    except Exception as e:
        print(f"Error downloading dump: {e}")
        sys.exit(1)
        
    # 2. Process
    # Start with a limit to avoid a multi-day process on first run, 
    # but allow user to specify.
    limit = None
    if len(sys.argv) > 1:
        try:
            limit = int(sys.argv[1])
            print(f"Processing limit set to {limit} pages.")
        except ValueError:
            pass
            
    try:
        process_wikivoyage_dump(limit=limit)
    except Exception as e:
        print(f"Error processing dump: {e}")
        sys.exit(1)

    print("\n✅ RAG Knowledge Base setup complete!")

if __name__ == "__main__":
    main()
