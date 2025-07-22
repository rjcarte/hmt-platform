# fix-email-validator.ps1

Write-Host "Adding email-validator dependency..." -ForegroundColor Green

# Update requirements.txt to include email-validator
$requirements = @"
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
alembic==1.12.1
pydantic==2.5.0
pydantic-settings==2.1.0
email-validator==2.1.0
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
Set-Content -Path "backend\requirements.txt" -Value $requirements

Write-Host "Rebuilding backend with email-validator..." -ForegroundColor Yellow

# Rebuild backend container to install the new dependency
docker-compose stop backend
docker-compose build backend --no-cache
docker-compose up -d backend

Write-Host "Waiting for backend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nFixed! The backend should now start properly." -ForegroundColor Green
Write-Host "Try logging in again at http://localhost:3000" -ForegroundColor Cyan