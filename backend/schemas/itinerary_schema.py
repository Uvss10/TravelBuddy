from pydantic import BaseModel
from typing import List

class ItineraryRequest(BaseModel):
    destination: str
    days: int
    budget: str
    interests: List[str]
