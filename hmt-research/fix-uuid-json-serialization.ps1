# fix-uuid-json-serialization.ps1

Write-Host "Fixing UUID JSON serialization issue..." -ForegroundColor Green

# Update sessions API to convert UUIDs to strings
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
from ..api.auth import get_current_user

router = APIRouter()

@router.post("/experiments", response_model=dict)
def create_experiment(
    experiment: ExperimentCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Create a new experiment"""
    # Convert UUIDs to strings for JSON storage
    scenario_sequence_str = [str(sid) for sid in experiment.scenario_sequence]
    
    db_experiment = Experiment(
        name=experiment.name,
        description=experiment.description,
        scenario_sequence=scenario_sequence_str,  # Store as strings
        config=experiment.config
        # Removed created_by since it's not in the model
    )
    db.add(db_experiment)
    db.commit()
    db.refresh(db_experiment)
    return {"id": str(db_experiment.id), "name": db_experiment.name}

@router.post("/", response_model=SessionResponse)
def create_session(
    session_data: SessionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
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
    current_user: dict = Depends(get_current_user)
):
    """Get the next scenario in the sequence"""
    session = db.query(SessionModel).filter_by(id=session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Get experiment
    experiment = session.experiment
    if not experiment:
        raise HTTPException(status_code=404, detail="Experiment not found")
    
    # Count completed responses
    completed = db.query(ScenarioResponse).filter_by(session_id=session_id).count()
    
    # Get next scenario
    if completed < len(experiment.scenario_sequence):
        scenario_id = experiment.scenario_sequence[completed]
        # Convert string ID back to UUID if needed
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
    current_user: dict = Depends(get_current_user)
):
    """Submit a response to a scenario"""
    # Get current step number
    step_number = db.query(ScenarioResponse).filter_by(session_id=session_id).count() + 1
    
    # Create response
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
    current_user: dict = Depends(get_current_user)
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
Set-Content -Path "backend\app\api\sessions.py" -Value $fixedSessionsApi

Write-Host "Restarting backend..." -ForegroundColor Green
docker-compose restart backend

Write-Host "Waiting for backend to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nFixed! The UUID serialization issue should be resolved." -ForegroundColor Green
Write-Host "Try creating an experiment again." -ForegroundColor Yellow