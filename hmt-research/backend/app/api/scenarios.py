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
