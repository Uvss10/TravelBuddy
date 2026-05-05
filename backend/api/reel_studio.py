"""
backend/api/reel_studio.py
===========================
Multi-Stage Reel Studio API

Replaces the single-shot /video/cinematic with a 3-step interactive workflow:

  POST /reel/analyze           → Stage 1: Upload photos, get AI analysis + grouping
  POST /reel/build-timeline    → Stage 2: User's curated list + theme → proposed slots
  POST /reel/render            → Stage 3: Final user-approved slots → background FFmpeg job
  GET  /reel/draft/{draft_id}  → Retrieve a previously stored draft
"""

from __future__ import annotations

import json
import uuid
import time
from pathlib import Path
from typing import List, Optional, Dict, Any

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from backend.services.media_intelligence import analyze_photos, sort_for_storytelling, PhotoMeta
from backend.services.cinematic_video_service import generate_cinematic_video, get_job_status
from backend.config.themes import list_themes, get_theme

router = APIRouter()

# ── Draft store (in-memory, survives restarts via JSON) ───────────────────────
DRAFT_DIR = Path("data/reel_drafts")
DRAFT_DIR.mkdir(parents=True, exist_ok=True)


def _save_draft(draft_id: str, data: dict):
    path = DRAFT_DIR / f"{draft_id}.json"
    with open(path, "w") as f:
        json.dump(data, f)


def _load_draft(draft_id: str) -> Optional[dict]:
    path = DRAFT_DIR / f"{draft_id}.json"
    if not path.exists():
        return None
    with open(path, "r") as f:
        return json.load(f)


# ── Schemas ───────────────────────────────────────────────────────────────────

class AnalyzeRequest(BaseModel):
    image_paths: List[str] = Field(..., description="Server-side paths from /images/upload")


class PhotoSelection(BaseModel):
    path: str
    caption: str = ""
    user_kept: bool = True   # False = user explicitly removed this photo


class BuildTimelineRequest(BaseModel):
    draft_id: str
    selected_photos: List[PhotoSelection] = Field(..., description="User-curated ordered list")
    theme: str = Field(default="cinematic")
    energy_level: float = Field(default=0.5, ge=0.0, le=1.0,
                                description="0=Relaxed (3s/photo) 1=HighEnergy (0.8s/photo)")
    duration_s: int = Field(default=60, ge=10, le=120)


class SlotOverride(BaseModel):
    index: int
    caption: str = ""
    photo_path: str


class RenderRequest(BaseModel):
    draft_id: str
    slot_overrides: List[SlotOverride] = Field(default=[])
    audio_path: Optional[str] = None
    lrc_content: Optional[str] = None
    destination: str = "trip"
    theme: str = "cinematic"
    duration_s: int = 60


# ── Endpoint 1: ANALYZE ────────────────────────────────────────────────────────

@router.post("/analyze")
def reel_analyze(req: AnalyzeRequest):
    """
    Stage 1 — AI Intelligence Layer.

    Analyzes all uploaded photos and returns:
      • Scored metadata per photo (blur, exposure, face, quality)
      • AI "Top Picks" (top 30% by quality score)
      • Grouping by shot_type: Landscapes / Portraits / Details
      • A draft_id to pass into Stage 2
    """
    valid_paths = [p for p in req.image_paths if Path(p).is_file()]
    if not valid_paths:
        raise HTTPException(status_code=422, detail="No valid image paths found on server.")

    photos: List[PhotoMeta] = analyze_photos(valid_paths)
    if not photos:
        raise HTTPException(status_code=422, detail="Could not analyze any of the provided photos.")

    # Sort by quality to produce "AI picks"
    sorted_by_quality = sorted(photos, key=lambda p: p.overall_quality, reverse=True)
    top_30_pct = max(5, int(len(sorted_by_quality) * 0.30))
    ai_pick_paths = {p.path for p in sorted_by_quality[:top_30_pct]}

    # Group by shot type for the curation wall
    groups: Dict[str, list] = {
        "Landscapes": [],
        "Portraits": [],
        "Details": [],
    }
    for p in photos:
        meta = {
                "path": p.path,
                "width": p.width,
                "height": p.height,
                "orientation": p.orientation,
                "shot_type": p.shot_type,
                # Technical
                "blur_score": p.blur_score,
                "exposure_score": p.exposure_score,
                "noise_score": p.noise_score,
                "entropy": p.entropy,
                # Semantic
                "face_score": p.face_score,
                "face_count": p.face_count,
                # Travel aesthetics (NEW v2)
                "overall_quality": p.overall_quality,
                "color_vibrancy": p.color_vibrancy,
                "golden_hour": p.golden_hour,
                "sky_presence": p.sky_presence,
                "saturation_score": p.saturation_score,
                # Composition (NEW v2)
                "composition_score": p.composition_score,
                "rule_of_thirds": p.rule_of_thirds,
                "symmetry": p.symmetry,
                # Story
                "story_position": p.story_position,
                "ai_pick": p.path in ai_pick_paths,
                "is_travel_hero": p.is_travel_hero,
                "ai_insight": p.ai_insight,
                "is_duplicate": p.is_duplicate,
            }
        if p.shot_type in ("wide",):
            groups["Landscapes"].append(meta)
        elif p.shot_type in ("close", "medium"):
            groups["Portraits"].append(meta)
        else:
            groups["Details"].append(meta)

    # Persist draft
    draft_id = str(uuid.uuid4())
    draft_data = {
        "draft_id": draft_id,
        "created_at": time.time(),
        "all_photos": [p.path for p in photos],
        "photo_meta": {
            p.path: {
                "overall_quality": p.overall_quality,
                "shot_type": p.shot_type,
                "orientation": p.orientation,
                "story_position": p.story_position,
                "face_score": p.face_score,
                "blur_score": p.blur_score,
                "exposure_score": p.exposure_score,
                "width": p.width,
                "height": p.height,
            }
            for p in photos
        },
        "ai_picks": list(ai_pick_paths),
        "stage": "analyzed",
    }
    _save_draft(draft_id, draft_data)

    return {
        "draft_id": draft_id,
        "total_analyzed": len(photos),
        "ai_pick_count": len(ai_pick_paths),
        "groups": groups,
        "all_photos": [
            {
                "path": p.path,
                "overall_quality": p.overall_quality,
                "shot_type": p.shot_type,
                "orientation": p.orientation,
                "ai_pick": p.path in ai_pick_paths,
                "is_travel_hero": p.is_travel_hero,
                "ai_insight": p.ai_insight,
                "is_duplicate": p.is_duplicate,
                # Technical
                "blur_score": p.blur_score,
                "exposure_score": p.exposure_score,
                "noise_score": p.noise_score,
                # Semantic
                "face_score": p.face_score,
                "face_count": p.face_count,
                # Travel aesthetics
                "color_vibrancy": p.color_vibrancy,
                "golden_hour": p.golden_hour,
                "sky_presence": p.sky_presence,
                # Composition
                "composition_score": p.composition_score,
                "rule_of_thirds": p.rule_of_thirds,
            }
            for p in photos
        ],
        "message": f"Analyzed {len(photos)} photos. AI recommends {len(ai_pick_paths)} top picks.",
    }


# ── Endpoint 2: BUILD TIMELINE ─────────────────────────────────────────────────

@router.post("/build-timeline")
def reel_build_timeline(req: BuildTimelineRequest):
    """
    Stage 2 — Storyboard Builder.

    Takes the user's curated + reordered photo list and returns a proposed
    timeline (slots) that the user can review before final render.

    energy_level slider:
        0.0 → ~3.0s per photo (slow / relaxed)
        0.5 → ~2.0s per photo (balanced)
        1.0 → ~0.8s per photo (fast cuts / high energy)
    """
    draft = _load_draft(req.draft_id)
    if draft is None:
        raise HTTPException(status_code=404, detail=f"Draft '{req.draft_id}' not found.")

    # Filter to only user-kept photos, preserving user order
    kept = [s for s in req.selected_photos if s.user_kept]
    if not kept:
        raise HTTPException(status_code=422, detail="No photos selected. Keep at least 1 photo.")

    theme = get_theme(req.theme)

    # Build a lightweight slot preview without running FFmpeg
    # Duration per photo varies by energy slider
    min_dur = 0.8
    max_dur = 3.5
    per_photo_s = max_dur - (max_dur - min_dur) * req.energy_level

    total_s = req.duration_s
    n = len(kept)
    # Clamp photo count to fit duration
    max_photos = max(3, int(total_s / min_dur))
    if n > max_photos:
        n = max_photos
        kept = kept[:n]

    slots = []
    t = 0.0
    section_map = {
        0: "intro",
    }
    # Simple section assignment
    for i, sel in enumerate(kept):
        ratio = i / max(n - 1, 1)
        if ratio < 0.08:
            section = "intro"
        elif ratio < 0.33:
            section = "exploration"
        elif ratio < 0.67:
            section = "peak"
        elif ratio < 0.92:
            section = "scenic"
        else:
            section = "outro"

        # Intro + outro get longer slots; peak gets shorter
        if section in ("intro", "outro"):
            dur = per_photo_s * 1.6
        elif section == "peak":
            dur = per_photo_s * 0.7
        else:
            dur = per_photo_s

        dur = round(dur, 2)
        end = round(min(t + dur, total_s), 2)

        # Pull stored meta
        meta = draft.get("photo_meta", {}).get(sel.path, {})

        slots.append({
            "index": i,
            "photo_path": sel.path,
            "caption": sel.caption,
            "start_s": round(t, 2),
            "end_s": end,
            "duration_s": round(end - t, 2),
            "section": section,
            "shot_type": meta.get("shot_type", "wide"),
            "orientation": meta.get("orientation", "landscape"),
            "overall_quality": meta.get("overall_quality", 0.5),
        })
        t = end
        if t >= total_s:
            break

    # Update draft with stage-2 info
    draft["stage"] = "timeline_built"
    draft["timeline_theme"] = req.theme
    draft["timeline_energy"] = req.energy_level
    draft["timeline_duration_s"] = req.duration_s
    draft["proposed_slots"] = slots
    draft["selected_paths"] = [s.path for s in kept]
    draft["captions"] = {s.path: s.caption for s in kept}
    _save_draft(req.draft_id, draft)

    return {
        "draft_id": req.draft_id,
        "theme": req.theme,
        "theme_display_name": theme.display_name,
        "energy_level": req.energy_level,
        "duration_s": req.duration_s,
        "photo_count": len(slots),
        "slots": slots,
        "available_themes": list_themes(),
        "message": f"Timeline built with {len(slots)} photos at {req.energy_level:.0%} energy.",
    }


# ── Endpoint 3: RENDER ─────────────────────────────────────────────────────────

@router.post("/render")
def reel_render(req: RenderRequest):
    """
    Stage 3 — Final Production.

    Starts the FFmpeg background render using the user-approved timeline.
    Returns a job_id to poll via GET /video/status/{job_id}.
    """
    draft = _load_draft(req.draft_id)
    if draft is None:
        raise HTTPException(status_code=404, detail=f"Draft '{req.draft_id}' not found.")

    if draft.get("stage") not in ("timeline_built", "rendered"):
        raise HTTPException(
            status_code=400,
            detail="Draft must be in 'timeline_built' stage. Call /reel/build-timeline first."
        )

    # Apply any caption overrides the user made in the annotation step
    caption_overrides: Dict[str, str] = {}
    for override in req.slot_overrides:
        caption_overrides[override.photo_path] = override.caption

    # Build final ordered image paths + captions
    slots = draft.get("proposed_slots", [])
    if not slots:
        raise HTTPException(status_code=422, detail="No timeline slots found in draft.")

    image_paths = []
    captions = []
    for slot in slots:
        path = slot["photo_path"]
        if not Path(path).is_file():
            continue
        image_paths.append(path)
        # Override caption if user edited it; else keep storyboard caption
        cap = caption_overrides.get(path, slot.get("caption", ""))
        captions.append(cap)

    if not image_paths:
        raise HTTPException(status_code=422, detail="No valid image files found for render.")

    precomputed_metas = []
    draft_meta = draft.get("photo_meta", {})
    for path in image_paths:
        m = draft_meta.get(path, {})
        from backend.services.media_intelligence import PhotoMeta
        precomputed_metas.append(PhotoMeta(
            path=path,
            shot_type=m.get("shot_type", "wide"),
            orientation=m.get("orientation", "landscape"),
            overall_quality=m.get("overall_quality", 0.5),
            # provide defaults for others if needed
        ))

    # Start the background render job
    result = generate_cinematic_video(
        image_paths=image_paths,
        captions=captions,
        destination=req.destination,
        theme_name=req.theme,
        audio_path=req.audio_path,
        lrc_content=req.lrc_content,
        duration_s=req.duration_s,
        precomputed_metas=precomputed_metas,
    )

    # Update draft
    draft["stage"] = "rendered"
    draft["render_job_id"] = result["job_id"]
    _save_draft(req.draft_id, draft)

    return {
        **result,
        "draft_id": req.draft_id,
        "photo_count": len(image_paths),
        "message": f"Render started for {len(image_paths)} photos. Poll /video/status/{result['job_id']}",
    }


# ── Endpoint: GET DRAFT ────────────────────────────────────────────────────────

@router.get("/draft/{draft_id}")
def get_draft(draft_id: str):
    """Retrieve full draft state (useful for resuming a session)."""
    draft = _load_draft(draft_id)
    if draft is None:
        raise HTTPException(status_code=404, detail=f"Draft '{draft_id}' not found.")
    return draft


# ── Endpoint: GET THEMES ───────────────────────────────────────────────────────

@router.get("/themes")
def get_reel_themes():
    """Return all available themes with their display names."""
    return {"themes": list_themes()}
