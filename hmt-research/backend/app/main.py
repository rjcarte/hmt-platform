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
