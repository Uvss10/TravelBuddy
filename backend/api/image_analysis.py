from fastapi import APIRouter, UploadFile, File
from typing import List
import os
import shutil

from backend.services.image_service import process_uploaded_images

router = APIRouter()

UPLOAD_DIR = "data/uploaded_images"

@router.post("/upload")
async def upload_images(files: List[UploadFile] = File(...)):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    saved_files = []

    for file in files:
        file_path = os.path.join(UPLOAD_DIR, file.filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        saved_files.append(file_path)

    results = process_uploaded_images(saved_files)

    return {
        "uploaded_count": len(saved_files),
        "analysis_results": results
    }
