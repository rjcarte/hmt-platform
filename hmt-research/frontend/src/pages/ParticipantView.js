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
