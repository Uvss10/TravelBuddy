from fastapi import APIRouter, Body
from fastapi.responses import FileResponse
from backend.schemas.itinerary_schema import ItineraryRequest, ItineraryEditRequest
from backend.services.itinerary_service import generate_itinerary, edit_itinerary
from backend.services.export_service import generate_itinerary_docx
import os
import tempfile

router = APIRouter()

@router.post("/generate")
def generate_itinerary_api(request: ItineraryRequest):
    return generate_itinerary(request)

@router.post("/edit")
def edit_itinerary_api(request: ItineraryEditRequest):
    return edit_itinerary(request)

@router.post("/export/docx")
def export_itinerary_docx(itinerary_data: dict = Body(...)):
    """
    Takes the full itinerary object and returns a .docx file.
    """
    with tempfile.NamedTemporaryFile(delete=False, suffix=".docx") as tmp:
        output_path = tmp.name
    
    generate_itinerary_docx(itinerary_data, output_path)
    
    filename = f"Itinerary_{itinerary_data.get('destination', 'Trip')}.docx"
    return FileResponse(
        output_path, 
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=filename
    )
