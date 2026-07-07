from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Any
from sqlalchemy.orm import Session
from db.session import SessionLocal
from db.models import AnalysisJob

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class AnalysisCreate(BaseModel):
    sample_id: str
    project_id: str
    parameters: dict = {}

@router.get("/")
async def list_jobs(db: Session = Depends(get_db)) -> Any:
    """
    Retrieve all analysis jobs, ordered by newest first.
    """
    jobs = db.query(AnalysisJob).order_by(AnalysisJob.created_at.desc()).all()
    return [{
        "id": job.id,
        "sample_name": job.sample_name,
        "status": job.status.value if job.status else "UNKNOWN",
        "created_at": job.created_at.isoformat() if job.created_at else None
    } for job in jobs]

@router.post("/", status_code=status.HTTP_202_ACCEPTED)
async def submit_analysis(job_req: AnalysisCreate) -> Any:
    """
    Submit a new MGE-Sift analysis job.
    Delegates heavy computation to Celery worker via Nextflow.
    """
    # TODO: Create database record for Job
    # TODO: Trigger Celery task
    job_id = "temp-uuid-1234"
    return {"job_id": job_id, "status": "QUEUED", "message": "Analysis job submitted successfully."}

@router.get("/{job_id}")
async def get_analysis_status(job_id: str) -> Any:
    """
    Retrieve the status of a submitted analysis job.
    """
    return {"job_id": job_id, "status": "RUNNING", "progress": "Plasmid Detection"}

@router.delete("/{job_id}")
async def cancel_analysis(job_id: str) -> Any:
    """
    Cancel a running analysis job.
    """
    return {"job_id": job_id, "status": "CANCELED"}

