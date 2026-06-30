from fastapi import APIRouter, UploadFile, File, HTTPException, status, Depends
from typing import Any
from sqlalchemy.orm import Session
import shutil
import os

from db.session import SessionLocal
from db.models import AnalysisJob, JobStatus
from worker.celery_app import run_nextflow_pipeline

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

UPLOAD_DIR = "/tmp/mge_sift_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/")
async def upload_genome(file: UploadFile = File(...), db: Session = Depends(get_db)) -> Any:
    """
    Upload a genome FASTA/FASTQ file for analysis and trigger the background pipeline.
    """
    if not file.filename.endswith(('.fasta', '.fna', '.fastq', '.gz', '.fa')):
        raise HTTPException(status_code=400, detail="Invalid file type. Only FASTA/FASTQ supported.")
        
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not save file: {str(e)}")
    finally:
        file.file.close()
        
    # 1. Create a database record
    new_job = AnalysisJob(
        sample_name=file.filename.split('.')[0],
        status=JobStatus.QUEUED,
        parameters={"input_file": file_path}
    )
    db.add(new_job)
    db.commit()
    db.refresh(new_job)
    
    # 2. Trigger the Celery worker in the background
    output_dir = f"/tmp/mge_sift_results/{new_job.id}"
    os.makedirs(output_dir, exist_ok=True)
    run_nextflow_pipeline.delay(new_job.id, file_path, output_dir)
        
    return {
        "job_id": new_job.id,
        "sample_name": new_job.sample_name, 
        "status": "QUEUED",
        "message": "File uploaded and Nextflow pipeline triggered successfully!"
    }
