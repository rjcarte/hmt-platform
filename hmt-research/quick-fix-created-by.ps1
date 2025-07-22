# quick-fix-created-by.ps1

Write-Host "Quick fix - removing created_by field..." -ForegroundColor Green

# Update the import service to remove created_by
$fixedImportService = @'
import json
from typing import List, Dict
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
                    # Transform the format to match our schema
                    transformed_scenarios = self._transform_scenario_format(scenario_data)
                    
                    for transformed in transformed_scenarios:
                        scenario = Scenario(
                            title=transformed["title"],
                            category=transformed["category"],
                            description=transformed["description"],
                            context=transformed["context"],
                            decision_point=transformed["decision_point"],
                            options=transformed["options"],
                            meta_data=transformed["meta_data"]
                            # Removed created_by since it's not in the model
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
    
    def _transform_scenario_format(self, scenario_data: Dict) -> List[Dict]:
        """Transform your scenario format to our expected format"""
        # Check if this is your format (has variants)
        if "variants" in scenario_data:
            transformed_scenarios = []
            
            # Create a scenario for each variant
            for variant in scenario_data.get("variants", []):
                context = f"""Domain: {scenario_data.get('domain', 'Unknown')}
Scenario: {scenario_data.get('title', 'Unknown')}
AI Alignment: {variant.get('ai_alignment', 'unknown')}
AI Autonomy Level: {variant.get('ai_autonomy', 'unknown')}

This scenario tests decision-making in a {scenario_data.get('dominant_kdma', 'general')} situation."""
                
                decision_point = "How would you respond to this incident?"
                
                # Create options based on AI suggestions
                options = [
                    {
                        "id": "A",
                        "label": "Accept AI Recommendation",
                        "description": variant.get('ai_rationale_clear', 'Follow the AI recommendation')
                    },
                    {
                        "id": "B", 
                        "label": "Override AI Recommendation",
                        "description": "Reject the AI suggestion and take alternative action"
                    },
                    {
                        "id": "C",
                        "label": "Modify AI Recommendation",
                        "description": "Partially accept but adjust the AI suggestion"
                    },
                    {
                        "id": "D",
                        "label": "Request More Information",
                        "description": "Ask for additional analysis before deciding"
                    }
                ]
                
                # If AI rationale is ambiguous, add that as context
                if variant.get('ai_rationale_ambiguous'):
                    context += f"\n\nAI's explanation: {variant['ai_rationale_ambiguous']}"
                
                transformed = {
                    "title": f"{scenario_data['title']} - {variant['code']}",
                    "category": scenario_data.get('domain', 'General'),
                    "description": f"{scenario_data['title']} with {variant['ai_alignment']} AI in {variant['ai_autonomy']} mode",
                    "context": context,
                    "decision_point": decision_point,
                    "options": options,
                    "meta_data": {
                        "original_id": scenario_data.get('id'),
                        "variant_code": variant.get('code'),
                        "dominant_kdma": scenario_data.get('dominant_kdma'),
                        "ai_alignment": variant.get('ai_alignment'),
                        "ai_autonomy": variant.get('ai_autonomy'),
                        "ai_rationale_clear": variant.get('ai_rationale_clear'),
                        "ai_rationale_ambiguous": variant.get('ai_rationale_ambiguous')
                    }
                }
                
                transformed_scenarios.append(transformed)
            
            return transformed_scenarios
        
        # If it's already in the expected format
        else:
            # Validate required fields
            required = ["title", "context", "decision_point", "options"]
            for field in required:
                if field not in scenario_data:
                    raise ValueError(f"Missing required field: {field}")
            
            return [{
                "title": scenario_data["title"],
                "category": scenario_data.get("category", "General"),
                "description": scenario_data.get("description", scenario_data["title"]),
                "context": scenario_data["context"],
                "decision_point": scenario_data["decision_point"],
                "options": scenario_data["options"],
                "meta_data": scenario_data.get("metadata", scenario_data.get("meta_data", {}))
            }]
'@
Set-Content -Path "backend\app\services\scenario_import.py" -Value $fixedImportService

# Also fix the scenarios API to remove created_by
$fixedScenariosApi = @'
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
    db_scenario = Scenario(**scenario.dict())
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
Set-Content -Path "backend\app\api\scenarios.py" -Value $fixedScenariosApi

Write-Host "Restarting backend..." -ForegroundColor Green
docker-compose restart backend

Write-Host "Waiting for backend to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nFixed! Try importing your scenarios again." -ForegroundColor Green