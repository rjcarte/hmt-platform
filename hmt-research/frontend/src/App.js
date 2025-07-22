import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { AuthProvider, useAuth } from './contexts/AuthContext';

// Import pages
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Scenarios from './pages/Scenarios';
import Experiments from './pages/Experiments';
import RunSession from './pages/RunSession';
import ParticipantView from './pages/ParticipantView';
import Settings from './pages/Settings';
import Users from './pages/Users';
import Layout from './components/Layout';

function AppContent() {
  const { user, loading, darkMode } = useAuth();

  const theme = React.useMemo(
    () =>
      createTheme({
        palette: {
          mode: darkMode ? 'dark' : 'light',
          primary: {
            main: '#1976d2',
          },
          secondary: {
            main: '#dc004e',
          },
        },
        typography: {
          fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
        },
      }),
    [darkMode]
  );

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Routes>
        <Route path="/login" element={!user ? <Login /> : <Navigate to="/dashboard" />} />
        <Route path="/participant/:sessionId" element={<ParticipantView />} />
        
        {/* Protected routes */}
        <Route
          path="/dashboard"
          element={user ? <Layout><Dashboard /></Layout> : <Navigate to="/login" />}
        />
        <Route
          path="/scenarios"
          element={user ? <Layout><Scenarios /></Layout> : <Navigate to="/login" />}
        />
        <Route
          path="/experiments"
          element={user ? <Layout><Experiments /></Layout> : <Navigate to="/login" />}
        />
        <Route
          path="/run-session"
          element={user ? <Layout><RunSession /></Layout> : <Navigate to="/login" />}
        />
        <Route
          path="/settings"
          element={user ? <Layout><Settings /></Layout> : <Navigate to="/login" />}
        />
        <Route
          path="/users"
          element={user?.role === 'admin' ? <Layout><Users /></Layout> : <Navigate to="/dashboard" />}
        />
        <Route path="/" element={<Navigate to="/dashboard" />} />
      </Routes>
    </ThemeProvider>
  );
}

function App() {
  return (
    <Router>
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </Router>
  );
}

export default App;
