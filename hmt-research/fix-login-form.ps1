# fix-login-form.ps1

Write-Host "Fixing login form data issue..." -ForegroundColor Green

# Update AuthContext to send form data instead of JSON
$fixedAuthContext = @'
import React, { createContext, useState, useContext, useEffect } from 'react';
import axios from 'axios';

const AuthContext = createContext(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      // Set axios default header
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      // Get user info
      fetchUser();
    } else {
      setLoading(false);
    }
  }, []);

  const fetchUser = async () => {
    try {
      const response = await axios.get('http://localhost:8000/api/v1/auth/me');
      setUser(response.data);
      setDarkMode(response.data.preferences?.darkMode || false);
    } catch (error) {
      console.error('Failed to fetch user', error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  const login = async (email, password) => {
    // Create form data - this is the fix!
    const formData = new URLSearchParams();
    formData.append('username', email);  // OAuth2 expects 'username' field
    formData.append('password', password);
    
    const response = await axios.post('http://localhost:8000/api/v1/auth/login', formData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });
    
    const { access_token, user } = response.data;
    
    localStorage.setItem('token', access_token);
    axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
    
    setUser(user);
    setDarkMode(user.preferences?.darkMode || false);
    
    return user;
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete axios.defaults.headers.common['Authorization'];
    setUser(null);
    setDarkMode(false);
  };

  const toggleDarkMode = async () => {
    const newDarkMode = !darkMode;
    setDarkMode(newDarkMode);
    
    // Update on server
    try {
      await axios.put('http://localhost:8000/api/v1/auth/me/preferences', {
        darkMode: newDarkMode
      });
    } catch (error) {
      console.error('Failed to update preferences', error);
    }
  };

  return (
    <AuthContext.Provider value={{
      user,
      loading,
      darkMode,
      login,
      logout,
      toggleDarkMode,
      isAdmin: user?.role === 'admin'
    }}>
      {children}
    </AuthContext.Provider>
  );
};
'@
Set-Content -Path "frontend\src\contexts\AuthContext.js" -Value $fixedAuthContext

Write-Host "Login form data issue fixed!" -ForegroundColor Green
Write-Host "The frontend will auto-reload. Try logging in again with:" -ForegroundColor Yellow
Write-Host "Email: admin@hmt.local" -ForegroundColor White  
Write-Host "Password: admin123" -ForegroundColor White