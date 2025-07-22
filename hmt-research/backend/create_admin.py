from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.user import User
import uuid

# Database connection
engine = create_engine("postgresql://hmt_user:local_dev_password@postgres:5432/hmt_platform")
SessionLocal = sessionmaker(bind=engine)
db = SessionLocal()

try:
    # Check if admin exists
    admin = db.query(User).filter(User.email == "admin@hmt.local").first()
    if admin:
        print("Admin already exists")
    else:
        # Create admin
        admin = User(
            id=uuid.uuid4(),
            email="admin@hmt.local",
            hashed_password=User.hash_password("admin123"),
            full_name="Administrator",
            role="admin",
            is_active=True
        )
        db.add(admin)
        db.commit()
        print("Admin user created successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
