import os
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime

# ── Database Config (SQLite is free and permanent) ──────────────────────────
DB_PATH = os.path.join("data", "travelbuddy.db")
SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# ── Models ──────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    hashed_password = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

    trips = relationship("Trip", back_populates="owner")

class Trip(Base):
    __tablename__ = "trips"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    destination = Column(String)
    title = Column(String)
    narration = Column(Text)
    captions = Column(JSON)  # List of strings
    hashtags = Column(JSON)  # List of strings
    video_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="trips")

# ── Initialization ───────────────────────────────────────────────────────────
def init_db():
    os.makedirs("data", exist_ok=True)
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    init_db()
