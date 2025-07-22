# create-files.ps1 - Run this to create all necessary files

Write-Host "Creating HMT Platform files..." -ForegroundColor Green

# Backend Dockerfile
$backendDockerfile = @"
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc postgresql-client && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
"@
New-Item -Path "backend\Dockerfile" -ItemType File -Force
Set-Content -Path "backend\Dockerfile" -Value $backendDockerfile

# Backend requirements.txt
$requirements = @"
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
firebase-admin==6.3.0
openai==1.3.7
"@
Set-Content -Path "backend\requirements.txt" -Value $requirements

# Backend main.py
$mainPy = @"
from fastapi import FastAPI

app = FastAPI(title="HMT Research Platform")

@app.get("/")
async def root():
    return {"message": "HMT Research Platform API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
"@
New-Item -Path "backend\app\main.py" -ItemType File -Force
Set-Content -Path "backend\app\main.py" -Value $mainPy

# Frontend Dockerfile
$frontendDockerfile = @"
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
"@
New-Item -Path "frontend\Dockerfile" -ItemType File -Force
Set-Content -Path "frontend\Dockerfile" -Value $frontendDockerfile

# Frontend package.json
$packageJson = @"
{
  "name": "hmt-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version"]
  }
}
"@
New-Item -Path "frontend\package.json" -ItemType File -Force
Set-Content -Path "frontend\package.json" -Value $packageJson

# Create directories
New-Item -Path "frontend\src" -ItemType Directory -Force
New-Item -Path "frontend\public" -ItemType Directory -Force

# Frontend App.js
$appJs = @"
function App() {
  return (
    <div>
      <h1>HMT Research Platform</h1>
      <p>Frontend is running!</p>
    </div>
  );
}

export default App;
"@
Set-Content -Path "frontend\src\App.js" -Value $appJs

# Frontend index.js
$indexJs = @"
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
"@
Set-Content -Path "frontend\src\index.js" -Value $indexJs

# Frontend index.html
$indexHtml = @"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>HMT Research Platform</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
"@
Set-Content -Path "frontend\public\index.html" -Value $indexHtml

# Database init.sql
$initSql = @"
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
"@
Set-Content -Path "backend\init.sql" -Value $initSql

Write-Host "All files created successfully!" -ForegroundColor Green
Write-Host "Now run: docker-compose build" -ForegroundColor Yellow