"""
backend/api/video.py — Video generation endpoints.

POST /video/generate
  • Accepts a list of already-uploaded image paths (from /images/upload)
    plus optional captions and destination name.
  • Tries server-side generation (MoviePy → FFmpeg → JS-canvas fallback).
  • Returns JSON describing the result. The frontend uses video_url if present,
    or falls back to client-side Canvas rendering if engine == "js_canvas".

GET /video/status
  • Quick health-check — confirms the module is loaded.
"""

import os
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional

from backend.services.video_service import generate_video

router = APIRouter()


# ── Request / Response models ─────────────────────────────────────────────────

class VideoGenerateRequest(BaseModel):
    image_paths : List[str]  = Field(
        default=[],
        description="Server-side paths to images (as returned by /images/upload).",
    )
    captions    : List[str]  = Field(default=[], description="One caption per image (optional).")
    destination : str        = Field(default="my_trip", description="Trip destination name (used in filename).")


class VideoGenerateResponse(BaseModel):
    status      : str                       # "done" | "fallback"
    engine      : str                       # "moviepy" | "ffmpeg" | "js_canvas"
    video_url   : Optional[str]             # served via /data — None if fallback
    duration_s  : int
    photo_count : int
    message     : str


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/status")
def video_status():
    """Health-check for the video module."""
    engines = []
    try:
        import moviepy  # noqa
        engines.append("moviepy")
    except ImportError:
        pass
    try:
        import shutil
        if shutil.which("ffmpeg"):
            engines.append("ffmpeg")
    except Exception:
        pass

    return {
        "message"         : "Video generation module ready",
        "available_engines": engines if engines else ["js_canvas (browser fallback)"],
        "max_photos"      : 50,
        "max_mb_per_photo": 50,
        "output_duration_s": 60,
    }


@router.post("/generate", response_model=VideoGenerateResponse)
def video_generate(req: VideoGenerateRequest):
    """
    Generate a 1-minute slideshow video from pre-uploaded server images.

    If server-side rendering is unavailable, returns engine='js_canvas'
    so the frontend can generate offline via Canvas + MediaRecorder.
    """
    # Validate that at least some paths exist on disk
    valid_paths = [p for p in req.image_paths if os.path.isfile(p)]
    if not valid_paths:
        # All paths missing — tell frontend to use JS generator with its own blob URLs
        return VideoGenerateResponse(
            status      = "fallback",
            engine      = "js_canvas",
            video_url   = None,
            duration_s  = 60,
            photo_count = len(req.image_paths),
            message     = "Image paths not found on server. Use the browser Canvas generator — works 100% offline.",
        )

    result = generate_video(
        image_paths = valid_paths,
        captions    = req.captions,
        destination = req.destination,
    )

    return VideoGenerateResponse(**result)
