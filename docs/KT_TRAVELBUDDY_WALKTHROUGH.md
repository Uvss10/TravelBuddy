# TravelBuddy AI - Knowledge Transfer (KT) Walkthrough

## 1. Document Purpose

This KT document is a practical, end-to-end onboarding guide for the TravelBuddy codebase.
After reading this, a new developer should be able to:

- Understand what the product does and how modules connect.
- Set up and run the backend, web frontend, and optional mobile app.
- Understand AI mode switching (Cloud Groq vs Local Ollama).
- Trace the full request flow for itinerary, image analysis, story, and video generation.
- Run and validate the app locally.
- Troubleshoot common setup/runtime failures.

---

## 2. Product Overview

TravelBuddy is a privacy-first travel assistant with three major user outcomes:

1. Generate route-optimized itineraries.
2. Analyze uploaded travel photos and rank/select high-quality shots.
3. Produce short cinematic travel reels with captions/audio/theme control.

The app is implemented as:

- FastAPI backend (serves both API and static web frontend).
- Browser frontend (single-page experience in frontend/).
- Optional Flutter mobile client (mobile/).
- RAG subsystem backed by ChromaDB for itinerary context enrichment.

---

## 3. High-Level Architecture

### 3.1 Runtime components

- Backend API: FastAPI app in backend/main.py
- Frontend SPA: static files in frontend/, mounted at /
- Data storage (local): data/ for uploads, selected images, generated videos, chroma_db
- AI providers:
  - Cloud: Groq API
  - Local: Ollama HTTP server
  - Fallback: mock/offline behavior in selected flows
- RAG knowledge store: Chroma PersistentClient under data/chroma_db

### 3.2 App mounts and routing behavior

- API routes are mounted first in backend/main.py.
- Static /data is mounted for generated assets.
- Frontend static mount at / is intentionally last to avoid shadowing API routes.

This means:

- Open app UI at http://127.0.0.1:8000/
- API remains accessible at /health, /itinerary/*, /images/*, /story/*, /video/*

---

## 4. Backend Structure and Responsibilities

### 4.1 Entry point

- backend/main.py

Responsibilities:

- Creates FastAPI app metadata.
- Adds body-size limit middleware for POST uploads.
- Enables GZip and permissive CORS.
- Registers routers: health, itinerary, image_analysis, story, video.
- Creates local data directories and mounts static resources.

### 4.2 API route modules

- backend/api/health.py
  - GET /health
  - GET /llm/status
  - POST /llm/toggle_mode

- backend/api/itinerary.py
  - POST /itinerary/generate
  - POST /itinerary/edit

- backend/api/image_analysis.py
  - POST /images/upload
  - GET /images/list
  - POST /images/clear

- backend/api/story.py
  - GET /story/status
  - POST /story/generate

- backend/api/video.py
  - GET /video/status
  - GET /video/themes
  - POST /video/cinematic
  - GET /video/status/{job_id}
  - POST /video/upload-audio
  - POST /video/generate (legacy)

### 4.3 Schema layer

- backend/schemas/itinerary_schema.py
- backend/schemas/story_schema.py
- backend/schemas/image_schema.py (currently empty placeholder)

### 4.4 Service layer (core business logic)

- itinerary_service.py: itinerary generation/edit via RAG pipeline + budget estimation.
- image_service.py: image metrics, dedupe, quality score, refinement to reel-friendly format.
- story_service.py: cinematic narrative generation + robust parse/fallback.
- video_service.py: legacy slideshow generation with MoviePy/FFmpeg/browser fallback.
- cinematic_video_service.py: background-job cinematic renderer with themed transitions/motion/audio sync.
- budget_service.py: budget estimate support for itinerary responses.
- Additional cinematic modules:
  - audio_analyzer.py
  - media_intelligence.py
  - timeline_builder.py
  - motion_engine.py
  - transition_composer.py
  - color_grader.py
  - caption_renderer.py

---

## 5. Frontend Flow (Browser App)

Frontend lives in frontend/index.html + frontend/app.js + frontend/style.css.

Two primary tabs are exposed:

- Photo -> Reel
- Trip Planner

### 5.1 Photo -> Reel flow

1. User selects destination/tone and uploads photos.
2. Frontend POSTs to /images/upload.
3. Backend analyzes + ranks photos and returns selected image paths.
4. Frontend POSTs to /story/generate for narration/captions/hashtags.
5. Optional audio upload POST /video/upload-audio.
6. Frontend starts cinematic job via POST /video/cinematic.
7. Frontend polls GET /video/status/{job_id} until done.
8. Video served through /data/generated_videos/... URL.

### 5.2 Trip Planner flow

1. User submits destination, days, budget, interests, style/group constraints.
2. Frontend POSTs /itinerary/generate.
3. Backend runs RAG retrieval + LLM generation and returns structured JSON itinerary.
4. User can request modifications via POST /itinerary/edit.

### 5.3 AI mode pill behavior

Frontend displays provider state from GET /llm/status and toggles mode using POST /llm/toggle_mode.

---

## 6. AI Provider Strategy

Implemented in backend/utils.py and health endpoints:

Priority and mode behavior:

- Cloud-first or local-first depends on PREFER_LOCAL_LLM in .env.
- If preferred provider unavailable, fallback logic is applied.
- Offline mode is exposed when neither provider is available.

Environment keys used:

- GROQ_API_KEY
- PREFER_LOCAL_LLM
- OLLAMA_MODEL
- GROQ_VISION_MODEL
- OLLAMA_VISION_MODEL

Important:

- .env is loaded from project root.
- toggle_mode updates process env and persists back to .env.

---

## 7. RAG Subsystem (Itinerary Context)

Top-level scripts in rag/ and rag_setup.py support creating a Wikivoyage-backed knowledge base.

### 7.1 RAG generation pipeline

- itinerary_service.generate_itinerary -> rag.rag_pipeline.rag_generate_itinerary
- rag_generate_itinerary:
  - builds semantic query
  - retrieves top chunks via rag/retriever.py
  - composes strict route-optimization prompt
  - calls LLM and returns JSON-ish response

### 7.2 Vector storage

- rag/vector_store.py uses chromadb.PersistentClient(path=data/chroma_db)
- collection name: travel_knowledge

### 7.3 Setup path

- rag_setup.py:
  - downloads Wikivoyage dump
  - processes/chunks/embeds documents
  - ingests into Chroma

Operational note:

- Initial RAG setup can be long-running and data-heavy.

---

## 8. Image Analysis Pipeline

Implemented primarily in backend/services/image_service.py and models/vision/*.

### 8.1 Upload constraints

- Max 100 files per request.
- Max 50 MB per file.
- Supports common image + RAW formats.
- Old upload/selected directories are cleared per new upload request.

### 8.2 Scoring

Per image metrics include:

- Blur
- Sharpness
- Exposure
- Contrast
- Entropy
- Face score

Then normalized weighted scoring calculates final_quality_score.

### 8.3 Dedupe and refine

- pHash deduplication removes near-duplicates.
- Top scored images are refined to 1080x1920 WebP for reel consistency.

### 8.4 Vision boost

For top candidates, vision LLM scoring can add aesthetic bonuses and emotion labels.

---

## 9. Video Generation Paths

### 9.1 Legacy generator (video_service.py)

Engine priority:

1. MoviePy
2. FFmpeg CLI
3. Browser-side JS canvas fallback

Returns status + engine + video_url (if generated server-side).

### 9.2 Cinematic engine (cinematic_video_service.py)

- Starts async background job.
- Job state tracked in in-memory registry.
- Frontend polls /video/status/{job_id}.
- Uses theme config + timeline + motion + transitions + color grading.
- Supports optional audio mux (ffmpeg required).

### 9.3 Theme system

Defined in backend/config/themes.py.
Themes include:

- cinematic
- energetic
- romantic
- documentary
- adventure

Each theme configures:

- cut frequency and beat sensitivity
- motion profile
- transition pool
- color grade
- caption style

---

## 10. Data Directories and Artifacts

At runtime, the backend creates/uses:

- data/uploaded_images
- data/selected_images
- data/generated_videos
- data/uploaded_audio
- data/chroma_db

These are local machine artifacts and should generally be gitignored.

---

## 11. Setup and Runbook (Linux)

### 11.1 Prerequisites

- Python 3.10+
- Optional for local AI: Ollama
- Optional for faster/feature-complete video/audio mux: ffmpeg on PATH

### 11.2 First-time setup

1. Create virtual environment

python3 -m venv venv

2. Activate

source venv/bin/activate

3. Install dependencies

python -m pip install -r requirements.txt --default-timeout=1000 --retries=20

(Use increased timeout/retries for large torch/nvidia wheels on slow networks.)

### 11.3 Configure .env

Create/update root .env with required keys. Recommended minimum:

GROQ_API_KEY=<your_key>
PREFER_LOCAL_LLM=false
OLLAMA_MODEL=mistral
GROQ_VISION_MODEL=llama-3.2-11b-vision-preview
OLLAMA_VISION_MODEL=llama3.2-vision

### 11.4 Run backend + web frontend

python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000

Open:

- App UI: http://127.0.0.1:8000/
- Health: http://127.0.0.1:8000/health
- OpenAPI docs: http://127.0.0.1:8000/docs

### 11.5 Optional: prepare local Ollama

- Install Ollama
- Pull model(s) used by .env
- Start Ollama service (default localhost:11434)

### 11.6 Optional: run Flutter mobile app

cd mobile
flutter pub get
# update baseUrl in lib/config/api_config.dart
flutter run

---

## 12. API Quick Reference

### 12.1 Health and AI mode

- GET /health
- GET /llm/status
- POST /llm/toggle_mode

### 12.2 Itinerary

POST /itinerary/generate
Sample request:

{
  "destination": "Jaipur",
  "days": 3,
  "budget": "medium",
  "interests": ["history", "food"],
  "travel_style": "cultural",
  "group_type": "solo",
  "starting_location": "MI Road",
  "custom_constraints": "avoid late nights"
}

POST /itinerary/edit
Sample request:

{
  "existing_plan": {"days": []},
  "modification": "replace day 2 with indoor options",
  "interests": ["history"]
}

### 12.3 Images

- POST /images/upload (multipart files[])
- GET /images/list
- POST /images/clear

### 12.4 Story

POST /story/generate
Sample request:

{
  "destination": "Jaipur",
  "scene_tags": ["amber fort", "sunset", "street food"],
  "tone": "adventurous and inspiring"
}

### 12.5 Video

- GET /video/status
- GET /video/themes
- POST /video/upload-audio (multipart file)
- POST /video/cinematic
- GET /video/status/{job_id}
- POST /video/generate (legacy)

---

## 13. Testing and Validation Status

Current test files exist but are empty placeholders:

- tests/test_itinerary.py
- tests/test_story.py
- tests/test_image_selection.py

Recommended immediate test coverage:

1. API contract tests for all route modules.
2. Service-level tests for parse/fallback logic in itinerary/story services.
3. Image pipeline tests with sample fixtures (valid, invalid, duplicate, oversize).
4. Video job lifecycle tests (queued -> running -> done/error).
5. Integration smoke test: upload -> story -> cinematic job -> poll completion.

---

## 14. Common Operational Issues and Fixes

### 14.1 pip install timeout on large wheels

Symptom:

- ReadTimeout while downloading nvidia_* or torch wheels.

Fix:

python -m pip install -r requirements.txt --default-timeout=1000 --retries=20

### 14.2 AI not responding

Checks:

1. Call GET /llm/status.
2. Verify GROQ_API_KEY present for cloud mode.
3. Verify Ollama is running on 127.0.0.1:11434 for local mode.
4. Toggle mode via /llm/toggle_mode.

### 14.3 Video has no audio

Likely cause:

- ffmpeg not found in PATH, so mux step falls back to silent video.

Fix:

- Install ffmpeg and ensure executable is discoverable from shell PATH.

### 14.4 Large upload rejected

- /images/upload enforces per-file max size.
- main app also enforces POST body size via content-length middleware.

### 14.5 Frontend can load, but API calls fail

- Verify uvicorn is running and mounted routes respond from same host/port.
- Open /docs and execute endpoints manually.

---

## 15. Security and Configuration Notes

1. Never commit real API keys to version control.
2. Use .env locally and keep secret values out of docs/screenshots.
3. Rotate keys immediately if exposed.
4. Consider adding a .env.example with placeholders only.

---

## 16. Suggested Developer Onboarding Checklist

Day 1 checklist:

1. Clone repo and create venv.
2. Install requirements with timeout/retry flags.
3. Configure .env (cloud key and/or local model).
4. Start backend and confirm /health and /llm/status.
5. Run one end-to-end web flow:
   - Upload 5-10 photos
   - Generate story
   - Start cinematic render and poll to completion
6. Generate one itinerary and one itinerary edit.
7. Read cinematic module files and theme registry.
8. Review docs/architecture_diagram.png and docs/dataflow_diagram.png.

---

## 17. Technical Debt and Priority Improvements

1. Add real automated tests (currently mostly missing).
2. Resolve comment mismatch in upload size message in backend/main.py (constant comment vs returned message differ).
3. Add formal logging instead of print statements.
4. Add persistent job store (Redis/DB) for cinematic job state across restarts.
5. Add request/response examples to OpenAPI docs via schema examples.
6. Add CPU-only dependency profile for low-bandwidth installs (avoid heavy CUDA wheels where not needed).
7. Add .env.example and secret scanning in CI.

---

## 18. Appendix - Useful Commands

Run server:

python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000

Install requirements (robust network settings):

python -m pip install -r requirements.txt --default-timeout=1000 --retries=20

RAG setup:

python rag_setup.py

RAG setup with page limit:

python rag_setup.py 5000

Flutter app run:

cd mobile && flutter pub get && flutter run

---

## 19. Ownership Pointers (By Area)

- API gateway and app mounts: backend/main.py
- LLM/provider switching logic: backend/utils.py, backend/api/health.py
- Itinerary generation/RAG integration: backend/services/itinerary_service.py, rag/*
- Image ranking/selection: backend/services/image_service.py, models/vision/*
- Story generation: backend/services/story_service.py
- Cinematic rendering stack: backend/services/cinematic_video_service.py + theme/motion/timeline modules
- Frontend UX flow and endpoint wiring: frontend/app.js
- Mobile client behavior: mobile/lib/services/api_service.dart + providers/

---

End of KT document.
