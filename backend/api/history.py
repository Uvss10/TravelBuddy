from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from backend.supabase_client import supabase

router = APIRouter()

# ── Schemas ──────────────────────────────────────────────────────────────────
class TripSave(BaseModel):
    user_id: str  # Changed to str for Supabase UUID compatibility
    destination: str
    title: str
    narration: str
    captions: List[str]
    hashtags: List[str]
    video_url: Optional[str] = None

# ── Endpoints ────────────────────────────────────────────────────────────────
@router.post("/save")
def save_trip(trip_data: TripSave):
    try:
        response = supabase.table("trips").insert({
            "user_id": trip_data.user_id,
            "destination": trip_data.destination,
            "title": trip_data.title,
            "narration": trip_data.narration,
            "captions": trip_data.captions,
            "hashtags": trip_data.hashtags,
            "video_url": trip_data.video_url
        }).execute()
        
        return {"status": "success", "data": response.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{user_id}")
def get_user_history(user_id: str):
    try:
        response = supabase.table("trips")\
            .select("*")\
            .eq("user_id", user_id)\
            .order("created_at", desc=True)\
            .execute()
        return response.data
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/{trip_id}")
def delete_trip(trip_id: int):
    """
    Delete a saved trip/reel from the user's history.
    """
    try:
        response = supabase.table("trips").delete().eq("id", trip_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Trip not found or already deleted.")
        return {"status": "success", "message": f"Trip {trip_id} successfully deleted."}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
