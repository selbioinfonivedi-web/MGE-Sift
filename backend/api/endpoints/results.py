from fastapi import APIRouter, HTTPException, Depends
from typing import Any
from db.session import SessionLocal
from db.models import MGEResult, AnalysisJob
from sqlalchemy.orm import Session

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/{job_id}")
async def get_results(job_id: str, db: Session = Depends(get_db)) -> Any:
    """
    Retrieve the final structured JSON results of an MGE-Sift analysis.
    """
    job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    results = db.query(MGEResult).filter(MGEResult.job_id == job_id).all()
    
    return {
        "job_id": job.id,
        "sample_name": job.sample_name,
        "status": job.status.value if job.status else None,
        "results": [
            {
                "mge_type": r.mge_type,
                "prediction": r.contig_id,
                "location_start": r.start_pos,
                "location_end": r.end_pos,
                "score": r.evidence_score,
                "classification": r.classification
            } for r in results
        ]
    }

@router.get("/{job_id}/download")
async def download_report(job_id: str, format: str = "pdf") -> Any:
    """
    Download the final analysis report (PDF, HTML, CSV).
    """
    return {"message": f"Download link for {format} report generated."}
