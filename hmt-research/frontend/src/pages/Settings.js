import React, { useState } from 'react';
import {
  Container, Paper, Typography, TextField, Button, Box,
  Alert, Divider
} from '@mui/material';
import { useAuth } from '../contexts/AuthContext';
import axios from 'axios';

function Settings() {
  const { user } = useAuth();
  const [fullName, setFullName] = useState(user?.full_name || '');
  const [email, setEmail] = useState(user?.email || '');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const handleUpdateProfile = async () => {
    try {
      setError('');
      setMessage('');
      
      await axios.put('http://localhost:8000/api/v1/auth/me', {
        full_name: fullName,
        email: email
      });
      
      setMessage('Profile updated successfully');
    } catch (err) {
      setError(err.response?.data?.detail || 'Update failed');
    }
  };

  const handleChangePassword = async () => {
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    
    try {
      setError('');
      setMessage('');
      
      await axios.put('http://localhost:8000/api/v1/auth/me', {
        password: newPassword
      });
      
      setMessage('Password changed successfully');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (err) {
      setError(err.response?.data?.detail || 'Password change failed');
    }
  };

  return (
    <Container maxWidth="md">
      <Typography variant="h4" gutterBottom>
        Account Settings
      </Typography>
      
      {message && <Alert severity="success" sx={{ mb: 2 }}>{message}</Alert>}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Profile Information
        </Typography>
        <TextField
          fullWidth
          label="Full Name"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          margin="normal"
        />
        <TextField
          fullWidth
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          margin="normal"
        />
        <Button
          variant="contained"
          onClick={handleUpdateProfile}
          sx={{ mt: 2 }}
        >
          Update Profile
        </Button>
      </Paper>
      
      <Paper sx={{ p: 3 }}>
        <Typography variant="h6" gutterBottom>
          Change Password
        </Typography>
        <TextField
          fullWidth
          label="New Password"
          type="password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          margin="normal"
        />
        <TextField
          fullWidth
          label="Confirm Password"
          type="password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          margin="normal"
        />
        <Button
          variant="contained"
          onClick={handleChangePassword}
          sx={{ mt: 2 }}
          disabled={!newPassword || !confirmPassword}
        >
          Change Password
        </Button>
      </Paper>
    </Container>
  );
}

export default Settings;
