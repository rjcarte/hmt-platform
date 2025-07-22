# fix-response-schema.ps1

Write-Host "Fixing response schema to make fields optional..." -ForegroundColor Green

# Update session schemas with proper optional fields
$fixedSessionSchemas = @'
from pydantic import BaseModel
from typing import Optional, Dict, List
from datetime import datetime
import uuid

class SessionCreate(BaseModel):
    experiment_id: uuid.UUID
    participant_id: str
    operator_id: str

class SessionResponse(BaseModel):
    id: uuid.UUID
    experiment_id: uuid.UUID
    participant_id: str
    operator_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str
    meta_data: Dict
    
    class Config:
        from_attributes = True

class ScenarioResponseCreate(BaseModel):
    selected_option: Optional[str] = None
    custom_response: Optional[str] = None
    confidence_rating: Optional[int] = None
    risk_rating: Optional[int] = None
    think_aloud_transcript: Optional[str] = None

class ExperimentCreate(BaseModel):
    name: str
    description: str
    scenario_sequence: List[uuid.UUID]
    config: Optional[Dict] = {}
'@
Set-Content -Path "backend\app\schemas\session.py" -Value $fixedSessionSchemas

Write-Host "Restarting backend..." -ForegroundColor Green
docker-compose restart backend

Write-Host "Waiting for backend to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nFixed! All response fields are now optional." -ForegroundColor Green
Write-Host "Try submitting the response again without the custom_response field." -ForegroundColor Yellow