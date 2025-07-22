# add-import-export-features.ps1

Write-Host "Adding import/export and session management features..." -ForegroundColor Green

# 1. Create schemas for better API documentation
Write-Host "Creating schemas..." -ForegroundColor Yellow

$scenarioSchemas = @'
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
'@
Set-Content -Path "backend\app\schemas\scenario.py" -Value $scenarioSchemas

# 2. Create session schemas
$sessionSchemas = @'
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
    end_time: Optional[datetime]
    status: str
    meta_data: Dict
    
    class Config:
        from_attributes = True

class ScenarioResponseCreate(BaseModel):
    selected_option: Optional[str]
    custom_response: Optional[str]
    confidence_rating: Optional[int]
    risk_rating: Optional[int]
    think_aloud_transcript: Optional[str]

class ExperimentCreate(BaseModel):
    name: str
    description: str
    scenario_sequence: List[uuid.UUID]
    config: Optional[Dict] = {}
'@
Set-Content -Path "backend\app\schemas\session.py" -Value $sessionSchemas

# 3. Add Session and Experiment models
$sessionModels = @'
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime
from ..core.database import Base

class Experiment(Base):
    __tablename__ = "experiments"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    scenario_sequence = Column(JSON, nullable=False)
    config = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(UUID(as_uuid=True))
    is_active = Column(Boolean, default=True)
    
    sessions = relationship("Session", back_populates="experiment")

class Session(Base):
    __tablename__ = "sessions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    experiment_id = Column(UUID(as_uuid=True), ForeignKey("experiments.id"))
    participant_id = Column(String(50), nullable=False)
    operator_id = Column(String(50), nullable=False)
    start_time = Column(DateTime, default=datetime.utcnow)
    end_time = Column(DateTime)
    status = Column(String(20), default="active")
    meta_data = Column(JSON, default={})
    
    experiment = relationship("Experiment", back_populates="sessions")
    responses = relationship("ScenarioResponse", back_populates="session")

class ScenarioResponse(Base):
    __tablename__ = "scenario_responses"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id"))
    scenario_id = Column(UUID(as_uuid=True), ForeignKey("scenarios.id"))
    step_number = Column(Integer, nullable=False)
    presented_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime)
    selected_option = Column(String(50))
    custom_response = Column(Text)
    confidence_rating = Column(Integer)
    risk_rating = Column(Integer)
    response_time_ms = Column(Integer)
    think_aloud_transcript = Column(Text)
    
    session = relationship("Session", back_populates="responses")
    scenario = relationship("Scenario")
'@
Set-Content -Path "backend\app\models\session.py" -Value $sessionModels

# 4. Create scenario import service
$importService = @'
import json
from typing import List
from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session
from ..models.scenario import Scenario
from ..schemas.scenario import ScenarioImportResponse

class ScenarioImporter:
    def __init__(self, db: Session):
        self.db = db
    
    async def import_json_file(self, file: UploadFile, user_id: str) -> ScenarioImportResponse:
        """Import scenarios from JSON file"""
        try:
            content = await file.read()
            data = json.loads(content)
            
            # Handle both single scenario and array
            scenarios_data = data if isinstance(data, list) else [data]
            
            imported_scenarios = []
            errors = []
            
            for idx, scenario_data in enumerate(scenarios_data):
                try:
                    # Validate required fields
                    required = ["title", "context", "decision_point", "options"]
                    for field in required:
                        if field not in scenario_data:
                            raise ValueError(f"Missing required field: {field}")
                    
                    # Create scenario
                    scenario = Scenario(
                        title=scenario_data["title"],
                        category=scenario_data.get("category", "General"),
                        description=scenario_data.get("description", scenario_data["title"]),
                        context=scenario_data["context"],
                        decision_point=scenario_data["decision_point"],
                        options=scenario_data["options"],
                        meta_data=scenario_data.get("metadata", scenario_data.get("meta_data", {})),
                        created_by=user_id
                    )
                    
                    self.db.add(scenario)
                    imported_scenarios.append(scenario)
                    
                except Exception as e:
                    errors.append(f"Scenario {idx}: {str(e)}")
            
            self.db.commit()
            
            return ScenarioImportResponse(
                imported_count=len(imported_scenarios),
                scenarios=imported_scenarios,
                errors=errors
            )
            
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid JSON file")
        except Exception as e:
            self.db.rollback()
            raise HTTPException(status_code=400, detail=str(e))
'@
Set-Content -Path "backend\app\services\scenario_import.py" -Value $importService

# 5. Create JSONL export service
$exportService = @'
import json
from datetime import datetime
from typing import List
from sqlalchemy.orm import Session
from ..models.session import Session as SessionModel, ScenarioResponse
from ..models.scenario import Scenario

class TraceExporter:
    def __init__(self, db: Session):
        self.db = db
    
    def export_session_to_jsonl(self, session_id: str) -> str:
        """Export session data in KDMA-enriched JSONL format"""
        session = self.db.query(SessionModel).filter_by(id=session_id).first()
        if not session:
            raise ValueError("Session not found")
            
        responses = self.db.query(ScenarioResponse).filter_by(
            session_id=session_id
        ).order_by(ScenarioResponse.step_number).all()
        
        traces = []
        
        for response in responses:
            scenario = response.scenario
            
            # Build observation
            obs_t = {
                "scenario_title": scenario.title,
                "scenario_context": scenario.context,
                "decision_point": scenario.decision_point,
                "available_options": scenario.options
            }
            
            # Calculate response time
            response_time = 0
            if response.responded_at and response.presented_at:
                response_time = int((response.responded_at - response.presented_at).total_seconds() * 1000)
            
            # Build trace entry matching KDMA spec
            trace = {
                "dataset_version": "1.0.0",
                "session_id": str(session_id),
                "operator_id": session.operator_id,
                "scenario_id": str(response.scenario_id),
                "timestamp": response.responded_at.isoformat() + "Z" if response.responded_at else datetime.utcnow().isoformat() + "Z",
                "step": response.step_number,
                "obs_t": obs_t,
                "act_t": response.selected_option or response.custom_response or "",
                "r_env_t": 0.0,  # No environmental reward in text scenarios
                "r_human_t": response.confidence_rating,
                "rationale_t": self._extract_rationale(response.think_aloud_transcript),
                "cta_phase": None,  # Will be filled by analysis
                "kdm_cues": [],     # Will be filled by analysis
                "kdm_heuristic": None,  # Will be filled by analysis
                "kdm_risk_rating": response.risk_rating,
                "kdm_confidence": response.confidence_rating,
                "provenance": {
                    "session_id": str(session_id),
                    "response_id": str(response.id)
                }
            }
            
            traces.append(trace)
        
        # Convert to JSONL
        return "\n".join(json.dumps(trace) for trace in traces)
    
    def _extract_rationale(self, transcript: str) -> str:
        """Extract concise rationale from transcript"""
        if not transcript:
            return ""
        
        # Take first 280 characters
        if len(transcript) <= 280:
            return transcript
        else:
            return transcript[:277] + "..."
'@
Set-Content -Path "backend\app\services\export.py" -Value $exportService

# 6. Update scenarios API with import
$updatedScenariosApi = @'
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from typing import List
import uuid
from ..core.database import get_db
from ..models.scenario import Scenario
from ..schemas.scenario import ScenarioCreate, ScenarioResponse, ScenarioImportResponse
from ..services.scenario_import import ScenarioImporter
from ..api.auth import get_current_user

router = APIRouter()

@router.get("/", response_model=List[ScenarioResponse])
def list_scenarios(
    skip: int = 0,
    limit: int = 100,
    category: str = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
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
    current_user: dict = Depends(get_current_user)
):
    """Create a new scenario"""
    db_scenario = Scenario(
        **scenario.dict(),
        created_by=current_user["uid"]
    )
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    return db_scenario

@router.post("/import", response_model=ScenarioImportResponse)
async def import_scenarios(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Import scenarios from JSON file"""
    if not file.filename.endswith(".json"):
        raise HTTPException(status_code=400, detail="Only JSON files are supported")
    
    importer = ScenarioImporter(db)
    result = await importer.import_json_file(file, current_user["uid"])
    return result

@router.get("/{scenario_id}", response_model=ScenarioResponse)
def get_scenario(
    scenario_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get a specific scenario"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    return scenario
'@
Set-Content -Path "backend\app\api\scenarios.py" -Value $updatedScenariosApi

# 7. Create sessions API
$sessionsApi = @'
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
    db_experiment = Experiment(
        **experiment.dict(),
        created_by=current_user["uid"]
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
Set-Content -Path "backend\app\api\sessions.py" -Value $sessionsApi

# 8. Update main.py to include session model
$updatedMain = @'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .api import scenarios, sessions, analysis, auth
from .core.database import engine
from .models import scenario, session

# Create tables
scenario.Base.metadata.create_all(bind=engine)
session.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(scenarios.router, prefix=f"{settings.API_V1_STR}/scenarios", tags=["scenarios"])
app.include_router(sessions.router, prefix=f"{settings.API_V1_STR}/sessions", tags=["sessions"])
app.include_router(analysis.router, prefix=f"{settings.API_V1_STR}/analysis", tags=["analysis"])

@app.get("/")
async def root():
    return {"message": "HMT Research Platform API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "environment": settings.ENVIRONMENT}
'@
Set-Content -Path "backend\app\main.py" -Value $updatedMain

# 9. Update SQL schema
$updatedSql = @'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables if they exist (for clean rebuild)
DROP TABLE IF EXISTS scenario_responses CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS scenarios CASCADE;

CREATE TABLE scenarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT NOT NULL,
    context TEXT NOT NULL,
    decision_point TEXT NOT NULL,
    options JSONB NOT NULL,
    meta_data JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE experiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    scenario_sequence JSONB NOT NULL,
    config JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_id UUID REFERENCES experiments(id),
    participant_id VARCHAR(50) NOT NULL,
    operator_id VARCHAR(50) NOT NULL,
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    meta_data JSONB DEFAULT '{}'
);

CREATE TABLE scenario_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES sessions(id),
    scenario_id UUID REFERENCES scenarios(id),
    step_number INTEGER NOT NULL,
    presented_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    selected_option VARCHAR(50),
    custom_response TEXT,
    confidence_rating INTEGER CHECK (confidence_rating BETWEEN 1 AND 5),
    risk_rating INTEGER CHECK (risk_rating BETWEEN 1 AND 5),
    response_time_ms INTEGER,
    think_aloud_transcript TEXT
);

-- Create indexes
CREATE INDEX idx_sessions_experiment ON sessions(experiment_id);
CREATE INDEX idx_responses_session ON scenario_responses(session_id);
CREATE INDEX idx_responses_scenario ON scenario_responses(scenario_id);
'@
Set-Content -Path "backend\init.sql" -Value $updatedSql

Write-Host "Files updated! Rebuilding backend..." -ForegroundColor Green

# Rebuild only backend
docker-compose stop backend
docker-compose build backend
docker-compose up -d backend

# Recreate database tables
Write-Host "Waiting for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Recreate the database schema
docker-compose exec -T postgres psql -U hmt_user -d hmt_platform -f /docker-entrypoint-initdb.d/init.sql

Write-Host "`nFeatures added successfully!" -ForegroundColor Green
Write-Host "New endpoints available:" -ForegroundColor Cyan
Write-Host "- POST /api/v1/scenarios/import - Import JSON scenarios" -ForegroundColor White
Write-Host "- POST /api/v1/sessions/experiments - Create experiment" -ForegroundColor White
Write-Host "- POST /api/v1/sessions/ - Start session" -ForegroundColor White
Write-Host "- GET /api/v1/sessions/{id}/next-scenario - Get next scenario" -ForegroundColor White
Write-Host "- POST /api/v1/sessions/{id}/responses - Submit response" -ForegroundColor White
Write-Host "- GET /api/v1/sessions/{id}/export/jsonl - Export JSONL" -ForegroundColor White