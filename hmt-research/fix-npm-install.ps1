# fix-npm-install.ps1

Write-Host "Installing frontend dependencies..." -ForegroundColor Green

# Method 1: Run npm install inside the container
Write-Host "Running npm install in the frontend container..." -ForegroundColor Yellow
docker-compose exec frontend npm install

Write-Host "Restarting frontend to pick up changes..." -ForegroundColor Yellow
docker-compose restart frontend

Write-Host "`nWait about 30 seconds for the frontend to compile..." -ForegroundColor Yellow
Write-Host "Then refresh http://localhost:3000" -ForegroundColor Cyan
Write-Host "`nIf you see compilation errors, wait a bit longer - npm is installing packages." -ForegroundColor Gray