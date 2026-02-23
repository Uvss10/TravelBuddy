import os
from rag.data_loader import load_and_process
from rag.embedder import generate_embedding
from rag.vector_store import add_chunks_to_store

def ingest_city_data(city):
    """
    Full ingestion pipeline for a city:
    1. Fetch and chunk Wikivoyage data.
    2. Generate embeddings for each chunk.
    3. Add chunks and embeddings to ChromaDB.
    """
    # Step 1: Fetch and Chunk
    chunks = load_and_process(city)
    if not chunks:
        print(f"No data found for {city}")
        return
    
    # Step 2: Generate Embeddings
    print(f"Generating embeddings for {len(chunks)} chunks...")
    embeddings = []
    for i, chunk in enumerate(chunks):
        emb = generate_embedding(chunk)
        if emb:
            embeddings.append(emb)
        else:
            print(f"Failed to generate embedding for chunk {i}")
            # If one fails, we might want to skip or handle it. 
            # For simplicity, we'll append a dummy or skip. Here we skip.
            chunks.pop(i) # Be careful with indexing when popping
    
    # Recalculate chunks if some failed (better to just filter)
    valid_chunks = [chunks[i] for i in range(len(embeddings))]
    
    # Step 3: Add to Vector Store
    add_chunks_to_store(city, valid_chunks, embeddings)
    print(f"Ingestion complete for {city}!")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        city = sys.argv[1]
    else:
        city = "Udaipur"
    ingest_city_data(city)
