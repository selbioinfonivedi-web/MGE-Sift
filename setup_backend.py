import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

base_dir = r"e:\MGE-Sift\MGE-Sift"
backend_dir = os.path.join(base_dir, "backend")
db_dir = os.path.join(base_dir, "database")

files = {}

# config.yaml
files[os.path.join(backend_dir, "config.yaml")] = """
app:
  name: "MGE-Sift API"
  version: "1.0.0"
  debug: false
database:
  url: "postgresql://postgres:postgres@localhost:5432/mgesift"
celery:
  broker_url: "redis://localhost:6379/0"
  result_backend: "redis://localhost:6379/0"
logging:
  level: "INFO"
"""

# backend/core/config.py
files[os.path.join(backend_dir, "core", "config.py")] = """
import yaml
import os
from pydantic import BaseModel

class AppConfig(BaseModel):
    name: str
    version: str
    debug: bool

class DatabaseConfig(BaseModel):
    url: str

class CeleryConfig(BaseModel):
    broker_url: str
    result_backend: str

class LoggingConfig(BaseModel):
    level: str

class Settings(BaseModel):
    app: AppConfig
    database: DatabaseConfig
    celery: CeleryConfig
    logging: LoggingConfig

def load_config() -> Settings:
    config_path = os.getenv("CONFIG_PATH", os.path.join(os.path.dirname(__file__), "..", "config.yaml"))
    with open(config_path, "r") as f:
        data = yaml.safe_load(f)
    return Settings(**data)

settings = load_config()
"""

# backend/core/logger.py
files[os.path.join(backend_dir, "core", "logger.py")] = """
import logging
import sys
from pythonjsonlogger import jsonlogger
from backend.core.config import settings

def setup_logging():
    logger = logging.getLogger("mgesift")
    logger.setLevel(settings.logging.level)
    
    # Avoid duplicate logs if run multiple times
    if logger.handlers:
        return logger

    logHandler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(levelname)s %(name)s %(message)s'
    )
    logHandler.setFormatter(formatter)
    logger.addHandler(logHandler)
    return logger

logger = setup_logging()
"""

# database/models.py
files[os.path.join(db_dir, "models.py")] = """
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime, timezone

Base = declarative_base()

class Upload(Base):
    __tablename__ = "uploads"
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String, nullable=False)
    filepath = Column(String, nullable=False)
    uploaded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    analyses = relationship("Analysis", back_populates="upload")

class Analysis(Base):
    __tablename__ = "analyses"
    id = Column(Integer, primary_key=True, index=True)
    upload_id = Column(Integer, ForeignKey("uploads.id"))
    status = Column(String, default="pending") # pending, processing, completed, failed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    results = Column(JSON, nullable=True)
    error_message = Column(String, nullable=True)
    
    upload = relationship("Upload", back_populates="analyses")
"""

# database/session.py
files[os.path.join(db_dir, "session.py")] = """
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from backend.core.config import settings

engine = create_engine(settings.database.url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
"""

# backend/schemas.py
files[os.path.join(backend_dir, "schemas.py")] = """
from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime

class UploadResponse(BaseModel):
    id: int
    filename: str
    message: str

class AnalysisCreate(BaseModel):
    upload_id: int

class AnalysisResponse(BaseModel):
    id: int
    upload_id: int
    status: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class AnalysisResultResponse(BaseModel):
    id: int
    status: str
    results: Optional[Any]
    error_message: Optional[str]

class SummaryResponse(BaseModel):
    total_analyses: int
    completed: int
    failed: int
    pending: int
    processing: int

class StatisticsResponse(BaseModel):
    avg_processing_time_seconds: float
"""

# backend/celery_app.py
files[os.path.join(backend_dir, "celery_app.py")] = """
from celery import Celery
from backend.core.config import settings

celery_app = Celery(
    "mgesift_worker",
    broker=settings.celery.broker_url,
    backend=settings.celery.result_backend
)

celery_app.conf.task_routes = {
    "backend.worker.*": "main-queue"
}
"""

# backend/worker.py
files[os.path.join(backend_dir, "worker.py")] = """
from backend.celery_app import celery_app
from database.session import SessionLocal
from database.models import Analysis
import time
import json
from backend.core.logger import logger

@celery_app.task(bind=True)
def run_analysis_task(self, analysis_id: int):
    logger.info(f"Starting analysis task for analysis_id: {analysis_id}")
    db = SessionLocal()
    try:
        analysis = db.query(Analysis).filter(Analysis.id == analysis_id).first()
        if not analysis:
            logger.error(f"Analysis {analysis_id} not found")
            return
            
        analysis.status = "processing"
        db.commit()
        
        # Simulate processing time
        logger.info(f"Processing analysis {analysis_id}...")
        time.sleep(5) 
        
        # Fake results
        analysis.results = {"mge_detected": 42, "score": 0.95}
        analysis.status = "completed"
        db.commit()
        logger.info(f"Completed analysis task for analysis_id: {analysis_id}")
    except Exception as e:
        logger.exception(f"Error in analysis {analysis_id}")
        db.rollback()
        
        analysis = db.query(Analysis).filter(Analysis.id == analysis_id).first()
        if analysis:
            analysis.status = "failed"
            analysis.error_message = str(e)
            db.commit()
    finally:
        db.close()
"""

# backend/api/routes.py
files[os.path.join(backend_dir, "api", "routes.py")] = """
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import os
import shutil

from database.session import get_db
from database.models import Analysis, Upload
from backend.schemas import (
    UploadResponse, AnalysisCreate, AnalysisResponse, 
    AnalysisResultResponse, SummaryResponse, StatisticsResponse
)
from backend.worker import run_analysis_task
from backend.core.logger import logger

router = APIRouter()

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.get("/health")
def health_check():
    logger.info("Health check endpoint called")
    return {"status": "ok", "message": "Service is healthy"}

@router.post("/upload", response_model=UploadResponse)
def upload_file(file: UploadFile = File(...), db: Session = Depends(get_db)):
    logger.info(f"Uploading file: {file.filename}")
    filepath = os.path.join(UPLOAD_DIR, file.filename)
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    db_upload = Upload(filename=file.filename, filepath=filepath)
    db.add(db_upload)
    db.commit()
    db.refresh(db_upload)
    
    logger.info(f"File uploaded successfully with id {db_upload.id}")
    return UploadResponse(id=db_upload.id, filename=db_upload.filename, message="File uploaded successfully")

@router.post("/analysis", response_model=AnalysisResponse)
def create_analysis(data: AnalysisCreate, db: Session = Depends(get_db)):
    logger.info(f"Creating analysis for upload_id: {data.upload_id}")
    upload = db.query(Upload).filter(Upload.id == data.upload_id).first()
    if not upload:
        raise HTTPException(status_code=404, detail="Upload not found")
        
    db_analysis = Analysis(upload_id=data.upload_id, status="pending")
    db.add(db_analysis)
    db.commit()
    db.refresh(db_analysis)
    
    # Trigger Celery task
    run_analysis_task.delay(db_analysis.id)
    
    logger.info(f"Analysis created with id {db_analysis.id}")
    return db_analysis

@router.get("/analysis/{id}", response_model=AnalysisResponse)
def get_analysis(id: int, db: Session = Depends(get_db)):
    analysis = db.query(Analysis).filter(Analysis.id == id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return analysis

@router.get("/results/{id}", response_model=AnalysisResultResponse)
def get_results(id: int, db: Session = Depends(get_db)):
    analysis = db.query(Analysis).filter(Analysis.id == id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return analysis

@router.get("/summary", response_model=SummaryResponse)
def get_summary(db: Session = Depends(get_db)):
    total = db.query(Analysis).count()
    completed = db.query(Analysis).filter(Analysis.status == "completed").count()
    failed = db.query(Analysis).filter(Analysis.status == "failed").count()
    pending = db.query(Analysis).filter(Analysis.status == "pending").count()
    processing = db.query(Analysis).filter(Analysis.status == "processing").count()
    
    return SummaryResponse(
        total_analyses=total,
        completed=completed,
        failed=failed,
        pending=pending,
        processing=processing
    )

@router.get("/statistics", response_model=StatisticsResponse)
def get_statistics(db: Session = Depends(get_db)):
    # Dummy stat for now, can be computed based on created_at and updated_at
    completed_analyses = db.query(Analysis).filter(Analysis.status == "completed").all()
    if not completed_analyses:
        return StatisticsResponse(avg_processing_time_seconds=0.0)
        
    total_time = 0.0
    for a in completed_analyses:
        total_time += (a.updated_at - a.created_at).total_seconds()
        
    return StatisticsResponse(avg_processing_time_seconds=total_time / len(completed_analyses))

@router.delete("/analysis/{id}")
def delete_analysis(id: int, db: Session = Depends(get_db)):
    logger.info(f"Deleting analysis {id}")
    analysis = db.query(Analysis).filter(Analysis.id == id).first()
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")
        
    db.delete(analysis)
    db.commit()
    return {"message": f"Analysis {id} deleted successfully"}
"""

# backend/main.py
files[os.path.join(backend_dir, "main.py")] = """
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.api.routes import router
from backend.core.config import settings
from backend.core.logger import logger
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

app = FastAPI(
    title=settings.app.name,
    version=settings.app.version,
    debug=settings.app.debug
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

@app.on_event("startup")
async def startup_event():
    logger.info("Starting up MGE-Sift backend")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down MGE-Sift backend")
"""

for path, content in files.items():
    create_file(path, content)

print("Files created successfully.")
