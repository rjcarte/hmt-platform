# setup-frontend-ui.ps1

Write-Host "Setting up HMT Research Platform Frontend UI..." -ForegroundColor Green

# Update package.json with all dependencies
$packageJson = @'
{
  "name": "hmt-research-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@emotion/react": "^11.11.1",
    "@emotion/styled": "^11.11.0",
    "@mui/icons-material": "^5.14.19",
    "@mui/material": "^5.14.20",
    "@mui/x-data-grid": "^6.18.3",
    "axios": "^1.6.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1",
    "react-scripts": "5.0.1",
    "recharts": "^2.10.3"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
'@
Set-Content -Path "frontend\package.json" -Value $packageJson

# Create API service
$apiService = @'
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
  create: (data) => api.post('/api/v1/scenarios/', data),
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
New-Item -Path "frontend\src\services" -ItemType Directory -Force | Out-Null
Set-Content -Path "frontend\src\services\api.js" -Value $apiService

# Create main App component
$appComponent = @'
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { Box } from '@mui/material';

// Import pages
import Dashboard from './pages/Dashboard';
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
Set-Content -Path "frontend\src\App.js" -Value $appComponent

# Create Dashboard page
$dashboardPage = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Grid, Paper, Typography, Box, Button, Card, CardContent,
  IconButton, Tooltip
} from '@mui/material';
import {
  Science, PlayArrow, Assessment, Upload
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
          <Grid item xs={12} md={4} key={index}>
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
            startIcon={<Upload />}
            component="label"
            sx={{ mr: 2 }}
          >
            Import Scenarios
            <input
              type="file"
              hidden
              accept=".json"
              onChange={async (e) => {
                if (e.target.files[0]) {
                  try {
                    await scenarioAPI.import(e.target.files[0]);
                    loadStats();
                    alert('Scenarios imported successfully!');
                  } catch (error) {
                    alert('Error importing scenarios');
                  }
                }
              }}
            />
          </Button>
          <Button
            variant="outlined"
            onClick={() => navigate('/experiments')}
          >
            Create Experiment
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}

export default Dashboard;
'@
New-Item -Path "frontend\src\pages" -ItemType Directory -Force | Out-Null
Set-Content -Path "frontend\src\pages\Dashboard.js" -Value $dashboardPage

# Create Experiments page
$experimentsPage = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Typography, Box, Button, Paper, List, ListItem, 
  ListItemText, Checkbox, Dialog, DialogTitle, DialogContent,
  DialogActions, TextField, Chip, IconButton
} from '@mui/material';
import { Add, Delete } from '@mui/icons-material';
import { scenarioAPI, experimentAPI } from '../services/api';

function Experiments() {
  const [scenarios, setScenarios] = useState([]);
  const [selectedScenarios, setSelectedScenarios] = useState([]);
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [experimentName, setExperimentName] = useState('');
  const [experimentDescription, setExperimentDescription] = useState('');

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

  const toggleScenario = (scenarioId) => {
    setSelectedScenarios(prev => {
      if (prev.includes(scenarioId)) {
        return prev.filter(id => id !== scenarioId);
      }
      return [...prev, scenarioId];
    });
  };

  const createExperiment = async () => {
    try {
      await experimentAPI.create({
        name: experimentName,
        description: experimentDescription,
        scenario_sequence: selectedScenarios,
      });
      alert('Experiment created successfully!');
      setCreateDialogOpen(false);
      setSelectedScenarios([]);
      setExperimentName('');
      setExperimentDescription('');
    } catch (error) {
      alert('Error creating experiment');
    }
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4" component="h1">
          Experiment Designer
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => setCreateDialogOpen(true)}
          disabled={selectedScenarios.length === 0}
        >
          Create Experiment ({selectedScenarios.length} scenarios)
        </Button>
      </Box>

      <Paper sx={{ p: 2 }}>
        <Typography variant="h6" gutterBottom>
          Available Scenarios
        </Typography>
        <List>
          {scenarios.map((scenario) => (
            <ListItem
              key={scenario.id}
              sx={{
                border: '1px solid #e0e0e0',
                borderRadius: 1,
                mb: 1,
                '&:hover': { backgroundColor: '#f5f5f5' },
              }}
            >
              <Checkbox
                checked={selectedScenarios.includes(scenario.id)}
                onChange={() => toggleScenario(scenario.id)}
              />
              <ListItemText
                primary={scenario.title}
                secondary={
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      {scenario.description}
                    </Typography>
                    <Box sx={{ mt: 1 }}>
                      <Chip label={scenario.category} size="small" sx={{ mr: 1 }} />
                      {scenario.meta_data?.ai_alignment && (
                        <Chip 
                          label={scenario.meta_data.ai_alignment} 
                          size="small" 
                          color={scenario.meta_data.ai_alignment === 'aligned' ? 'success' : 'error'}
                          sx={{ mr: 1 }}
                        />
                      )}
                      {scenario.meta_data?.ai_autonomy && (
                        <Chip label={scenario.meta_data.ai_autonomy} size="small" variant="outlined" />
                      )}
                    </Box>
                  </Box>
                }
              />
            </ListItem>
          ))}
        </List>
      </Paper>

      <Dialog open={createDialogOpen} onClose={() => setCreateDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create Experiment</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Experiment Name"
            value={experimentName}
            onChange={(e) => setExperimentName(e.target.value)}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Description"
            value={experimentDescription}
            onChange={(e) => setExperimentDescription(e.target.value)}
            margin="normal"
            multiline
            rows={3}
          />
          <Typography variant="body2" sx={{ mt: 2 }}>
            Selected scenarios: {selectedScenarios.length}
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateDialogOpen(false)}>Cancel</Button>
          <Button onClick={createExperiment} variant="contained">Create</Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default Experiments;
'@
Set-Content -Path "frontend\src\pages\Experiments.js" -Value $experimentsPage

# Create RunSession page
$runSessionPage = @'
import React, { useState } from 'react';
import {
  Container, Typography, Box, Button, Paper, TextField,
  Alert
} from '@mui/material';
import { PlayArrow } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { sessionAPI } from '../services/api';

function RunSession() {
  const navigate = useNavigate();
  const [experimentId, setExperimentId] = useState('');
  const [participantId, setParticipantId] = useState('');
  const [operatorId, setOperatorId] = useState('');

  const startSession = async () => {
    try {
      const response = await sessionAPI.create({
        experiment_id: experimentId,
        participant_id: participantId,
        operator_id: operatorId,
      });
      
      // Navigate to participant view
      navigate(`/participant/${response.data.id}`);
    } catch (error) {
      alert('Error starting session. Check that experiment ID is valid.');
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 4, mb: 4 }}>
      <Paper sx={{ p: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Start New Session
        </Typography>
        
        <Alert severity="info" sx={{ mb: 3 }}>
          Enter the experiment ID from the experiments page to begin a session.
        </Alert>

        <TextField
          fullWidth
          label="Experiment ID"
          value={experimentId}
          onChange={(e) => setExperimentId(e.target.value)}
          margin="normal"
          placeholder="e.g., 123e4567-e89b-12d3-a456-426614174000"
        />
        
        <TextField
          fullWidth
          label="Participant ID"
          value={participantId}
          onChange={(e) => setParticipantId(e.target.value)}
          margin="normal"
          placeholder="e.g., P001"
        />
        
        <TextField
          fullWidth
          label="Operator ID"
          value={operatorId}
          onChange={(e) => setOperatorId(e.target.value)}
          margin="normal"
          placeholder="e.g., researcher-01"
        />

        <Button
          fullWidth
          variant="contained"
          size="large"
          startIcon={<PlayArrow />}
          onClick={startSession}
          disabled={!experimentId || !participantId || !operatorId}
          sx={{ mt: 3 }}
        >
          Start Session
        </Button>
      </Paper>
    </Container>
  );
}

export default RunSession;
'@
Set-Content -Path "frontend\src\pages\RunSession.js" -Value $runSessionPage

# Create ParticipantView page
$participantViewPage = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Typography, Box, Button, Paper, Radio, RadioGroup,
  FormControlLabel, FormControl, FormLabel, Slider, TextField,
  LinearProgress, Chip, Card, CardContent, Alert
} from '@mui/material';
import { useParams, useNavigate } from 'react-router-dom';
import { sessionAPI } from '../services/api';

function ParticipantView() {
  const { sessionId } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [scenario, setScenario] = useState(null);
  const [stepNumber, setStepNumber] = useState(0);
  const [totalSteps, setTotalSteps] = useState(0);
  const [completed, setCompleted] = useState(false);
  
  // Response state
  const [selectedOption, setSelectedOption] = useState('');
  const [confidenceRating, setConfidenceRating] = useState(3);
  const [riskRating, setRiskRating] = useState(3);
  const [thinkAloud, setThinkAloud] = useState('');

  useEffect(() => {
    loadNextScenario();
  }, [sessionId]);

  const loadNextScenario = async () => {
    try {
      setLoading(true);
      const response = await sessionAPI.getNextScenario(sessionId);
      
      if (response.data.completed) {
        setCompleted(true);
      } else {
        setScenario(response.data.scenario);
        setStepNumber(response.data.step_number);
        setTotalSteps(response.data.total_steps);
        resetForm();
      }
    } catch (error) {
      console.error('Error loading scenario:', error);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setSelectedOption('');
    setConfidenceRating(3);
    setRiskRating(3);
    setThinkAloud('');
  };

  const submitResponse = async () => {
    try {
      await sessionAPI.submitResponse(sessionId, scenario.id, {
        selected_option: selectedOption,
        confidence_rating: confidenceRating,
        risk_rating: riskRating,
        think_aloud_transcript: thinkAloud,
      });
      
      loadNextScenario();
    } catch (error) {
      alert('Error submitting response');
    }
  };

  const exportResults = async () => {
    try {
      const response = await sessionAPI.exportJSONL(sessionId);
      const blob = new Blob([response.data], { type: 'application/x-ndjson' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `session_${sessionId}.jsonl`;
      a.click();
    } catch (error) {
      alert('Error exporting results');
    }
  };

  if (loading) {
    return (
      <Container maxWidth="md" sx={{ mt: 4 }}>
        <Typography>Loading...</Typography>
      </Container>
    );
  }

  if (completed) {
    return (
      <Container maxWidth="md" sx={{ mt: 4 }}>
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography variant="h4" gutterBottom>
            Session Complete!
          </Typography>
          <Typography variant="body1" paragraph>
            Thank you for participating in this study.
          </Typography>
          <Button variant="contained" onClick={exportResults} sx={{ mt: 2 }}>
            Export Results
          </Button>
        </Paper>
      </Container>
    );
  }

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ mb: 3 }}>
        <LinearProgress 
          variant="determinate" 
          value={(stepNumber / totalSteps) * 100} 
          sx={{ mb: 2 }}
        />
        <Typography variant="body2" color="text.secondary">
          Scenario {stepNumber} of {totalSteps}
        </Typography>
      </Box>

      <Paper sx={{ p: 4, mb: 3 }}>
        <Typography variant="h5" gutterBottom>
          {scenario.title}
        </Typography>
        
        <Card sx={{ mb: 3, backgroundColor: '#f5f5f5' }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>Context</Typography>
            <Typography variant="body1" style={{ whiteSpace: 'pre-line' }}>
              {scenario.context}
            </Typography>
          </CardContent>
        </Card>

        <Alert severity="warning" sx={{ mb: 3 }}>
          <Typography variant="h6" gutterBottom>
            {scenario.decision_point}
          </Typography>
        </Alert>

        <FormControl component="fieldset" sx={{ width: '100%', mb: 3 }}>
          <FormLabel component="legend">Select your response:</FormLabel>
          <RadioGroup value={selectedOption} onChange={(e) => setSelectedOption(e.target.value)}>
            {scenario.options.map((option) => (
              <Paper key={option.id} sx={{ p: 2, mb: 1 }}>
                <FormControlLabel
                  value={option.id}
                  control={<Radio />}
                  label={
                    <Box>
                      <Typography variant="subtitle1">
                        <strong>{option.label}</strong>
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {option.description}
                      </Typography>
                    </Box>
                  }
                />
              </Paper>
            ))}
          </RadioGroup>
        </FormControl>

        <Box sx={{ mb: 3 }}>
          <Typography gutterBottom>
            Confidence in your decision: {confidenceRating}
          </Typography>
          <Slider
            value={confidenceRating}
            onChange={(e, val) => setConfidenceRating(val)}
            min={1}
            max={5}
            marks
            valueLabelDisplay="auto"
          />
        </Box>

        <Box sx={{ mb: 3 }}>
          <Typography gutterBottom>
            Risk level of this decision: {riskRating}
          </Typography>
          <Slider
            value={riskRating}
            onChange={(e, val) => setRiskRating(val)}
            min={1}
            max={5}
            marks
            valueLabelDisplay="auto"
          />
        </Box>

        <TextField
          fullWidth
          multiline
          rows={4}
          label="Think Aloud - Explain your reasoning"
          value={thinkAloud}
          onChange={(e) => setThinkAloud(e.target.value)}
          sx={{ mb: 3 }}
          placeholder="Please describe your thought process for this decision..."
        />

        <Button
          fullWidth
          variant="contained"
          size="large"
          onClick={submitResponse}
          disabled={!selectedOption}
        >
          Submit Response
        </Button>
      </Paper>
    </Container>
  );
}

export default ParticipantView;
'@
Set-Content -Path "frontend\src\pages\ParticipantView.js" -Value $participantViewPage

Write-Host "Frontend files created! Rebuilding frontend container..." -ForegroundColor Green

# Stop and rebuild frontend
docker-compose stop frontend
docker-compose build frontend
docker-compose up -d frontend

Write-Host "Waiting for frontend to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nFrontend UI setup complete!" -ForegroundColor Green
Write-Host "Access the application at: http://localhost:3000" -ForegroundColor Cyan
Write-Host "`nFeatures:" -ForegroundColor Yellow
Write-Host "- Dashboard with quick stats and actions" -ForegroundColor White
Write-Host "- Experiment designer with scenario selection" -ForegroundColor White
Write-Host "- Session runner for participants" -ForegroundColor White
Write-Host "- Clean participant interface with progress tracking" -ForegroundColor White
Write-Host "- Export results directly from the UI" -ForegroundColor White