import os
import requests
from bs4 import BeautifulSoup
import re

RAW_DATA_DIR = os.path.join("data", "wikivoyage_raw")
CHUNK_DATA_DIR = os.path.join("data", "wikivoyage_chunks")

def fetch_wikivoyage_data(city):
    """Fetches text content from Wikivoyage for a given city."""
    url = f"https://en.wikivoyage.org/wiki/{city.replace(' ', '_')}"
    response = requests.get(url)
    if response.status_code != 200:
        print(f"Error fetching data for {city}: {response.status_code}")
        return None
    
    soup = BeautifulSoup(response.text, 'lxml')
    # Remove unwanted elements
    for script in soup(["script", "style", "nav", "footer", "header"]):
        script.decompose()
    
    # Extract text from main body
    content = soup.find('div', {'id': 'mw-content-text'})
    if not content:
        return None
    
    text = content.get_text(separator='\n')
    # Basic cleanup
    text = re.sub(r'\n+', '\n', text)
    text = re.sub(r'\[edit\]', '', text)
    
    # Save raw data
    os.makedirs(RAW_DATA_DIR, exist_ok=True)
    with open(os.path.join(RAW_DATA_DIR, f"{city.lower()}.txt"), "w", encoding="utf-8") as f:
        f.write(text)
    
    return text

def chunk_text(text, city, min_words=500, max_words=800):
    """Splits text into chunks of 500-800 words."""
    words = text.split()
    chunks = []
    current_chunk = []
    current_word_count = 0
    
    for word in words:
        current_chunk.append(word)
        current_word_count += 1
        
        if current_word_count >= max_words:
            chunks.append(" ".join(current_chunk))
            current_chunk = []
            current_word_count = 0
            
    if current_chunk:
        chunks.append(" ".join(current_chunk))
    
    # Save chunks
    os.makedirs(CHUNK_DATA_DIR, exist_ok=True)
    city_chunk_dir = os.path.join(CHUNK_DATA_DIR, city.lower())
    os.makedirs(city_chunk_dir, exist_ok=True)
    
    for i, chunk in enumerate(chunks):
        with open(os.path.join(city_chunk_dir, f"chunk_{i}.txt"), "w", encoding="utf-8") as f:
            f.write(chunk)
            
    return chunks

def load_and_process(city):
    print(f"Processing data for {city}...")
    text = fetch_wikivoyage_data(city)
    if text:
        chunks = chunk_text(text, city)
        print(f"Created {len(chunks)} chunks for {city}.")
        return chunks
    return []

if __name__ == "__main__":
    # Example usage
    load_and_process("Udaipur")
