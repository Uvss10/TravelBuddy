from pydantic import BaseModel
from typing import List, Optional

class StoryRequest(BaseModel):
    destination: str
    scene_tags: List[str]
    tone: Optional[str] = "adventurous and inspiring"

class StoryResponse(BaseModel):
    destination: str
    title: str
    narration: str
    captions: List[str]
    hashtags: List[str]
