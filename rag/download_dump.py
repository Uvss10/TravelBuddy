import os
import time
import requests
from tqdm import tqdm

DUMP_URL = "https://dumps.wikimedia.org/enwikivoyage/latest/enwikivoyage-latest-pages-articles.xml.bz2"
DUMP_PATH = os.path.join("data", "enwikivoyage-latest-pages-articles.xml.bz2")

CHUNK_SIZE = 1024 * 1024  # 1 MiB chunks for faster disk/network throughput
MAX_RETRIES = 8
CONNECT_TIMEOUT_S = 20
READ_TIMEOUT_S = 120


def _get_remote_size(url: str) -> int | None:
    """Best-effort remote size lookup. Returns None if unavailable."""
    try:
        head = requests.head(url, allow_redirects=True, timeout=(CONNECT_TIMEOUT_S, READ_TIMEOUT_S))
        head.raise_for_status()
        value = head.headers.get("content-length")
        return int(value) if value else None
    except Exception:
        return None

def download_wikivoyage_dump():
    """Downloads the latest Wikivoyage XML dump with retry + resume support."""
    os.makedirs("data", exist_ok=True)

    remote_size = _get_remote_size(DUMP_URL)
    existing_size = os.path.getsize(DUMP_PATH) if os.path.exists(DUMP_PATH) else 0

    if existing_size and remote_size and existing_size == remote_size:
        print(f"Dump already exists at {DUMP_PATH}")
        return DUMP_PATH

    if existing_size and remote_size and existing_size > remote_size:
        print("Local dump is larger than remote. Restarting download from scratch...")
        os.remove(DUMP_PATH)
        existing_size = 0

    print(f"Downloading Wikivoyage dump from {DUMP_URL}...")
    attempt = 0

    # If we know remote size, show full progress with resume position.
    with tqdm(
        desc=DUMP_PATH,
        total=remote_size,
        initial=existing_size,
        unit="iB",
        unit_scale=True,
        unit_divisor=1024,
    ) as bar:
        while True:
            downloaded = os.path.getsize(DUMP_PATH) if os.path.exists(DUMP_PATH) else 0

            if remote_size and downloaded >= remote_size:
                break

            headers = {"Range": f"bytes={downloaded}-"} if downloaded else {}

            try:
                response = requests.get(
                    DUMP_URL,
                    stream=True,
                    headers=headers,
                    timeout=(CONNECT_TIMEOUT_S, READ_TIMEOUT_S),
                )
                response.raise_for_status()

                # If resume was requested but server ignored Range, restart cleanly.
                if downloaded > 0 and response.status_code == 200:
                    print("Server ignored resume header. Restarting from 0...")
                    downloaded = 0
                    if os.path.exists(DUMP_PATH):
                        os.remove(DUMP_PATH)
                    bar.reset(total=remote_size)

                mode = "ab" if downloaded else "wb"
                with open(DUMP_PATH, mode) as f:
                    for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                        if not chunk:
                            continue
                        f.write(chunk)
                        bar.update(len(chunk))

                # Reset retry counter after a successful streaming chunk pass.
                attempt = 0

            except (requests.exceptions.RequestException, OSError) as exc:
                attempt += 1
                if attempt > MAX_RETRIES:
                    raise RuntimeError(
                        f"Download failed after {MAX_RETRIES} retries. Partial file kept at {DUMP_PATH}."
                    ) from exc

                wait_s = min(2 ** attempt, 30)
                print(f"Download interrupted ({exc}). Retrying in {wait_s}s [{attempt}/{MAX_RETRIES}]...")
                time.sleep(wait_s)

    final_size = os.path.getsize(DUMP_PATH) if os.path.exists(DUMP_PATH) else 0
    if remote_size and final_size != remote_size:
        raise RuntimeError(
            f"Downloaded file size mismatch. Expected {remote_size}, got {final_size}. "
            f"Run again to resume."
        )

    print(f"Download complete: {DUMP_PATH}")
    return DUMP_PATH

if __name__ == "__main__":
    download_wikivoyage_dump()
