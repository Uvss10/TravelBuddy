from rag.embedder import generate_embedding
from rag.vector_store import get_collection

def retrieve_top_chunks(query, n_results=5):
    """
    Given a query, retrieves the top N most similar chunks from the vector store.
    """
    query_embedding = generate_embedding(query)
    if not query_embedding:
        return []
    
    collection = get_collection()
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=n_results
    )
    
    return results['documents'][0] if results['documents'] else []

if __name__ == "__main__":
    query = "Top places to visit in Udaipur"
    chunks = retrieve_top_chunks(query)
    for i, chunk in enumerate(chunks):
        print(f"Chunk {i+1}:\n{chunk[:200]}...\n")
