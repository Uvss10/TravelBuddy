import os
import requests
from tqdm import tqdm

DUMP_URL = "https://dumps.wikimedia.org/enwikivoyage/latest/enwikivoyage-latest-pages-articles.xml.bz2"
DUMP_PATH = os.path.join("data", "enwikivoyage-latest-pages-articles.xml.bz2")

def download_wikivoyage_dump():
    """Downloads the latest Wikivoyage XML dump."""
    os.makedirs("data", exist_ok=True)
    
    if os.path.exists(DUMP_PATH):
        print(f"Dump already exists at {DUMP_PATH}")
        return DUMP_PATH

    print(f"Downloading Wikivoyage dump from {DUMP_URL}...")
    response = requests.get(DUMP_URL, stream=True)
    total_size = int(response.headers.get('content-length', 0))
    
    with open(DUMP_PATH, "wb") as f, tqdm(
        desc=DUMP_PATH,
        total=total_size,
        unit='iB',
        unit_scale=True,
        unit_divisor=1024,
    ) as bar:
        for data in response.iter_content(chunk_size=1024):
            size = f.write(data)
            bar.update(size)
            
    print(f"Download complete: {DUMP_PATH}")
    return DUMP_PATH

if __name__ == "__main__":
    download_wikivoyage_dump()
