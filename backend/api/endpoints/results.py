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

from fastapi.responses import FileResponse, PlainTextResponse
import os

@router.get("/{job_id}/fasta")
async def get_fasta(job_id: str, db: Session = Depends(get_db)):
    """
    Stream a single-pseudomolecule FASTA for this job to be used as a reference in IGV.
    """
    job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
    if not job or not job.parameters or "input_file" not in job.parameters:
        raise HTTPException(status_code=404, detail="FASTA file not found for this job")
    
    file_path = job.parameters["input_file"]
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="FASTA file no longer exists on disk")
        
    seq = []
    with open(file_path, 'r') as f:
        for line in f:
            if not line.startswith('>'):
                seq.append(line.strip())
    # Format sequence to 80 chars per line for standard fasta
    full_seq = "".join(seq)
    lines = [">chr1"]
    for i in range(0, len(full_seq), 80):
        lines.append(full_seq[i:i+80])
        
    return PlainTextResponse("\n".join(lines) + "\n")

@router.get("/{job_id}/bed")
async def get_bed(job_id: str, db: Session = Depends(get_db)):
    """
    Dynamically generate a BED file from the job's MGE results for IGV.
    """
    results = db.query(MGEResult).filter(MGEResult.job_id == job_id).all()
    if not results:
        return PlainTextResponse("")
        
    lines = []
    
    def get_color(mge_type):
        colors = {
            'AMR': '239,68,68',      # red
            'Integron': '59,130,246', # blue
            'Prophage': '168,85,247', # purple
            'Plasmid': '34,197,94',   # green
            'IS_Element': '234,179,8',# yellow
            'Genomic_Island': '20,184,166' # teal
        }
        return colors.get(mge_type, '107,114,128') # gray
        
    for r in results:
        chrom = "chr1"
        start = r.start_pos
        end = r.end_pos
        name = r.contig_id.replace(" ", "_") # contig_id contains the prediction name
        score = int((r.evidence_score or 0) * 1000) # BED scores are 0-1000
        strand = "+"
        thickStart = start
        thickEnd = end
        itemRgb = get_color(r.mge_type)
        
        # BED requires 0-based start, half-open
        lines.append(f"{chrom}\t{start}\t{end}\t{name}\t{score}\t{strand}\t{thickStart}\t{thickEnd}\t{itemRgb}")
        
    return PlainTextResponse("\n".join(lines) + "\n")
@router.get("/{job_id}/download")
async def download_report(job_id: str, format: str = "pdf") -> Any:
    """
    Download the final analysis report (PDF, HTML, CSV).
    """
    return {"message": f"Download link for {format} report generated."}
