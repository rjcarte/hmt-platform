# add-full-implementation.ps1

Write-Host "Adding full HMT Platform implementation..." -ForegroundColor Green

# First, let's stop the containers to update them
docker-compose down

# Create all Python __init__.py files
$initFiles = @(
    "backend\app\__init__.py",
    "backend\app\api\__init__.py",
    "backend\app\core\__init__.py",
    "backend\app\models\__init__.py",
    "backend\app\services\__init__.py",
    "backend\app\schemas\__init__.py"
)

foreach ($file in $initFiles) {
    New-Item -Path $file -ItemType File -Force | Out-Null
}

Write-Host "Created Python package structure" -ForegroundColor Green

# Now run the add-features script
Write-Host "Adding features..." -ForegroundColor Yellow