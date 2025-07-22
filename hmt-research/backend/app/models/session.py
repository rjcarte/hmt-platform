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
