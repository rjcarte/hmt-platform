# HMT Research Platform - Windows Development Setup

Write-Host "Setting up HMT Research Platform for local development..." -ForegroundColor Green

# Better Docker check for Windows
try {
    docker version | Out-Null
    Write-Host "Docker is running ✓" -ForegroundColor Green
} catch {
    Write-Host "Docker is not accessible. Please ensure Docker Desktop is running and docker CLI is in PATH" -ForegroundColor Red
    Write-Host "You can also try running this script as Administrator" -ForegroundColor Yellow
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "Error: docker-compose.yml not found!" -ForegroundColor Red
    Write-Host "Please run this script from the hmt-research root directory" -ForegroundColor Yellow
    exit 1
}

# Create .env file if it doesn't exist
if (-not (Test-Path .env)) {
    Write-Host "Creating .env file..." -ForegroundColor Yellow
    @"
OPENAI_API_KEY=your-openai-api-key-here
FIREBASE_CONFIG='{"apiKey":"...","authDomain":"...","projectId":"hmt-research"}'
"@ | Out-File -FilePath .env -Encoding UTF8
    Write-Host "Please edit .env file with your API keys!" -ForegroundColor Yellow
}

# Create required directories
Write-Host "Creating required directories..." -ForegroundColor Green
$dirs = @(
    "backend/app/api",
    "backend/app/core", 
    "backend/app/models",
    "backend/app/services",
    "backend/app/schemas",
    "frontend/src/components",
    "frontend/src/pages",
    "frontend/src/services",
    "frontend/src/hooks",
    "frontend/src/contexts",
    "sample_data"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

# Create empty __init__.py files for Python packages
$initFiles = @(
    "backend/app/__init__.py",
    "backend/app/api/__init__.py",
    "backend/app/core/__init__.py",
    "backend/app/models/__init__.py",
    "backend/app/services/__init__.py",
    "backend/app/schemas/__init__.py"
)

foreach ($file in $initFiles) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Force -Path $file | Out-Null
    }
}

# Build and start containers
Write-Host "Building Docker containers..." -ForegroundColor Green
docker-compose build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Starting services..." -ForegroundColor Green
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start services!" -ForegroundColor Red
    exit 1
}

# Wait for database to be ready
Write-Host "Waiting for database to initialize..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    try {
        docker-compose exec -T postgres pg_isready -U hmt_user -d hmt_platform | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Database is ready! ✓" -ForegroundColor Green
            break
        }
    } catch {}
    
    $attempt++
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
}

Write-Host ""

# Show status
docker-compose ps

Write-Host "`nSetup complete! ✓" -ForegroundColor Green
Write-Host "Backend API: http://localhost:8000" -ForegroundColor Cyan
Write-Host "Frontend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "API Documentation: http://localhost:8000/docs" -ForegroundColor Cyan
Write-Host "`nTo view logs: docker-compose logs -f" -ForegroundColor Gray
Write-Host "To stop services: docker-compose down" -ForegroundColor Gray