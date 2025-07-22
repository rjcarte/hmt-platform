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
