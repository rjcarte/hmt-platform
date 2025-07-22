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
