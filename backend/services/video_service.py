"""
video_service.py — Offline-capable video generation from images.

Priority order:
  1. MoviePy  (pip install moviepy pillow)  — pure-Python, offline, best quality
  2. FFmpeg CLI  (must be on PATH)          — offline, fastest, needs ffmpeg installed
  3. Offline-safe JSON fallback             — tells frontend to use JS Canvas generator

All processing is 100% local — no internet or cloud service used.

Video spec:
  • Resolution : 720 × 1280  (9:16 vertical reel)
  • Duration   : 60 seconds exactly
  • FPS        : 30
  • Per-photo  : floor(60 / n) seconds, remainder distributed to first slides
  • Effect     : Ken Burns (slight zoom) + cross-fade between slides
  • Encoding   : H.264 MP4 / VP9 WebM
"""

import os
import io
import json
import math
import shutil
import tempfile
import subprocess
from pathlib import Path
from typing import List, Optional

# ── Constants ─────────────────────────────────────────────────────────────────
REEL_W        = 720
REEL_H        = 1280
FPS           = 30
DURATION_S    = 60                      # 1 minute exactly
TOTAL_FRAMES  = FPS * DURATION_S        # 1 800
FADE_FRAMES   = 15                      # 0.5-second cross-fade
VIDEO_BITRATE = "5000k"
OUTPUT_DIR    = Path("data/generated_videos")


def _ensure_output_dir():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ═════════════════════════════════════════════════════════════════════════════
# 1. MoviePy engine  (pip install moviepy pillow)
# ═════════════════════════════════════════════════════════════════════════════
def _try_moviepy(image_paths: List[str], captions: List[str], out_path: str) -> bool:
    """Returns True if video was written successfully."""
    try:
        from moviepy.editor import (
            ImageClip, concatenate_videoclips, CompositeVideoClip,
            TextClip, ColorClip
        )
        from PIL import Image as PILImage
        import numpy as np
    except ImportError:
        return False

    n = len(image_paths)
    if n == 0:
        return False

    base_s = DURATION_S / n          # seconds per slide (float)
    clips  = []

    for idx, img_path in enumerate(image_paths):
        duration = base_s  # equal split; all exactly 60 s total

        try:
            # Load + crop to 9:16 (cover-fit)
            with PILImage.open(img_path) as _pil:
                pil = _pil.convert("RGB")
            orig_w, orig_h = pil.size
            target_ratio   = REEL_W / REEL_H
            src_ratio      = orig_w / orig_h

            if src_ratio > target_ratio:
                # image is wider — crop sides
                new_w = int(orig_h * target_ratio)
                left  = (orig_w - new_w) // 2
                pil   = pil.crop((left, 0, left + new_w, orig_h))
            else:
                # image is taller — crop top/bottom
                new_h = int(orig_w / target_ratio)
                top   = (orig_h - new_h) // 2
                pil   = pil.crop((0, top, orig_w, top + new_h))

            pil = pil.resize((REEL_W, REEL_H), PILImage.LANCZOS)
            arr = np.array(pil)

        except Exception:
            # Placeholder frame for unreadable images
            arr = np.zeros((REEL_H, REEL_W, 3), dtype=np.uint8)
            arr[:] = [30, 41, 59]  # dark slate

        clip = (ImageClip(arr)
                .set_duration(duration)
                .set_fps(FPS))

        # Ken Burns: zoom 1.00 → 1.06
        def _zoom(t, total=duration):
            factor = 1.0 + 0.06 * (t / total)
            return factor

        clip = clip.resize(lambda t: _zoom(t))
        clip = clip.crop(x_center=REEL_W / 2, y_center=REEL_H / 2,
                         width=REEL_W, height=REEL_H)

        # Caption
        cap = captions[idx] if idx < len(captions) else ""
        if cap:
            try:
                txt = (TextClip(cap, fontsize=36, color="white",
                                font="DejaVu-Sans-Bold",
                                method="caption", size=(REEL_W - 80, None),
                                align="center")
                       .set_position(("center", REEL_H - 200))
                       .set_duration(duration))
                # Gradient strip behind caption
                grad = (ColorClip(size=(REEL_W, 220), color=(0, 0, 0))
                        .set_opacity(0.55)
                        .set_position((0, REEL_H - 220))
                        .set_duration(duration))
                clip = CompositeVideoClip([clip, grad, txt], size=(REEL_W, REEL_H))
            except Exception:
                pass  # caption fallback — skip if TextClip fails

        # Cross-fade
        clip = clip.crossfadein(FADE_FRAMES / FPS)
        clips.append(clip)

    if not clips:
        return False

    final = concatenate_videoclips(clips, method="compose", padding=-FADE_FRAMES / FPS)
    final = final.set_duration(DURATION_S)          # enforce exactly 60 s

    try:
        final.write_videofile(
            out_path,
            fps=FPS,
            codec="libx264",
            bitrate=VIDEO_BITRATE,
            audio=False,
            verbose=False,
            logger=None,
        )
        return True
    except Exception:
        # Try WebM fallback
        try:
            webm_path = out_path.replace(".mp4", ".webm")
            final.write_videofile(webm_path, fps=FPS, codec="libvpx-vp9",
                                  bitrate=VIDEO_BITRATE, audio=False,
                                  verbose=False, logger=None)
            # Rename so caller gets expected path
            os.replace(webm_path, out_path)
            return True
        except Exception:
            return False


# ═════════════════════════════════════════════════════════════════════════════
# 2. FFmpeg CLI engine
# ═════════════════════════════════════════════════════════════════════════════
def _try_ffmpeg(image_paths: List[str], captions: List[str], out_path: str) -> bool:
    """Returns True if FFmpeg was available and produced output."""
    if not shutil.which("ffmpeg"):
        return False

    n = len(image_paths)
    if n == 0:
        return False

    # Seconds per slide
    base_s    = DURATION_S / n
    durations = [base_s] * n
    # Distribute leftover to first slide
    total_assigned = sum(durations)
    durations[0] += DURATION_S - total_assigned

    try:
        with tempfile.TemporaryDirectory() as tmp:
            # Write concat manifest
            concat_file = os.path.join(tmp, "concat.txt")
            with open(concat_file, "w", encoding="utf-8") as f:
                for img, dur in zip(image_paths, durations):
                    abs_img = os.path.abspath(img)
                    f.write(f"file '{abs_img}'\n")
                    f.write(f"duration {dur:.4f}\n")
                # FFmpeg concat demuxer needs last file repeated
                f.write(f"file '{os.path.abspath(image_paths[-1])}'\n")

            cmd = [
                "ffmpeg", "-y",
                "-f", "concat", "-safe", "0",
                "-i", concat_file,
                "-vf", (
                    f"scale={REEL_W}:{REEL_H}:force_original_aspect_ratio=increase,"
                    f"crop={REEL_W}:{REEL_H},"
                    f"zoompan=z='min(zoom+0.0008,1.06)':d={FPS}:s={REEL_W}x{REEL_H}:fps={FPS},"
                    "format=yuv420p"
                ),
                "-r", str(FPS),
                "-t", str(DURATION_S),
                "-c:v", "libx264",
                "-preset", "fast",
                "-b:v", VIDEO_BITRATE,
                "-an",
                out_path,
            ]
            result = subprocess.run(cmd, capture_output=True, timeout=300)
            if result.returncode == 0 and os.path.exists(out_path) and os.path.getsize(out_path) > 1024:
                return True
    except Exception:
        pass
    return False


# ═════════════════════════════════════════════════════════════════════════════
# 3. Public API
# ═════════════════════════════════════════════════════════════════════════════
def generate_video(
    image_paths: List[str],
    captions: Optional[List[str]] = None,
    destination: str = "trip",
) -> dict:
    """
    Generate a 1-minute video reel from image_paths.

    Returns:
        {
          "status"   : "done" | "fallback",
          "video_path": str | None,      # relative to project root
          "video_url" : str | None,      # HTTP path to serve via StaticFiles
          "engine"   : "moviepy" | "ffmpeg" | "js_canvas",
          "duration_s": 60,
          "photo_count": int,
          "message"  : str,
        }
    """
    _ensure_output_dir()

    caps   = captions or []
    n      = len(image_paths)
    safe   = destination.replace(" ", "_").replace("/", "_")[:40]
    fname  = f"reel_{safe}.mp4"
    out    = str(OUTPUT_DIR / fname)

    # ── Engine 1: MoviePy ─────────────────────────────────────────────────────
    if _try_moviepy(image_paths, caps, out):
        return {
            "status"     : "done",
            "video_path" : out,
            "video_url"  : f"/data/generated_videos/{fname}",
            "engine"     : "moviepy",
            "duration_s" : DURATION_S,
            "photo_count": n,
            "message"    : f"1-minute reel created with MoviePy ({n} photos).",
        }

    # ── Engine 2: FFmpeg CLI ──────────────────────────────────────────────────
    if _try_ffmpeg(image_paths, caps, out):
        return {
            "status"     : "done",
            "video_path" : out,
            "video_url"  : f"/data/generated_videos/{fname}",
            "engine"     : "ffmpeg",
            "duration_s" : DURATION_S,
            "photo_count": n,
            "message"    : f"1-minute reel created with FFmpeg ({n} photos).",
        }

    # ── Engine 3: JS Canvas fallback ─────────────────────────────────────────
    # Neither MoviePy nor FFmpeg available. Tell the frontend to generate
    # the video client-side using video_generator.js (Canvas + MediaRecorder).
    return {
        "status"     : "fallback",
        "video_path" : None,
        "video_url"  : None,
        "engine"     : "js_canvas",
        "duration_s" : DURATION_S,
        "photo_count": n,
        "message"    : (
            "Server-side engines (moviepy / ffmpeg) not available. "
            "The browser will generate the video locally using Canvas — "
            "no internet required. Install moviepy (`pip install moviepy pillow`) "
            "or ffmpeg for faster server-side generation."
        ),
    }
