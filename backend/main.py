import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
import asyncio
import time
import logging
import traceback
from fastapi import Request

from backend.api import itinerary, image_analysis, story, video, health, discovery, auth, history, reel_studio, admin
from backend.database import init_db

# ── Logging Setup ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.FileHandler("backend_debug.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("backend")


# ── Initialize Database Schema ──────────────────────────────────────────────
init_db()

app = FastAPI(
    title       = "TravelBuddy Pro API",
    description = "True Cinematic 1-minute reel generation with beat-sync",
    version     = "2.1.0",
)

@app.on_event("startup")
async def start_heartbeat():
    async def heartbeat():
        start_time = time.time()
        while True:
            uptime = int(time.time() - start_time)
            logger.info(f"[Heartbeat] Uptime: {uptime}s")
            await asyncio.sleep(10)
    asyncio.create_task(heartbeat())


# ── Upload size limit: 100 photos × 50 MB = 5 000 MB max body ──────────────────
MAX_UPLOAD_BYTES = 100 * 50 * 1024 * 1024  # 5 GB ceiling

class _LimitBody(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if request.method == "POST":
            cl = request.headers.get("content-length")
            if cl and int(cl) > MAX_UPLOAD_BYTES:
                from fastapi.responses import JSONResponse
                return JSONResponse({"detail": "Request body too large (max 5 GB)."}, status_code=413)
        return await call_next(request)

app.add_middleware(_LimitBody)

@app.middleware("http")
async def catch_exceptions_middleware(request: Request, call_next):
    try:
        return await call_next(request)
    except Exception as e:
        logger.error(f"GLOBAL CRASH: {e}")
        logger.error(traceback.format_exc())
        from fastapi.responses import JSONResponse
        return JSONResponse({"detail": "Internal Server Error", "error": str(e)}, status_code=500)

app.add_middleware(GZipMiddleware, minimum_size=1000)

app.add_middleware(
    CORSMiddleware,
    allow_origins     = ["*"],
    allow_credentials = True,
    allow_methods     = ["*"],
    allow_headers     = ["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(health.router,          tags=["Health"])
app.include_router(auth.router,            prefix="/auth",      tags=["Authentication"])
app.include_router(history.router,         prefix="/history",   tags=["History"])
app.include_router(itinerary.router,       prefix="/itinerary", tags=["Itinerary"])
app.include_router(image_analysis.router,  prefix="/images",    tags=["Images"])
app.include_router(story.router,           prefix="/story",     tags=["Story"])
app.include_router(video.router,           prefix="/video",     tags=["Video"])
app.include_router(reel_studio.router,     prefix="/reel",      tags=["Reel Studio"])
app.include_router(discovery.router,       prefix="/discovery", tags=["Discovery"])
app.include_router(admin.router,           prefix="/admin",     tags=["Admin"])

# ── Static files ──────────────────────────────────────────────────────────────
os.makedirs("data/selected_images",   exist_ok=True)
os.makedirs("data/generated_videos",  exist_ok=True)
app.mount("/data",     StaticFiles(directory="data"),     name="data")
app.mount("/",         StaticFiles(directory="frontend", html=True), name="frontend")
