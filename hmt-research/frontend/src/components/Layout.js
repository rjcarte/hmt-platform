import React from 'react';
import {
  AppBar, Toolbar, Typography, Button, IconButton, Menu, MenuItem,
  Box, Container, Switch, FormControlLabel
} from '@mui/material';
import { AccountCircle, Brightness4, Brightness7 } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

function Layout({ children }) {
  const navigate = useNavigate();
  const { user, logout, darkMode, toggleDarkMode, isAdmin } = useAuth();
  const [anchorEl, setAnchorEl] = React.useState(null);

  const handleMenu = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <Box sx={{ minHeight: '100vh', backgroundColor: 'background.default' }}>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" sx={{ flexGrow: 1, cursor: 'pointer' }} onClick={() => navigate('/dashboard')}>
            HMT Research Platform
          </Typography>
          
          <Button color="inherit" onClick={() => navigate('/dashboard')}>Dashboard</Button>
          <Button color="inherit" onClick={() => navigate('/scenarios')}>Scenarios</Button>
          <Button color="inherit" onClick={() => navigate('/experiments')}>Experiments</Button>
          <Button color="inherit" onClick={() => navigate('/run-session')}>Run Session</Button>
          {isAdmin && <Button color="inherit" onClick={() => navigate('/users')}>Users</Button>}
          
          <IconButton color="inherit" onClick={toggleDarkMode} sx={{ ml: 1 }}>
            {darkMode ? <Brightness7 /> : <Brightness4 />}
          </IconButton>
          
          <div>
            <IconButton
              size="large"
              onClick={handleMenu}
              color="inherit"
            >
              <AccountCircle />
            </IconButton>
            <Menu
              anchorEl={anchorEl}
              open={Boolean(anchorEl)}
              onClose={handleClose}
            >
              <MenuItem disabled>
                <Typography variant="body2">{user?.full_name}</Typography>
              </MenuItem>
              <MenuItem onClick={() => { handleClose(); navigate('/settings'); }}>Settings</MenuItem>
              <MenuItem onClick={handleLogout}>Logout</MenuItem>
            </Menu>
          </div>
        </Toolbar>
      </AppBar>
      
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        {children}
      </Container>
    </Box>
  );
}

export default Layout;
