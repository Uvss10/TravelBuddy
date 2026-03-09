from pydantic import BaseModel
from typing import List

class ItineraryRequest(BaseModel):
    destination: str
    days: int
    budget: str
    interests: List[str]
    travel_style: str = "cultural"
    group_type: str = "solo"
    starting_location: str = ""
    custom_constraints: str = ""

class ItineraryEditRequest(BaseModel):
    existing_plan: dict
    modification: str
    interests: List[str] = []
