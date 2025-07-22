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
