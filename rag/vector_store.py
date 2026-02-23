import chromadb
import os

DB_PATH = os.path.join("data", "chroma_db")

def get_chroma_client():
    """Initializes and returns a ChromaDB client."""
    return chromadb.PersistentClient(path=DB_PATH)

def add_chunks_to_store(city, chunks, embeddings):
    """
    Stores text chunks and their embeddings in ChromaDB.
    """
    client = get_chroma_client()
    collection = client.get_or_create_collection(name="travel_knowledge")
    
    ids = [f"{city.lower().replace(' ', '_')}_{i}" for i in range(len(chunks))]
    metadatas = [{"city": city.lower(), "chunk_id": i} for i in range(len(chunks))]
    
    collection.add(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas
    )
    print(f"Added {len(chunks)} chunks to vector store for {city}.")

def get_collection():
    client = get_chroma_client()
    return client.get_or_create_collection(name="travel_knowledge")

if __name__ == "__main__":
    client = get_chroma_client()
    print("ChromaDB client initialized.")
