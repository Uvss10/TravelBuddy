"""
backend/api/video.py — Video generation endpoints (Cinematic Engine v2)

POST /video/generate         — Legacy endpoint (preserved for compatibility)
POST /video/cinematic        — NEW: Full cinematic pipeline with all 9 modules
GET  /video/themes           — NEW: List available themes
GET  /video/status           — Health check
"""

import os
from fastapi import APIRouter, UploadFile, File, Form
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional
import shutil
import tempfile
from pathlib import Path

from backend.services.video_service           import generate_video
from backend.services.cinematic_video_service import generate_cinematic_video, get_job_status
from backend.config.themes                    import list_themes

router = APIRouter()

AUDIO_UPLOAD_DIR = Path("data/uploaded_audio")


# ── Schemas ───────────────────────────────────────────────────────────────────

class VideoGenerateRequest(BaseModel):
    image_paths : List[str]  = Field(default=[], description="Server-side paths to images.")
    captions    : List[str]  = Field(default=[], description="One caption per image (optional).")
    destination : str        = Field(default="my_trip", description="Trip name used in filename.")


class VideoGenerateResponse(BaseModel):
    status      : str
    engine      : str
    video_url   : Optional[str]
    duration_s  : int
    photo_count : int
    message     : str


class CinematicRequest(BaseModel):
    image_paths  : List[str]  = Field(default=[], description="Absolute server-side image paths.")
    captions     : List[str]  = Field(default=[], description="One caption per photo (optional).")
    destination  : str        = Field(default="my_trip")
    theme        : str        = Field(default="cinematic",
                                      description="cinematic | energetic | romantic | documentary | adventure")
    audio_path   : Optional[str] = Field(default=None,
                                         description="Server-side path to music file for beat sync.")
    lrc_content  : Optional[str] = Field(default=None,
                                         description="Raw .lrc lyric file contents for lyric overlay.")
    duration_s   : int        = Field(default=60, ge=10, le=120,
                                      description="Reel duration in seconds (default 60, max 120).")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/status")
def video_status():
    """Health-check — lists available engines and themes."""
    engines = ["cinematic (opencv)"]
    try:
        import moviepy  # noqa
        engines.append("moviepy")
    except ImportError:
        pass
    if shutil.which("ffmpeg"):
        engines.append("ffmpeg")

    return {
        "message":          "TravelBuddy Cinematic Video Engine ready",
        "available_engines": engines,
        "themes":           list_themes(),
        "output_spec": {
            "resolution":  "1080×1920 (9:16 vertical)",
            "fps":         60,
            "duration_s":  "10–120 (configurable)",
            "max_photos":  100,
        },
    }


@router.get("/themes")
def get_themes():
    """Return list of all available visual themes."""
    return {"themes": list_themes()}


@router.post("/cinematic")
def video_cinematic(req: CinematicRequest):
    """
    🎬 CINEMATIC ENGINE — Starts a background render job, returns immediately.
    Poll GET /video/status/{job_id} for live progress.
    """
    valid_paths = [p for p in req.image_paths if os.path.isfile(p)]
    if not valid_paths:
        return JSONResponse(
            status_code=422,
            content={
                "status":  "error",
                "message": "No valid image paths found on server.",
                "hint":    "Upload images first via POST /images/upload",
            },
        )

    result = generate_cinematic_video(
        image_paths = valid_paths,
        captions    = req.captions or [],
        destination = req.destination,
        theme_name  = req.theme,
        audio_path  = req.audio_path,
        lrc_content = req.lrc_content,
        duration_s  = req.duration_s,
    )
    # result contains { status:"queued", job_id, poll_url, ... }
    return result


@router.get("/status/{job_id}")
def job_status(job_id: str):
    """
    Poll for background render progress.
    Returns: { status, progress, message, video_url (when done), error (if failed) }
    """
    return get_job_status(job_id)


@router.post("/upload-audio")
async def upload_audio(file: UploadFile = File(...)):
    """
    Upload a music file (mp3, wav, ogg, flac, m4a) for beat sync.
    Returns the server-side path to pass into POST /video/cinematic as audio_path.
    """
    AUDIO_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    allowed_exts = {".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac"}
    suffix = Path(file.filename).suffix.lower()
    if suffix not in allowed_exts:
        return JSONResponse(
            status_code=422,
            content={"error": f"Unsupported audio format '{suffix}'. Accepted: {allowed_exts}"},
        )

    safe_name = file.filename.replace(" ", "_").replace("/", "_")
    dest      = AUDIO_UPLOAD_DIR / safe_name

    with dest.open("wb") as f:
        content = await file.read()
        f.write(content)

    return {
        "status":     "uploaded",
        "filename":   safe_name,
        "audio_path": str(dest),
        "size_mb":    round(len(content) / (1024 * 1024), 2),
    }


# ── Legacy endpoint (preserved) ────────────────────────────────────────────────

@router.post("/generate", response_model=VideoGenerateResponse)
def video_generate(req: VideoGenerateRequest):
    """
    Legacy slideshow generator (MoviePy / FFmpeg / JS-canvas).
    Use POST /video/cinematic for the full cinematic experience.
    """
    valid_paths = [p for p in req.image_paths if os.path.isfile(p)]
    if not valid_paths:
        return VideoGenerateResponse(
            status      = "fallback",
            engine      = "js_canvas",
            video_url   = None,
            duration_s  = 60,
            photo_count = len(req.image_paths),
            message     = "Image paths not found on server. Use the browser Canvas generator.",
        )

    result = generate_video(
        image_paths = valid_paths,
        captions    = req.captions,
        destination = req.destination,
    )
    return VideoGenerateResponse(**result)
