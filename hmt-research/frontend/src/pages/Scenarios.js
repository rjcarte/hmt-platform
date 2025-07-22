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
