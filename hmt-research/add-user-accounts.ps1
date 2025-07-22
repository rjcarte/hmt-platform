# add-user-accounts.ps1

Write-Host "Adding user accounts and dark mode..." -ForegroundColor Green

# 1. Update backend user model
Write-Host "Updating backend user model..." -ForegroundColor Yellow

$userModel = @'
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime
from passlib.context import CryptContext
from ..core.database import Base

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255))
    role = Column(String(50), default="user")  # "admin" or "user"
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime)
    preferences = Column(String, default='{}')  # JSON string for preferences like dark mode
    
    def verify_password(self, password: str) -> bool:
        return pwd_context.verify(password, self.hashed_password)
    
    @staticmethod
    def hash_password(password: str) -> str:
        return pwd_context.hash(password)
'@
Set-Content -Path "backend\app\models\user.py" -Value $userModel

# 2. Create auth schemas
$authSchemas = @'
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
import uuid

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = "user"

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    password: Optional[str] = None

class UserPreferences(BaseModel):
    darkMode: Optional[bool] = False

class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    role: str
    is_active: bool
    created_at: datetime
    preferences: dict
    
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse
'@
New-Item -Path "backend\app\schemas" -ItemType Directory -Force | Out-Null
Set-Content -Path "backend\app\schemas\auth.py" -Value $authSchemas

# 3. Create auth service
$authService = @'
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from ..core.database import get_db
from ..core.config import settings
from ..models.user import User
import json

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

async def get_admin_user(current_user: User = Depends(get_current_active_user)):
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return current_user
'@
Set-Content -Path "backend\app\services\auth.py" -Value $authService

# 4. Update auth API with full functionality
$authApi = @'
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List
import json
from ..core.database import get_db
from ..models.user import User
from ..schemas.auth import UserCreate, UserResponse, Token, UserUpdate, UserPreferences
from ..services.auth import create_access_token, get_current_active_user, get_admin_user, ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter()

@router.post("/register", response_model=UserResponse)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    # Check if user exists
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    
    # Create user
    user = User(
        email=user_data.email,
        hashed_password=User.hash_password(user_data.password),
        full_name=user_data.full_name,
        role=user_data.role
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # Parse preferences
    user.preferences = json.loads(user.preferences or '{}')
    return user

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Login and get access token"""
    user = db.query(User).filter(User.email == form_data.username).first()
    
    if not user or not user.verify_password(form_data.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()
    
    # Create token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    
    # Parse preferences
    user.preferences = json.loads(user.preferences or '{}')
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_active_user)):
    """Get current user info"""
    current_user.preferences = json.loads(current_user.preferences or '{}')
    return current_user

@router.put("/me", response_model=UserResponse)
def update_me(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update current user"""
    if user_update.email and user_update.email != current_user.email:
        # Check if new email is taken
        if db.query(User).filter(User.email == user_update.email).first():
            raise HTTPException(status_code=400, detail="Email already taken")
        current_user.email = user_update.email
    
    if user_update.full_name is not None:
        current_user.full_name = user_update.full_name
    
    if user_update.password:
        current_user.hashed_password = User.hash_password(user_update.password)
    
    db.commit()
    db.refresh(current_user)
    current_user.preferences = json.loads(current_user.preferences or '{}')
    return current_user

@router.put("/me/preferences", response_model=UserResponse)
def update_preferences(
    preferences: UserPreferences,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update user preferences"""
    current_user.preferences = json.dumps(preferences.dict())
    db.commit()
    db.refresh(current_user)
    current_user.preferences = json.loads(current_user.preferences)
    return current_user

# Admin endpoints
@router.get("/users", response_model=List[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user)
):
    """List all users (admin only)"""
    users = db.query(User).all()
    for user in users:
        user.preferences = json.loads(user.preferences or '{}')
    return users

@router.put("/users/{user_id}/toggle-active")
def toggle_user_active(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user)
):
    """Enable/disable user (admin only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.is_active = not user.is_active
    db.commit()
    
    return {"message": f"User {'activated' if user.is_active else 'deactivated'}"}

@router.delete("/users/{user_id}")
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user)
):
    """Delete user (admin only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    
    db.delete(user)
    db.commit()
    
    return {"message": "User deleted"}
'@
Set-Content -Path "backend\app\api\auth.py" -Value $authApi

# 5. Update main.py to include user model
$updatedMainPy = @'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .api import scenarios, sessions, analysis, auth
from .core.database import engine
from .models import scenario, session, user

# Create tables
scenario.Base.metadata.create_all(bind=engine)
session.Base.metadata.create_all(bind=engine)
user.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(scenarios.router, prefix=f"{settings.API_V1_STR}/scenarios", tags=["scenarios"])
app.include_router(sessions.router, prefix=f"{settings.API_V1_STR}/sessions", tags=["sessions"])
app.include_router(analysis.router, prefix=f"{settings.API_V1_STR}/analysis", tags=["analysis"])

@app.get("/")
async def root():
    return {"message": "HMT Research Platform API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "environment": settings.ENVIRONMENT}

# Create default admin user on startup
from sqlalchemy.orm import Session
from .core.database import SessionLocal
from .models.user import User

def init_db():
    db = SessionLocal()
    try:
        # Check if admin exists
        admin = db.query(User).filter(User.email == "admin@hmt.local").first()
        if not admin:
            admin = User(
                email="admin@hmt.local",
                hashed_password=User.hash_password("admin123"),
                full_name="Administrator",
                role="admin"
            )
            db.add(admin)
            db.commit()
            print("Default admin user created: admin@hmt.local / admin123")
    finally:
        db.close()

# Initialize database
init_db()
'@
Set-Content -Path "backend\app\main.py" -Value $updatedMainPy

# 6. Update SQL schema
$updatedSql = @'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table update
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    preferences TEXT DEFAULT '{}'
);

-- Existing tables remain the same
'@
$existingSql = Get-Content -Path "backend\init.sql" -Raw
$fullSql = $updatedSql + "`n`n" + $existingSql
Set-Content -Path "backend\init.sql" -Value $fullSql

# 7. Update frontend auth context
$authContext = @'
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
    const formData = new FormData();
    formData.append('username', email);
    formData.append('password', password);
    
    const response = await axios.post('http://localhost:8000/api/v1/auth/login', formData);
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
New-Item -Path "frontend\src\contexts" -ItemType Directory -Force | Out-Null
Set-Content -Path "frontend\src\contexts\AuthContext.js" -Value $authContext

# 8. Create Login page
$loginPage = @'
import React, { useState } from 'react';
import {
  Container, Paper, TextField, Button, Typography, Box, Alert, Link
} from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    
    try {
      await login(email, password);
      navigate('/dashboard');
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Paper sx={{ p: 4 }}>
        <Typography variant="h4" align="center" gutterBottom>
          HMT Research Platform
        </Typography>
        <Typography variant="h6" align="center" gutterBottom color="text.secondary">
          Sign In
        </Typography>
        
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        
        <Box component="form" onSubmit={handleSubmit}>
          <TextField
            fullWidth
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            margin="normal"
            required
          />
          <TextField
            fullWidth
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            margin="normal"
            required
          />
          <Button
            fullWidth
            type="submit"
            variant="contained"
            sx={{ mt: 3, mb: 2 }}
            disabled={loading}
          >
            Sign In
          </Button>
          
          <Box sx={{ textAlign: 'center' }}>
            <Typography variant="body2" color="text.secondary">
              Default admin: admin@hmt.local / admin123
            </Typography>
          </Box>
        </Box>
      </Paper>
    </Container>
  );
}

export default Login;
'@
Set-Content -Path "frontend\src\pages\Login.js" -Value $loginPage

# 9. Create Layout with navigation
$layout = @'
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
'@
Set-Content -Path "frontend\src\components\Layout.js" -Value $layout

# 10. Create Settings page
$settingsPage = @'
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
'@
Set-Content -Path "frontend\src\pages\Settings.js" -Value $settingsPage

# 11. Create Users management page (admin only)
$usersPage = @'
import React, { useState, useEffect } from 'react';
import {
  Container, Typography, Paper, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, IconButton, Chip,
  Button, Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, Select, MenuItem, FormControl, InputLabel
} from '@mui/material';
import {
  Block, CheckCircle, Delete, Add
} from '@mui/icons-material';
import axios from 'axios';

function Users() {
  const [users, setUsers] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [newUser, setNewUser] = useState({
    email: '',
    password: '',
    full_name: '',
    role: 'user'
  });

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await axios.get('http://localhost:8000/api/v1/auth/users');
      setUsers(response.data);
    } catch (error) {
      console.error('Error loading users:', error);
    }
  };

  const handleCreateUser = async () => {
    try {
      await axios.post('http://localhost:8000/api/v1/auth/register', newUser);
      setOpenDialog(false);
      setNewUser({ email: '', password: '', full_name: '', role: 'user' });
      loadUsers();
    } catch (error) {
      alert('Error creating user');
    }
  };

  const toggleUserActive = async (userId) => {
    try {
      await axios.put(`http://localhost:8000/api/v1/auth/users/${userId}/toggle-active`);
      loadUsers();
    } catch (error) {
      alert('Error toggling user status');
    }
  };

  const deleteUser = async (userId) => {
    if (window.confirm('Are you sure you want to delete this user?')) {
      try {
        await axios.delete(`http://localhost:8000/api/v1/auth/users/${userId}`);
        loadUsers();
      } catch (error) {
        alert('Error deleting user');
      }
    }
  };

  return (
    <Container maxWidth="lg">
      <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h4">User Management</Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => setOpenDialog(true)}
        >
          Add User
        </Button>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Role</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Created</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {users.map((user) => (
              <TableRow key={user.id}>
                <TableCell>{user.full_name}</TableCell>
                <TableCell>{user.email}</TableCell>
                <TableCell>
                  <Chip
                    label={user.role}
                    color={user.role === 'admin' ? 'primary' : 'default'}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={user.is_active ? 'Active' : 'Disabled'}
                    color={user.is_active ? 'success' : 'error'}
                    size="small"
                  />
                </TableCell>
                <TableCell>{new Date(user.created_at).toLocaleDateString()}</TableCell>
                <TableCell align="right">
                  <IconButton
                    onClick={() => toggleUserActive(user.id)}
                    color={user.is_active ? 'error' : 'success'}
                  >
                    {user.is_active ? <Block /> : <CheckCircle />}
                  </IconButton>
                  <IconButton
                    onClick={() => deleteUser(user.id)}
                    color="error"
                  >
                    <Delete />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create New User</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Full Name"
            value={newUser.full_name}
            onChange={(e) => setNewUser({ ...newUser, full_name: e.target.value })}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Email"
            type="email"
            value={newUser.email}
            onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Password"
            type="password"
            value={newUser.password}
            onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
            margin="normal"
          />
          <FormControl fullWidth margin="normal">
            <InputLabel>Role</InputLabel>
            <Select
              value={newUser.role}
              label="Role"
              onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}
            >
              <MenuItem value="user">User</MenuItem>
              <MenuItem value="admin">Admin</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Cancel</Button>
          <Button onClick={handleCreateUser} variant="contained">Create</Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default Users;
'@
Set-Content -Path "frontend\src\pages\Users.js" -Value $usersPage

# 12. Update App.js with auth and dark mode
$updatedApp = @'
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
'@
Set-Content -Path "frontend\src\App.js" -Value $updatedApp

# 13. Update frontend API service to remove hardcoded token
$updatedApiService = @'
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Token will be set by AuthContext after login

export const scenarioAPI = {
  list: () => api.get('/api/v1/scenarios/'),
  get: (id) => api.get(`/api/v1/scenarios/${id}`),
  create: (data) => api.post('/api/v1/scenarios/', data),
  update: (id, data) => api.put(`/api/v1/scenarios/${id}`, data),
  delete: (id) => api.delete(`/api/v1/scenarios/${id}`),
  import: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/api/v1/scenarios/import', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
};

export const experimentAPI = {
  create: (data) => api.post('/api/v1/sessions/experiments', data),
};

export const sessionAPI = {
  create: (data) => api.post('/api/v1/sessions/', data),
  getNextScenario: (sessionId) => api.get(`/api/v1/sessions/${sessionId}/next-scenario`),
  submitResponse: (sessionId, scenarioId, data) => 
    api.post(`/api/v1/sessions/${sessionId}/responses`, data, {
      params: { scenario_id: scenarioId }
    }),
  exportJSONL: (sessionId) => 
    api.get(`/api/v1/sessions/${sessionId}/export/jsonl`, {
      responseType: 'blob'
    }),
};

export default api;
'@
Set-Content -Path "frontend\src\services\api.js" -Value $updatedApiService

Write-Host "User accounts and dark mode added! Rebuilding services..." -ForegroundColor Green

# Restart backend
docker-compose restart backend

# Force rebuild frontend
docker-compose stop frontend
docker-compose rm -f frontend
docker-compose build frontend
docker-compose up -d frontend

Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nUser accounts system added successfully!" -ForegroundColor Green
Write-Host "`nDefault admin account:" -ForegroundColor Cyan
Write-Host "Email: admin@hmt.local" -ForegroundColor White
Write-Host "Password: admin123" -ForegroundColor White
Write-Host "`nFeatures added:" -ForegroundColor Yellow
Write-Host "- Login system with JWT authentication" -ForegroundColor White
Write-Host "- User roles (Admin/User)" -ForegroundColor White
Write-Host "- Admin can manage all users" -ForegroundColor White
Write-Host "- User settings page" -ForegroundColor White
Write-Host "- Dark mode toggle in navigation bar" -ForegroundColor White
Write-Host "- Protected routes" -ForegroundColor White
Write-Host "`nRefresh http://localhost:3000 - you'll be redirected to login" -ForegroundColor Yellow