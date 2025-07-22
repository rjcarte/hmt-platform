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
    meta_data = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)
