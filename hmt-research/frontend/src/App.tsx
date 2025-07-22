import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { QueryClient, QueryClientProvider } from 'react-query';

// Firebase
import { initializeApp } from 'firebase/app';
import { getAuth, onAuthStateChanged, User } from 'firebase/auth';

// Components
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import ScenarioLibrary from './pages/ScenarioLibrary';
import ExperimentDesigner from './pages/ExperimentDesigner';
import SessionRunner from './pages/SessionRunner';
import { AuthContext } from './contexts/AuthContext';

// Initialize Firebase (config from environment)
const firebaseConfig = JSON.parse(process.env.REACT_APP_FIREBASE_CONFIG || '{}');
const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);

// Material-UI theme
const theme = createTheme({
  palette: {
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
});

// React Query client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setUser(user);
      setLoading(false);
    });

    return unsubscribe;
  }, []);

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <AuthContext.Provider value={{ user, setUser }}>
          <Router>
            <Routes>
              <Route path="/login" element={!user ? <Login /> : <Navigate to="/" />} />
              <Route path="/" element={user ? <Dashboard /> : <Navigate to="/login" />} />
              <Route path="/scenarios" element={user ? <ScenarioLibrary /> : <Navigate to="/login" />} />
              <Route path="/experiments" element={user ? <ExperimentDesigner /> : <Navigate to="/login" />} />
              <Route path="/session/:sessionId" element={<SessionRunner />} />
            </Routes>
          </Router>
        </AuthContext.Provider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;