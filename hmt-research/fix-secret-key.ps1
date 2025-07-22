# fix-secret-key.ps1

Write-Host "Fixing SECRET_KEY configuration..." -ForegroundColor Green

# Update config.py with SECRET_KEY
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
    
    # Security - THESE WERE MISSING!
    SECRET_KEY: str = "your-secret-key-for-development-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 1 week
    
    # Performance settings
    MAX_WORKERS: int = 2
    WHISPER_MODEL: str = "whisper-1"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
'@
Set-Content -Path "backend\app\core\config.py" -Value $configPy

Write-Host "Restarting backend..." -ForegroundColor Yellow
docker-compose restart backend

Write-Host "Waiting for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nFixed! SECRET_KEY is now configured." -ForegroundColor Green
Write-Host "Try logging in again at http://localhost:3000" -ForegroundColor Cyan