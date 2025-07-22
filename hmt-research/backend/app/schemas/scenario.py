from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime
import uuid

class ScenarioOption(BaseModel):
    id: str
    label: str
    description: str

class ScenarioCreate(BaseModel):
    title: str
    category: str
    description: str
    context: str
    decision_point: str
    options: List[ScenarioOption]
    meta_data: Optional[Dict] = {}

class ScenarioUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    context: Optional[str] = None
    decision_point: Optional[str] = None
    options: Optional[List[ScenarioOption]] = None
    meta_data: Optional[Dict] = None

class ScenarioResponse(BaseModel):
    id: uuid.UUID
    title: str
    category: str
    description: str
    context: str
    decision_point: str
    options: List[ScenarioOption]
    meta_data: Dict
    created_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True

class ScenarioImportResponse(BaseModel):
    imported_count: int
    scenarios: List[ScenarioResponse]
    errors: List[str] = []
