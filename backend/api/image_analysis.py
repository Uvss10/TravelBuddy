from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import List
import os
import shutil

from backend.services.image_service import process_uploaded_images

router = APIRouter()

UPLOAD_DIR   = "data/uploaded_images"
MAX_FILES    = 50
MAX_SIZE_MB  = 50
MAX_BYTES    = MAX_SIZE_MB * 1024 * 1024


@router.post("/upload")
async def upload_images(files: List[UploadFile] = File(...)):
    if len(files) > MAX_FILES:
        raise HTTPException(
            status_code=400,
            detail=f"Too many files. Maximum {MAX_FILES} photos per request."
        )

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    saved_files = []

    for file in files:
        # Validate content-type (allow all image types + RAW)
        ct = file.content_type or ""
        ext = (file.filename or "").rsplit(".", 1)[-1].lower()
        is_image = ct.startswith("image/") or ext in {
            "jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "tif",
            "avif", "heic", "heif", "svg",
            "nef", "cr2", "cr3", "arw", "dng", "raw", "raf", "orf", "rw2", "pef", "srw"
        }
        if not is_image:
            continue  # silently skip non-image files

        # Read in chunks to enforce 50 MB limit without loading all into RAM
        safe_name  = os.path.basename(file.filename or "image")
        file_path  = os.path.join(UPLOAD_DIR, safe_name)
        total_size = 0

        try:
            with open(file_path, "wb") as out:
                while chunk := await file.read(1024 * 256):  # 256 KB chunks
                    total_size += len(chunk)
                    if total_size > MAX_BYTES:
                        out.close()
                        os.remove(file_path)
                        raise HTTPException(
                            status_code=413,
                            detail=f"{safe_name} exceeds {MAX_SIZE_MB} MB limit."
                        )
                    out.write(chunk)
        except HTTPException:
            raise
        except Exception as e:
            continue  # skip files that fail to save

        saved_files.append(file_path)

    if not saved_files:
        raise HTTPException(status_code=400, detail="No valid image files were uploaded.")

    results = process_uploaded_images(saved_files)

    return {
        "uploaded_count"  : len(saved_files),
        "analysis_results": results,
    }


@router.get("/list")
def list_uploaded_images():
    """
    Returns all image paths currently stored in the upload and selected directories.
    Used by the cinematic engine when state.analysed is unavailable (e.g. page reload).
    """
    paths = []
    for directory in ["data/uploaded_images", "data/selected_images"]:
        if os.path.isdir(directory):
            for fname in sorted(os.listdir(directory)):
                if fname.lower().rsplit(".", 1)[-1] in {
                    "jpg", "jpeg", "png", "webp", "gif", "bmp",
                    "tiff", "tif", "avif", "heic", "heif"
                }:
                    paths.append(os.path.join(directory, fname).replace("\\", "/"))
    return {"images": paths, "count": len(paths)}
