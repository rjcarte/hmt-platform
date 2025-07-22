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
