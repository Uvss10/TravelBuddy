"""
backend/services/cinematic_video_service.py
============================================
CINEMATIC VIDEO ENGINE — Optimised for speed without sacrificing quality.

Key optimisations vs v1:
  • Resolution : 720×1280 (still 9:16, good-looking, 4× faster than 1080p)
  • FPS        : 30 instead of 60  (1 800 frames instead of 3 600)
  • Duration   : 30 s default (configurable up to 60 s)
  • Async jobs : render runs in a background thread; frontend polls /video/status/{job_id}
  • Frame pre-scale: photos resized once at load time, re-used per slide
"""

from __future__ import annotations

import os
import math
import shutil
import tempfile
import subprocess
import threading
import uuid
import time
from pathlib import Path
from typing import List, Optional, Dict

# ── Module imports ─────────────────────────────────────────────────────────────
from backend.config.themes            import get_theme, Theme
from backend.services.audio_analyzer  import analyze_audio, BeatMap, _synthetic_beatmap
from backend.services.media_intelligence import analyze_photos, sort_for_storytelling, PhotoMeta
from backend.services.timeline_builder   import build_timeline, TimelineSlot
from backend.services.motion_engine      import build_keyframe, get_transform
from backend.services.transition_composer import apply_transition
from backend.services.color_grader       import apply_grade, normalize_exposure
from backend.services.caption_renderer   import render_caption

import numpy as np
import cv2
from PIL import Image as PILImage

# ── Constants (Pro Quality: 1080p/60fps -> Optimized 720p/30fps) ─────────────
REEL_W        = 720          # Fast 720p vertical
REEL_H        = 1280
FPS           = 30           # Lower FPS for 2x faster rendering
DURATION_S    = 60           # 1 minute default reel
TOTAL_FRAMES  = FPS * DURATION_S          # 3600 frames
FADE_FRAMES   = int(FPS * 0.45)          # 0.45 s transition
VIDEO_BITRATE = "8000k"
OUTPUT_DIR    = Path("data/generated_videos")

# ── In-memory job registry ─────────────────────────────────────────────────────
# { job_id: { status, progress, message, video_url, error } }
_JOBS: Dict[str, dict] = {}
_JOBS_LOCK = threading.Lock()


def _set_job(job_id: str, **kwargs):
    with _JOBS_LOCK:
        if job_id not in _JOBS:
            _JOBS[job_id] = {}
        _JOBS[job_id].update(kwargs)

def get_job_status(job_id: str) -> dict:
    with _JOBS_LOCK:
        return dict(_JOBS.get(job_id, {"status": "not_found"}))


def _ensure_output_dir():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ── Photo loader ───────────────────────────────────────────────────────────────

def _calculate_sharpness(img: np.ndarray) -> float:
    """Calculate Laplacian variance (sharpness score). Higher is sharper."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return cv2.Laplacian(gray, cv2.CV_64F).var()


def _load_photo_bgr(path: str, w: int, h: int) -> np.ndarray:
    """
    Load + EXIF-correct + cover-crop a photo to w x h BGR array.

    FIX — Aspect ratio / quality:
    Load at 2x target resolution, crop at high-res, THEN downsample.
    This means the Ken Burns zoom (up to 1.15x) never samples below original
    resolution, eliminating the double-scale blur.
    """
    try:
        from PIL import ImageOps as _IOps
        pil = PILImage.open(path).convert("RGB")
        pil = _IOps.exif_transpose(pil)         # correct EXIF rotation

        orig_w, orig_h = pil.size
        target_ratio   = w / h
        src_ratio      = orig_w / orig_h

        # ── Cover-crop to target ratio ────────────────────────────────────────
        if src_ratio > target_ratio:
            # Image is wider — crop sides equally
            new_w = int(orig_h * target_ratio)
            left  = (orig_w - new_w) // 2
            pil   = pil.crop((left, 0, left + new_w, orig_h))
        else:
            # Image is taller — crop top/bottom
            # 35% from top so faces/subjects stay centred (not 30% which cuts chins)
            new_h = int(orig_w / target_ratio)
            top   = int((orig_h - new_h) * 0.35)
            pil   = pil.crop((0, top, orig_w, top + new_h))

        # ── FIX: Resize to 2x render resolution, not 1x ───────────────────────
        # Downsampling from 2x → 1x in get_transform gives clean sub-pixel
        # quality even after Ken Burns zoom (which scales up to 1.15x).
        # Without this, the zoom is applied on a 720px image causing blur.
        pil = pil.resize((w * 2, h * 2), PILImage.LANCZOS)
        return cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)
    except Exception:
        frame = np.zeros((h * 2, w * 2, 3), dtype=np.uint8)
        frame[:] = [59, 41, 30]
        return frame


def _gentle_enhance(frame: np.ndarray) -> np.ndarray:
    """
    Subtle per-channel CLAHE enhancement — improves local contrast without
    shifting overall brightness or altering skin/colour tones.

    This replaces the old normalize_exposure() which forced every image toward
    mean=128, causing overexposed faces and colour casts on intentionally dark
    or bright photos.
    """
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    # Very mild CLAHE (clipLimit=1.5) — just enough to lift shadow detail
    clahe = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8))
    l     = clahe.apply(l)
    enhanced = cv2.merge([l, a, b])
    return cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)


# ═════════════════════════════════════════════════════════════════════════════
# RENDERER — frame-by-frame pipeline, progress-tracked
# ═════════════════════════════════════════════════════════════════════════════

def _render_cinematic(
    slots: List[TimelineSlot],
    theme: Theme,
    out_path: str,
    audio_path: Optional[str] = None,
    job_id: Optional[str] = None,
    duration_s: int = DURATION_S,
) -> bool:
    _ensure_output_dir()

    fps   = FPS
    total = fps * duration_s

    tmp_silent = out_path.replace(".mp4", "_silent.mp4")
    
    ffmpeg_bin = _find_ffmpeg()
    if ffmpeg_bin:
        cmd = [
            ffmpeg_bin, "-y",
            "-f", "rawvideo",
            "-vcodec", "rawvideo",
            "-s", f"{REEL_W}x{REEL_H}",
            "-pix_fmt", "bgr24",
            "-r", str(fps),
            "-i", "-",
            "-an",
            # We use fast preset for rapid rendering
            "-vcodec", "libx264", "-preset", "fast",
            "-pix_fmt", "yuv420p",
            tmp_silent
        ]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
        
        def write_frame(frame: np.ndarray):
            if proc.stdin:
                try:
                    proc.stdin.write(frame.tobytes())
                except BrokenPipeError:
                    # ffmpeg likely crashed/exited early
                    pass
            
        def release_writer():
            if proc.stdin: proc.stdin.close()
            stdout, stderr = proc.communicate()
            if proc.returncode != 0:
                err_msg = stderr.decode(errors='ignore') if stderr else "Unknown ffmpeg error"
                print(f"[Cinematic] ffmpeg render error (code {proc.returncode}): {err_msg}")
    else:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(tmp_silent, fourcc, fps, (REEL_W, REEL_H))
        
        if not writer.isOpened():
            return False
            
        def write_frame(frame: np.ndarray):
            writer.write(frame)
            
        def release_writer():
            writer.release()

    def _prog(pct: int, msg: str):
        if job_id:
            _set_job(job_id, progress=pct, message=msg)

    try:
        _prog(5, "📸 Loading & pre-scaling photos…")

        # ── Pre-load all unique photos at render resolution ────────────────────
        photo_cache: dict[str, np.ndarray] = {}
        for slot in slots:
            p = slot.photo.path
            if p not in photo_cache:
                raw = _load_photo_bgr(p, REEL_W, REEL_H)
                
                # Sharpness filter: if Laplacian < 50, it's very blurry
                sharp = _calculate_sharpness(raw)
                if sharp < 50:
                    print(f"[Cinematic] Photo {Path(p).name} is blurry (score {sharp:.1f}). Applying subtle sharpening...")
                    # Apply a bit of sharpening filter instead of skipping (skipping breaks timeline)
                    kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
                    raw = cv2.filter2D(raw, -1, kernel)

                # ── FIX: Do NOT force-normalize exposure (causes blown-out faces).
                # Only apply gentle CLAHE per-channel to lift local contrast without
                # shifting overall brightness or skin tones.
                photo_cache[p] = _gentle_enhance(raw)

        # ── Pre-build keyframes ────────────────────────────────────────────────
        keyframes = {
            slot.index: build_keyframe(slot.motion, slot.energy, slot.index)
            for slot in slots
        }

        _prog(12, "🎬 Rendering frames…")

        frames_written = 0
        n_slots = len(slots)

        for slot_idx, slot in enumerate(slots):
            next_slot    = slots[slot_idx + 1] if slot_idx + 1 < n_slots else None
            frame_a_base = photo_cache[slot.photo.path]
            frame_b_base = photo_cache[next_slot.photo.path] if next_slot else frame_a_base

            slot_frames = max(1, round(slot.duration_s * fps))
            kf          = keyframes[slot.index]
            next_kf     = keyframes[next_slot.index] if next_slot else kf

            for f in range(slot_frames):
                if frames_written >= total:
                    break

                t_slide = f / max(slot_frames - 1, 1)

                frame_a = get_transform(frame_a_base, t_slide, kf, REEL_W, REEL_H)

                frames_left = slot_frames - f
                if frames_left <= FADE_FRAMES and next_slot is not None:
                    frame_b   = get_transform(frame_b_base, 0.0, next_kf, REEL_W, REEL_H)
                    t_trans   = 1.0 - (frames_left / FADE_FRAMES)
                    frame_out = apply_transition(frame_a, frame_b, t_trans,
                                                 REEL_W, REEL_H, name=slot.transition_out)
                else:
                    frame_out = frame_a

                frame_out = apply_grade(frame_out, theme.color_grade)

                if slot.caption:
                    frame_out = render_caption(
                        frame=frame_out, text=slot.caption,
                        style=theme.text_style, t=t_slide,
                        w=REEL_W, h=REEL_H,
                    )

                write_frame(frame_out)
                frames_written += 1

            # Progress update per slot
            pct = 12 + int(78 * frames_written / max(total, 1))
            _prog(min(pct, 89), f"🎞 Slot {slot_idx+1}/{n_slots} — {frames_written}/{total} frames")

    finally:
        release_writer()

    _prog(90, "🎵 Muxing audio with ffmpeg…")

    if audio_path and os.path.isfile(audio_path) and _find_ffmpeg():
        _mux_audio(tmp_silent, audio_path, out_path, duration_s)
        try:
            os.remove(tmp_silent)
        except Exception:
            pass
    else:
        if audio_path and not _find_ffmpeg():
            print("[Audio] ffmpeg not installed — video is silent. See _mux_audio for install instructions.")
        try:
            os.replace(tmp_silent, out_path)
        except Exception:
            shutil.copy(tmp_silent, out_path)

    return os.path.isfile(out_path) and os.path.getsize(out_path) > 10_000


def _find_ffmpeg() -> Optional[str]:
    """Find ffmpeg binary - checks PATH first, then common Windows install locations."""
    # 1. Check PATH (works on Linux / Mac / Windows if added to PATH)
    path_find = shutil.which("ffmpeg")
    if path_find:
        return path_find
    # 2. Common Windows install locations (including our custom install)
    windows_paths = [
        r"C:\Users\mansi\ffmpeg\bin\ffmpeg.exe",   # installed by TravelBuddy setup
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe",
        r"C:\tools\ffmpeg\bin\ffmpeg.exe",
        r"C:\ProgramData\chocolatey\bin\ffmpeg.exe",
    ]
    for p in windows_paths:
        if os.path.isfile(p):
            return p
    return None


def _mux_audio(video_path: str, audio_path: str, out_path: str, duration_s: int = DURATION_S):
    """Mux audio into video via ffmpeg. Shows clear warning if ffmpeg not found."""
    ffmpeg = _find_ffmpeg()
    if not ffmpeg:
        print("[Audio] WARNING: ffmpeg not found. Video will be silent.")
        print("[Audio] Install ffmpeg: https://ffmpeg.org/download.html")
        print("[Audio] Or: winget install ffmpeg  /  choco install ffmpeg")
        shutil.copy(video_path, out_path)
        return

    cmd = [
        ffmpeg, "-y",
        "-i", video_path,
        "-stream_loop", "-1",  # Loop audio if shorter than video
        "-i", audio_path,
        "-c:v", "copy",
        "-c:a", "aac", "-b:a", "192k",
        "-t", str(duration_s),
        "-map", "0:v:0",       # Use video from first input
        "-map", "1:a:0",       # Use audio from second input
        out_path,
    ]
    print(f"[Audio] Muxing: {ffmpeg} ...")
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=300)
        if result.returncode != 0:
            print(f"[Audio] ffmpeg error:\n{result.stderr.decode(errors='ignore')}")
            shutil.copy(video_path, out_path)
        else:
            print("[Audio] Mux complete.")
    except Exception as e:
        print(f"[Audio] Mux exception: {e}")
        shutil.copy(video_path, out_path)


# ═════════════════════════════════════════════════════════════════════════════
# BACKGROUND JOB RUNNER
# ═════════════════════════════════════════════════════════════════════════════

def _run_job(
    job_id: str,
    image_paths: List[str],
    captions: List[str],
    destination: str,
    theme_name: str,
    audio_path: Optional[str],
    lrc_content: Optional[str],
    duration_s: int,
    precomputed_metas: Optional[List[PhotoMeta]] = None,
):
    try:
        _set_job(job_id, status="running", progress=0, message="🚀 Starting cinematic pipeline…")

        import concurrent.futures

        theme = get_theme(theme_name)

        _set_job(job_id, progress=2, message="⚡ Analyzing audio and images concurrently...")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            if audio_path and os.path.isfile(audio_path):
                beatmap_future = executor.submit(analyze_audio, audio_path, float(duration_s))
            else:
                beatmap_future = executor.submit(_synthetic_beatmap, float(duration_s))
            
            if not precomputed_metas:
                photos_meta_future = executor.submit(analyze_photos, image_paths)

            # Parallel resolve
            beatmap = beatmap_future.result()
            
            if precomputed_metas:
                photos_meta = precomputed_metas
            else:
                photos_meta = photos_meta_future.result()

        if not photos_meta:
            _set_job(job_id, status="error", message="No usable photos found.")
            return

        if precomputed_metas:
            # Stage 3 explicitly passed precomputed_metas in the exact order the user curated.
            sorted_photos = photos_meta
        else:
            sorted_photos = sort_for_storytelling(photos_meta)

        _set_job(job_id, progress=8, message="🗂 Building 5-section EDL timeline…")
        from backend.services.caption_renderer import parse_lrc, get_lyric_at
        lyrics = parse_lrc(lrc_content) if lrc_content else []

        slots = build_timeline(
            photos=sorted_photos,
            beatmap=beatmap,
            theme=theme,
            captions=captions or [],
            force_keep_all=(precomputed_metas is not None),
        )
        if lyrics:
            for slot in slots:
                lyric = get_lyric_at(lyrics, slot.start_s)
                if lyric and not slot.caption:
                    slot.caption = lyric

        safe  = destination.replace(" ", "_").replace("/", "_")[:40]
        fname = f"cinematic_{safe}_{theme_name}_{job_id[:8]}.mp4"
        out   = str(OUTPUT_DIR / fname)

        _set_job(job_id, progress=10, message=f"🎬 Rendering {len(slots)} slots at 720p/30fps…")

        success = _render_cinematic(
            slots=slots, theme=theme,
            out_path=out, audio_path=audio_path,
            job_id=job_id, duration_s=duration_s,
        )

        if success:
            # ── Cloud Sync (Supabase) ──────────────────────────────────────────
            remote_url = None
            try:
                from backend.services.supabase_storage import supabase_storage
                if supabase_storage.enabled:
                    _set_job(job_id, message="☁️ Syncing to Supabase Cloud...")
                    remote_url = supabase_storage.upload_file(out, fname)
            except Exception as e:
                print(f"⚠️ Supabase Sync failed: {e}")

            _set_job(
                job_id,
                status="done",
                progress=100,
                message=(
                    f"✅ Cinematic reel ready — {len(sorted_photos)} photos, "
                    f"theme '{theme.display_name}', BPM {beatmap.bpm:.0f}, "
                    f"{'beat-synced' if audio_path else 'synthetic beat grid'}. "
                    f"{'(Uploaded to Oracle Cloud)' if remote_url else ''}"
                ),
                video_url=remote_url or f"/data/generated_videos/{fname}",
                beat_map={
                    "bpm":       round(beatmap.bpm, 1),
                    "sections":  beatmap.sections,
                    "cut_count": len(beatmap.cut_points),
                },
                photo_count=len(sorted_photos),
                theme=theme_name,
            )
        else:
            _set_job(job_id, status="error",
                     message="Render failed. Ensure OpenCV and Pillow are installed.")

    except Exception as exc:
        import traceback
        _set_job(job_id, status="error", message=f"Pipeline error: {exc}",
                 traceback=traceback.format_exc())


# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

def generate_cinematic_video(
    image_paths: List[str],
    captions: Optional[List[str]] = None,
    destination: str = "trip",
    theme_name: str = "cinematic",
    audio_path: Optional[str] = None,
    lrc_content: Optional[str] = None,
    duration_s: int = DURATION_S,
    precomputed_metas: Optional[List[PhotoMeta]] = None,
) -> dict:
    """
    Kick off a background cinematic render job.
    Returns immediately with a job_id for polling via /video/status/{job_id}.
    """
    _ensure_output_dir()
    job_id = str(uuid.uuid4())

    _set_job(job_id, status="queued", progress=0,
             message="Queued — starting shortly…",
             photo_count=len(image_paths), theme=theme_name)

    t = threading.Thread(
        target=_run_job,
        args=(job_id, image_paths, captions or [], destination,
              theme_name, audio_path, lrc_content, duration_s, precomputed_metas),
        daemon=True,
    )
    t.start()

    return {
        "status":      "queued",
        "job_id":      job_id,
        "engine":      "cinematic",
        "photo_count": len(image_paths),
        "theme":       theme_name,
        "message":     "Render started in background. Poll /video/status/{job_id} for progress.",
        "poll_url":    f"/video/status/{job_id}",
    }
