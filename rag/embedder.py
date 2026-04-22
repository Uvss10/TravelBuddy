import ollama

def generate_embedding(text):
    """
    Generates an embedding vector for the given text using Ollama's nomic-embed-text model.
    """
    try:
        response = ollama.embeddings(model='nomic-embed-text', prompt=text)
        return response['embedding']
    except Exception as e:
        print(f"Error generating embedding: {e}")
        return None

if __name__ == "__main__":
    # Test embedding
    test_text = "Udaipur is known as the City of Lakes."
    embedding = generate_embedding(test_text)
    if embedding:
        print(f"Generated embedding of length: {len(embedding)}")
    else:
        print("Failed to generate embedding.")
