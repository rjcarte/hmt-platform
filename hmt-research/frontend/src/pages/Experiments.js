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
