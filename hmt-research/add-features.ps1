# add-features.ps1 - Adds full HMT functionality

Write-Host "Adding HMT Platform features..." -ForegroundColor Green

# Create Python package init files
$initFiles = @(
    "backend\app\__init__.py",
    "backend\app\api\__init__.py", 
    "backend\app\core\__init__.py",
    "backend\app\models\__init__.py",
    "backend\app\services\__init__.py",
    "backend\app\schemas\__init__.py"
)

foreach ($file in $initFiles) {
    New-Item -Path $file -ItemType File -Force
    Set-Content -Path $file -Value ""
}

# Core config.py
$configPy = @'
from pydantic_settings import BaseSettings
import os

class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://hmt_user:local_dev_password@postgres:5432/hmt_platform"
    OPENAI_API_KEY: str
    ENVIRONMENT: str = "development"
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "HMT Research Platform"
    
    class Config:
        env_file = ".env"

settings = Settings()
'@
Set-Content -Path "backend\app\core\config.py" -Value $configPy

# Database.py
$databasePy = @'
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
'@
Set-Content -Path "backend\app\core\database.py" -Value $databasePy

# Update requirements.txt with all dependencies
$fullRequirements = @"
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
alembic==1.12.1
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
firebase-admin==6.3.0
openai==1.3.7
pandas==2.1.3
numpy==1.26.2
python-dotenv==1.0.0
httpx==0.25.2
"@
Set-Content -Path "backend\requirements.txt" -Value $fullRequirements

# Create models
$scenarioModel = @'
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime
from ..core.database import Base

class Scenario(Base):
    __tablename__ = "scenarios"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False)
    category = Column(String(100))
    description = Column(Text, nullable=False)
    context = Column(Text, nullable=False)
    decision_point = Column(Text, nullable=False)
    options = Column(JSON, nullable=False)
    metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)
'@
Set-Content -Path "backend\app\models\scenario.py" -Value $scenarioModel

# Create basic auth (no Firebase for now)
$authPy = @'
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

router = APIRouter()
security = HTTPBearer()

# Simple auth for development
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # For now, just accept any bearer token
    return {"uid": "test-user", "role": "admin"}

@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    return current_user
'@
Set-Content -Path "backend\app\api\auth.py" -Value $authPy

# Create scenarios API
$scenariosApi = @'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..core.database import get_db
from ..models.scenario import Scenario
from ..api.auth import get_current_user

router = APIRouter()

@router.get("/")
def list_scenarios(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """List all scenarios"""
    scenarios = db.query(Scenario).filter(Scenario.is_active == True).all()
    return scenarios

@router.post("/")
def create_scenario(
    scenario_data: dict,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Create a new scenario"""
    scenario = Scenario(**scenario_data)
    db.add(scenario)
    db.commit()
    db.refresh(scenario)
    return scenario
'@
Set-Content -Path "backend\app\api\scenarios.py" -Value $scenariosApi

# Create empty API files for now
Set-Content -Path "backend\app\api\sessions.py" -Value 'from fastapi import APIRouter; router = APIRouter()'
Set-Content -Path "backend\app\api\analysis.py" -Value 'from fastapi import APIRouter; router = APIRouter()'

# Update main.py with full implementation
$fullMainPy = @'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .api import scenarios, sessions, analysis, auth
from .core.database import engine
from .models import scenario

# Create tables
scenario.Base.metadata.create_all(bind=engine)

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
Set-Content -Path "backend\app\main.py" -Value $fullMainPy

# Update database schema
$fullInitSql = @'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS scenarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT NOT NULL,
    context TEXT NOT NULL,
    decision_point TEXT NOT NULL,
    options JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS experiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    scenario_sequence JSONB NOT NULL,
    config JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_id UUID REFERENCES experiments(id),
    participant_id VARCHAR(50) NOT NULL,
    operator_id VARCHAR(50) NOT NULL,
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    metadata JSONB DEFAULT '{}'
);
'@
Set-Content -Path "backend\init.sql" -Value $fullInitSql

# Create sample scenarios JSON
New-Item -Path "sample_data" -ItemType Directory -Force
$sampleScenarios = @'
[
  {
    "title": "Suspicious Network Traffic",
    "category": "Incident Response",
    "description": "Unusual outbound traffic detected",
    "context": "Your SIEM has alerted on unusual outbound network traffic from a production web server to an IP in a foreign country.",
    "decision_point": "What is your immediate response?",
    "options": [
      {"id": "A", "label": "Isolate Immediately", "description": "Disconnect the server from the network"},
      {"id": "B", "label": "Monitor First", "description": "Continue monitoring while investigating"},
      {"id": "C", "label": "Block Specific IP", "description": "Block only the suspicious connection"}
    ]
  }
]
'@
Set-Content -Path "sample_data\scenarios.json" -Value $sampleScenarios

Write-Host "Features added! Now rebuilding containers..." -ForegroundColor Green

# Rebuild to include new files
docker-compose down
docker-compose build --no-cache
docker-compose up -d

Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "Check the enhanced API at: http://localhost:8000/docs" -ForegroundColor Cyan