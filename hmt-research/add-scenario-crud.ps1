# add-scenario-crud.ps1

Write-Host "Adding CRUD functionality for scenarios..." -ForegroundColor Green

# 1. Update backend API with UPDATE and DELETE endpoints
Write-Host "Updating backend API..." -ForegroundColor Yellow

$updatedScenariosApi = @'
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from typing import List
import uuid
from ..core.database import get_db
from ..models.scenario import Scenario
from ..schemas.scenario import ScenarioCreate, ScenarioResponse, ScenarioImportResponse, ScenarioUpdate
from ..services.scenario_import import ScenarioImporter
from ..api.auth import get_current_user

router = APIRouter()

@router.get("/", response_model=List[ScenarioResponse])
def list_scenarios(
    skip: int = 0,
    limit: int = 100,
    category: str = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """List all scenarios with optional filtering"""
    query = db.query(Scenario).filter(Scenario.is_active == True)
    
    if category:
        query = query.filter(Scenario.category == category)
    
    scenarios = query.offset(skip).limit(limit).all()
    return scenarios

@router.post("/", response_model=ScenarioResponse)
def create_scenario(
    scenario: ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Create a new scenario"""
    db_scenario = Scenario(**scenario.dict())
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    return db_scenario

@router.get("/{scenario_id}", response_model=ScenarioResponse)
def get_scenario(
    scenario_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get a specific scenario"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    return scenario

@router.put("/{scenario_id}", response_model=ScenarioResponse)
def update_scenario(
    scenario_id: uuid.UUID,
    scenario_update: ScenarioUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Update a scenario"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    # Update only provided fields
    update_data = scenario_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(scenario, field, value)
    
    db.commit()
    db.refresh(scenario)
    return scenario

@router.delete("/{scenario_id}")
def delete_scenario(
    scenario_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Delete a scenario (soft delete)"""
    scenario = db.query(Scenario).filter(
        Scenario.id == scenario_id,
        Scenario.is_active == True
    ).first()
    
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    # Soft delete
    scenario.is_active = False
    db.commit()
    
    return {"message": "Scenario deleted successfully"}

@router.post("/import", response_model=ScenarioImportResponse)
async def import_scenarios(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Import scenarios from JSON file"""
    if not file.filename.endswith(".json"):
        raise HTTPException(status_code=400, detail="Only JSON files are supported")
    
    importer = ScenarioImporter(db)
    result = await importer.import_json_file(file, current_user["uid"])
    return result
'@
Set-Content -Path "backend\app\api\scenarios.py" -Value $updatedScenariosApi

# 2. Add ScenarioUpdate schema
$updatedSchemas = @'
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime
import uuid

class ScenarioOption(BaseModel):
    id: str
    label: str
    description: str

class ScenarioCreate(BaseModel):
    title: str
    category: str
    description: str
    context: str
    decision_point: str
    options: List[ScenarioOption]
    meta_data: Optional[Dict] = {}

class ScenarioUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    context: Optional[str] = None
    decision_point: Optional[str] = None
    options: Optional[List[ScenarioOption]] = None
    meta_data: Optional[Dict] = None

class ScenarioResponse(BaseModel):
    id: uuid.UUID
    title: str
    category: str
    description: str
    context: str
    decision_point: str
    options: List[ScenarioOption]
    meta_data: Dict
    created_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True

class ScenarioImportResponse(BaseModel):
    imported_count: int
    scenarios: List[ScenarioResponse]
    errors: List[str] = []
'@
Set-Content -Path "backend\app\schemas\scenario.py" -Value $updatedSchemas

# 3. Update frontend API service
$updatedApiService = @'
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to all requests
api.interceptors.request.use((config) => {
  config.headers.Authorization = 'Bearer test-token';
  return config;
});

export const scenarioAPI = {
  list: () => api.get('/api/v1/scenarios/'),
  get: (id) => api.get(`/api/v1/scenarios/${id}`),
  create: (data) => api.post('/api/v1/scenarios/', data),
  update: (id, data) => api.put(`/api/v1/scenarios/${id}`, data),
  delete: (id) => api.delete(`/api/v1/scenarios/${id}`),
  import: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/api/v1/scenarios/import', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
};

export const experimentAPI = {
  create: (data) => api.post('/api/v1/sessions/experiments', data),
};

export const sessionAPI = {
  create: (data) => api.post('/api/v1/sessions/', data),
  getNextScenario: (sessionId) => api.get(`/api/v1/sessions/${sessionId}/next-scenario`),
  submitResponse: (sessionId, scenarioId, data) => 
    api.post(`/api/v1/sessions/${sessionId}/responses`, data, {
      params: { scenario_id: scenarioId }
    }),
  exportJSONL: (sessionId) => 
    api.get(`/api/v1/sessions/${sessionId}/export/jsonl`, {
      responseType: 'blob'
    }),
};

export default api;
'@
Set-Content -Path "frontend\src\services\api.js" -Value $updatedApiService

# 4. Create Scenarios management page
$scenariosPage = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Typography, Box, Button, Paper, IconButton,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  Dialog, DialogTitle, DialogContent, DialogActions, TextField,
  FormControl, InputLabel, Select, MenuItem, Chip, Tooltip
} from '@mui/material';
import {
  Add, Edit, Delete, Visibility, Upload
} from '@mui/icons-material';
import { scenarioAPI } from '../services/api';

function Scenarios() {
  const [scenarios, setScenarios] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [currentScenario, setCurrentScenario] = useState({
    title: '',
    category: '',
    description: '',
    context: '',
    decision_point: '',
    options: [
      { id: 'A', label: '', description: '' },
      { id: 'B', label: '', description: '' },
      { id: 'C', label: '', description: '' },
      { id: 'D', label: '', description: '' }
    ],
    meta_data: {}
  });
  const [viewDialog, setViewDialog] = useState(false);
  const [viewScenario, setViewScenario] = useState(null);

  useEffect(() => {
    loadScenarios();
  }, []);

  const loadScenarios = async () => {
    try {
      const response = await scenarioAPI.list();
      setScenarios(response.data);
    } catch (error) {
      console.error('Error loading scenarios:', error);
    }
  };

  const handleCreate = () => {
    setEditMode(false);
    setCurrentScenario({
      title: '',
      category: '',
      description: '',
      context: '',
      decision_point: '',
      options: [
        { id: 'A', label: '', description: '' },
        { id: 'B', label: '', description: '' },
        { id: 'C', label: '', description: '' },
        { id: 'D', label: '', description: '' }
      ],
      meta_data: {}
    });
    setOpenDialog(true);
  };

  const handleEdit = (scenario) => {
    setEditMode(true);
    setCurrentScenario(scenario);
    setOpenDialog(true);
  };

  const handleView = (scenario) => {
    setViewScenario(scenario);
    setViewDialog(true);
  };

  const handleSave = async () => {
    try {
      if (editMode) {
        await scenarioAPI.update(currentScenario.id, currentScenario);
      } else {
        await scenarioAPI.create(currentScenario);
      }
      setOpenDialog(false);
      loadScenarios();
    } catch (error) {
      alert('Error saving scenario');
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this scenario?')) {
      try {
        await scenarioAPI.delete(id);
        loadScenarios();
      } catch (error) {
        alert('Error deleting scenario');
      }
    }
  };

  const updateOption = (index, field, value) => {
    const newOptions = [...currentScenario.options];
    newOptions[index] = { ...newOptions[index], [field]: value };
    setCurrentScenario({ ...currentScenario, options: newOptions });
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4" component="h1">
          Scenario Management
        </Typography>
        <Box>
          <Button
            variant="outlined"
            startIcon={<Upload />}
            component="label"
            sx={{ mr: 2 }}
          >
            Import JSON
            <input
              type="file"
              hidden
              accept=".json"
              onChange={async (e) => {
                if (e.target.files[0]) {
                  try {
                    await scenarioAPI.import(e.target.files[0]);
                    loadScenarios();
                    alert('Import successful!');
                  } catch (error) {
                    alert('Import failed');
                  }
                }
              }}
            />
          </Button>
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={handleCreate}
          >
            Create Scenario
          </Button>
        </Box>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Title</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>AI Alignment</TableCell>
              <TableCell>AI Autonomy</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {scenarios.map((scenario) => (
              <TableRow key={scenario.id}>
                <TableCell>{scenario.title}</TableCell>
                <TableCell>{scenario.category}</TableCell>
                <TableCell>
                  {scenario.meta_data?.ai_alignment && (
                    <Chip
                      label={scenario.meta_data.ai_alignment}
                      size="small"
                      color={scenario.meta_data.ai_alignment === 'aligned' ? 'success' : 'error'}
                    />
                  )}
                </TableCell>
                <TableCell>
                  {scenario.meta_data?.ai_autonomy && (
                    <Chip label={scenario.meta_data.ai_autonomy} size="small" variant="outlined" />
                  )}
                </TableCell>
                <TableCell align="right">
                  <Tooltip title="View">
                    <IconButton onClick={() => handleView(scenario)} size="small">
                      <Visibility />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Edit">
                    <IconButton onClick={() => handleEdit(scenario)} size="small">
                      <Edit />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton onClick={() => handleDelete(scenario.id)} size="small" color="error">
                      <Delete />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Create/Edit Dialog */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>{editMode ? 'Edit Scenario' : 'Create Scenario'}</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Title"
            value={currentScenario.title}
            onChange={(e) => setCurrentScenario({ ...currentScenario, title: e.target.value })}
            margin="normal"
          />
          <FormControl fullWidth margin="normal">
            <InputLabel>Category</InputLabel>
            <Select
              value={currentScenario.category}
              label="Category"
              onChange={(e) => setCurrentScenario({ ...currentScenario, category: e.target.value })}
            >
              <MenuItem value="Incident Response">Incident Response</MenuItem>
              <MenuItem value="Threat Assessment">Threat Assessment</MenuItem>
              <MenuItem value="Risk Management">Risk Management</MenuItem>
              <MenuItem value="General">General</MenuItem>
            </Select>
          </FormControl>
          <TextField
            fullWidth
            label="Description"
            value={currentScenario.description}
            onChange={(e) => setCurrentScenario({ ...currentScenario, description: e.target.value })}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Context"
            value={currentScenario.context}
            onChange={(e) => setCurrentScenario({ ...currentScenario, context: e.target.value })}
            margin="normal"
            multiline
            rows={4}
          />
          <TextField
            fullWidth
            label="Decision Point"
            value={currentScenario.decision_point}
            onChange={(e) => setCurrentScenario({ ...currentScenario, decision_point: e.target.value })}
            margin="normal"
          />
          
          <Typography variant="h6" sx={{ mt: 2 }}>Options</Typography>
          {currentScenario.options.map((option, index) => (
            <Box key={option.id} sx={{ mb: 2, p: 2, border: '1px solid #e0e0e0', borderRadius: 1 }}>
              <Typography variant="subtitle2">Option {option.id}</Typography>
              <TextField
                fullWidth
                label="Label"
                value={option.label}
                onChange={(e) => updateOption(index, 'label', e.target.value)}
                margin="dense"
                size="small"
              />
              <TextField
                fullWidth
                label="Description"
                value={option.description}
                onChange={(e) => updateOption(index, 'description', e.target.value)}
                margin="dense"
                size="small"
              />
            </Box>
          ))}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Cancel</Button>
          <Button onClick={handleSave} variant="contained">Save</Button>
        </DialogActions>
      </Dialog>

      {/* View Dialog */}
      <Dialog open={viewDialog} onClose={() => setViewDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>{viewScenario?.title}</DialogTitle>
        <DialogContent>
          {viewScenario && (
            <Box>
              <Typography variant="subtitle1" gutterBottom>
                <strong>Category:</strong> {viewScenario.category}
              </Typography>
              <Typography variant="subtitle1" gutterBottom>
                <strong>Description:</strong> {viewScenario.description}
              </Typography>
              <Typography variant="subtitle1" gutterBottom>
                <strong>Context:</strong>
              </Typography>
              <Paper sx={{ p: 2, mb: 2, backgroundColor: '#f5f5f5' }}>
                <Typography variant="body1" style={{ whiteSpace: 'pre-line' }}>
                  {viewScenario.context}
                </Typography>
              </Paper>
              <Typography variant="subtitle1" gutterBottom>
                <strong>Decision Point:</strong> {viewScenario.decision_point}
              </Typography>
              <Typography variant="subtitle1" gutterBottom>
                <strong>Options:</strong>
              </Typography>
              {viewScenario.options.map((option) => (
                <Paper key={option.id} sx={{ p: 2, mb: 1 }}>
                  <Typography variant="subtitle2">
                    {option.id}. {option.label}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {option.description}
                  </Typography>
                </Paper>
              ))}
              {viewScenario.meta_data && Object.keys(viewScenario.meta_data).length > 0 && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle1" gutterBottom>
                    <strong>Metadata:</strong>
                  </Typography>
                  <pre style={{ fontSize: '0.875rem', backgroundColor: '#f5f5f5', padding: '8px', borderRadius: '4px' }}>
                    {JSON.stringify(viewScenario.meta_data, null, 2)}
                  </pre>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewDialog(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default Scenarios;
'@
Set-Content -Path "frontend\src\pages\Scenarios.js" -Value $scenariosPage

# 5. Update App.js to include Scenarios route
$updatedApp = @'
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { Box } from '@mui/material';

// Import pages
import Dashboard from './pages/Dashboard';
import Scenarios from './pages/Scenarios';
import Experiments from './pages/Experiments';
import RunSession from './pages/RunSession';
import ParticipantView from './pages/ParticipantView';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
  },
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Box sx={{ minHeight: '100vh', backgroundColor: 'background.default' }}>
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/scenarios" element={<Scenarios />} />
            <Route path="/experiments" element={<Experiments />} />
            <Route path="/run-session" element={<RunSession />} />
            <Route path="/participant/:sessionId" element={<ParticipantView />} />
          </Routes>
        </Box>
      </Router>
    </ThemeProvider>
  );
}

export default App;
'@
Set-Content -Path "frontend\src\App.js" -Value $updatedApp

# 6. Update Dashboard to include link to Scenarios
$updatedDashboard = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Grid, Paper, Typography, Box, Button, Card, CardContent,
  IconButton, Tooltip
} from '@mui/material';
import {
  Science, PlayArrow, Assessment, Upload, Edit
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { scenarioAPI } from '../services/api';

function Dashboard() {
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    scenarios: 0,
    experiments: 0,
    sessions: 0,
  });

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      const scenarios = await scenarioAPI.list();
      setStats(prev => ({ ...prev, scenarios: scenarios.data.length }));
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const cards = [
    {
      title: 'Scenarios',
      count: stats.scenarios,
      icon: <Science />,
      color: '#1976d2',
      action: () => navigate('/scenarios'),
    },
    {
      title: 'Experiments',
      count: 'Design',
      icon: <Edit />,
      color: '#9c27b0',
      action: () => navigate('/experiments'),
    },
    {
      title: 'Run Session',
      count: 'Start',
      icon: <PlayArrow />,
      color: '#4caf50',
      action: () => navigate('/run-session'),
    },
    {
      title: 'Analytics',
      count: 'View',
      icon: <Assessment />,
      color: '#ff9800',
      action: () => alert('Analytics coming soon!'),
    },
  ];

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h3" component="h1" gutterBottom>
          HMT Research Platform
        </Typography>
        <Typography variant="h6" color="text.secondary">
          Human-Machine Teaming Decision Analysis
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {cards.map((card, index) => (
          <Grid item xs={12} md={3} key={index}>
            <Card 
              sx={{ 
                cursor: 'pointer',
                transition: 'transform 0.2s',
                '&:hover': { transform: 'translateY(-4px)' },
              }}
              onClick={card.action}
            >
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                  <Box
                    sx={{
                      p: 1,
                      borderRadius: 2,
                      backgroundColor: card.color,
                      color: 'white',
                      mr: 2,
                    }}
                  >
                    {card.icon}
                  </Box>
                  <Typography variant="h6">{card.title}</Typography>
                </Box>
                <Typography variant="h3" component="div">
                  {card.count}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      <Paper sx={{ mt: 4, p: 3 }}>
        <Typography variant="h5" gutterBottom>
          Quick Actions
        </Typography>
        <Box sx={{ mt: 2 }}>
          <Button
            variant="contained"
            onClick={() => navigate('/scenarios')}
            sx={{ mr: 2 }}
          >
            Manage Scenarios
          </Button>
          <Button
            variant="outlined"
            onClick={() => navigate('/experiments')}
            sx={{ mr: 2 }}
          >
            Create Experiment
          </Button>
          <Button
            variant="outlined"
            onClick={() => navigate('/run-session')}
          >
            Start Session
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}

export default Dashboard;
'@
Set-Content -Path "frontend\src\pages\Dashboard.js" -Value $updatedDashboard

Write-Host "CRUD functionality added! Restarting services..." -ForegroundColor Green

# Restart backend to load new endpoints
docker-compose restart backend

# Frontend will auto-reload with changes
Write-Host "Waiting for services to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nCRUD functionality added successfully!" -ForegroundColor Green
Write-Host "`nNew features:" -ForegroundColor Cyan
Write-Host "- Full Scenarios management page at /scenarios" -ForegroundColor White
Write-Host "- Create new scenarios with form" -ForegroundColor White
Write-Host "- View scenario details" -ForegroundColor White
Write-Host "- Edit existing scenarios" -ForegroundColor White
Write-Host "- Delete scenarios" -ForegroundColor White
Write-Host "- Import JSON files" -ForegroundColor White
Write-Host "`nRefresh http://localhost:3000 and click on 'Scenarios' or 'Manage Scenarios'" -ForegroundColor Yellow