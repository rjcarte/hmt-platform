# final-auth-fix.ps1

Write-Host "Final fix for auth issues..." -ForegroundColor Green

# 1. Fix config.py properly
$configPy = @'
from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://hmt_user:local_dev_password@postgres:5432/hmt_platform"
    
    # API Keys
    OPENAI_API_KEY: str = "placeholder"
    
    # Application
    ENVIRONMENT: str = "development"
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "HMT Research Platform"
    
    # Security
    SECRET_KEY: str = "your-secret-key-for-development-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    
    # Performance settings
    MAX_WORKERS: int = 2
    WHISPER_MODEL: str = "whisper-1"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
'@
Set-Content -Path "backend\app\core\config.py" -Value $configPy -Encoding UTF8

# 2. Fix scenarios.py import - it should NOT import from api.auth
$fixedScenariosApi = @'
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from typing import List
import uuid
from ..core.database import get_db
from ..models.scenario import Scenario
from ..schemas.scenario import ScenarioCreate, ScenarioResponse, ScenarioImportResponse, ScenarioUpdate
from ..services.scenario_import import ScenarioImporter
from ..services.auth import get_current_active_user

router = APIRouter()

@router.get("/", response_model=List[ScenarioResponse])
def list_scenarios(
    skip: int = 0,
    limit: int = 100,
    category: str = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """List all scenarios with optional filtering"""
    query = db.query(Scenario).filter(Scenario.is_active == True)
    
    if category:
        query = query.filter(Scenario.category == category)
    
    scenarios = query.offset(skip).limit(limit).all()
    return scenarios

@router.post("/", response_model=ScenarioResponse)
def create_scenario(
    scenario: ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Create a new scenario"""
    db_scenario = Scenario(**scenario.dict())
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    return db_scenario

@router.get("/{scenario_id}", response_model=ScenarioResponse)
def get_scenario(
    scenario_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Get a specific scenario"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    return scenario

@router.put("/{scenario_id}", response_model=ScenarioResponse)
def update_scenario(
    scenario_id: uuid.UUID,
    scenario_update: ScenarioUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Update a scenario"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    update_data = scenario_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(scenario, field, value)
    
    db.commit()
    db.refresh(scenario)
    return scenario

@router.delete("/{scenario_id}")
def delete_scenario(
    scenario_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Delete a scenario (soft delete)"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    scenario.is_active = False
    db.commit()
    
    return {"message": "Scenario deleted successfully"}

@router.post("/import", response_model=ScenarioImportResponse)
async def import_scenarios(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Import scenarios from JSON file"""
    if not file.filename.endswith(".json"):
        raise HTTPException(status_code=400, detail="Only JSON files are supported")
    
    importer = ScenarioImporter(db)
    result = await importer.import_json_file(file, str(current_user.id))
    return result
'@
Set-Content -Path "backend\app\api\scenarios.py" -Value $fixedScenariosApi -Encoding UTF8

# 3. Also fix sessions.py
$fixedSessionsApi = @'
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session
from typing import List
import uuid
from datetime import datetime
from ..core.database import get_db
from ..models.session import Session as SessionModel, Experiment, ScenarioResponse
from ..models.scenario import Scenario
from ..schemas.session import SessionCreate, SessionResponse, ScenarioResponseCreate, ExperimentCreate
from ..services.export import TraceExporter
from ..services.auth import get_current_active_user

router = APIRouter()

@router.post("/experiments", response_model=dict)
def create_experiment(
    experiment: ExperimentCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Create a new experiment"""
    scenario_sequence_str = [str(sid) for sid in experiment.scenario_sequence]
    
    db_experiment = Experiment(
        name=experiment.name,
        description=experiment.description,
        scenario_sequence=scenario_sequence_str,
        config=experiment.config
    )
    db.add(db_experiment)
    db.commit()
    db.refresh(db_experiment)
    return {"id": str(db_experiment.id), "name": db_experiment.name}

@router.post("/", response_model=SessionResponse)
def create_session(
    session_data: SessionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Start a new session"""
    session = SessionModel(**session_data.dict())
    db.add(session)
    db.commit()
    db.refresh(session)
    return session

@router.get("/{session_id}/next-scenario")
def get_next_scenario(
    session_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Get the next scenario in the sequence"""
    session = db.query(SessionModel).filter_by(id=session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    experiment = session.experiment
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")
    
    completed = db.query(ScenarioResponse).filter_by(session_id=session_id).count()
    
    if completed < len(experiment.scenario_sequence):
        scenario_id = experiment.scenario_sequence[completed]
        if isinstance(scenario_id, str):
            scenario_id = uuid.UUID(scenario_id)
        
        scenario = db.query(Scenario).filter_by(id=scenario_id).first()
        
        if scenario:
            return {
                "step_number": completed + 1,
                "total_steps": len(experiment.scenario_sequence),
                "scenario": {
                    "id": str(scenario.id),
                    "title": scenario.title,
                    "context": scenario.context,
                    "decision_point": scenario.decision_point,
                    "options": scenario.options
                }
            }
    
    return {"message": "No more scenarios", "completed": True}

@router.post("/{session_id}/responses")
def submit_response(
    session_id: uuid.UUID,
    scenario_id: uuid.UUID,
    response_data: ScenarioResponseCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Submit a response to a scenario"""
    step_number = db.query(ScenarioResponse).filter_by(session_id=session_id).count() + 1
    
    response = ScenarioResponse(
        session_id=session_id,
        scenario_id=scenario_id,
        step_number=step_number,
        presented_at=datetime.utcnow(),
        responded_at=datetime.utcnow(),
        **response_data.dict()
    )
    
    db.add(response)
    db.commit()
    
    return {"message": "Response recorded", "step": step_number}

@router.get("/{session_id}/export/jsonl")
def export_session_jsonl(
    session_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user)
):
    """Export session as KDMA-enriched JSONL"""
    exporter = TraceExporter(db)
    try:
        jsonl_data = exporter.export_session_to_jsonl(str(session_id))
        return Response(
            content=jsonl_data,
            media_type="application/x-ndjson",
            headers={
                "Content-Disposition": f"attachment; filename=session_{session_id}.jsonl"
            }
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
'@
Set-Content -Path "backend\app\api\sessions.py" -Value $fixedSessionsApi -Encoding UTF8

Write-Host "Files updated. Now rebuilding backend to ensure clean state..." -ForegroundColor Yellow

# Force rebuild
docker-compose stop backend
docker-compose rm -f backend
docker-compose up -d backend

Write-Host "Waiting for backend to start (this may take a moment)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "`nBackend should now be running properly!" -ForegroundColor Green
Write-Host "Try logging in at http://localhost:3000" -ForegroundColor Cyan
Write-Host "Email: admin@hmt.local" -ForegroundColor White
Write-Host "Password: admin123" -ForegroundColor White