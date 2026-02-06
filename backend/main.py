from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api import itinerary, image_analysis, story, video, health

app = FastAPI(title="TravelBuddy API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(health.router, tags=["Health"])
app.include_router(itinerary.router, prefix="/itinerary", tags=["Itinerary"])
app.include_router(image_analysis.router, prefix="/images", tags=["Images"])
app.include_router(story.router, prefix="/story", tags=["Story"])
app.include_router(video.router, prefix="/video", tags=["Video"])
