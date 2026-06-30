from fastapi import APIRouter, UploadFile, File, HTTPException, status
from typing import Any
import shutil
import os

router = APIRouter()

UPLOAD_DIR = "/tmp/mge_sift_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/")
async def upload_genome(file: UploadFile = File(...)) -> Any:
    """
    Upload a genome FASTA/FASTQ file for analysis.
    Stores the file temporarily or to S3-compatible storage.
    """
    if not file.filename.endswith(('.fasta', '.fna', '.fastq', '.gz')):
        raise HTTPException(status_code=400, detail="Invalid file type. Only FASTA/FASTQ supported.")
        
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not save file: {str(e)}")
    finally:
        file.file.close()
        
    return {"filename": file.filename, "status": "UPLOADED", "path": file_path}
