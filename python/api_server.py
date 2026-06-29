"""
MGE-Sift FastAPI Results Server
REST API for accessing pipeline results and metadata
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from pathlib import Path
import json
from datetime import datetime
import sqlite3
from functools import lru_cache
import os

from mge_utilities import (
    AnalysisResult,
    SQLiteDatabaseManager,
    get_logger,
    LogLevel
)

# ============================================================================
# SETUP
# ============================================================================

logger = get_logger(__name__, LogLevel.INFO)

app = FastAPI(
    title="MGE-Sift Results API",
    description="REST API for accessing mobile genetic element detection results",
    version="2.0.0"
)

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(",")],
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

# Database configuration
DB_PATH = Path(os.getenv('MGE_DB_PATH', './mge_results.db'))
API_KEY = os.getenv('MGE_API_KEY', 'dev-key-change-in-production')

db_manager = SQLiteDatabaseManager(DB_PATH, logger)

# ============================================================================
# AUTHENTICATION
# ============================================================================

async def verify_api_key(x_token: str = Header(None)):
    """Verify API key from request header."""
    if x_token is None:
        raise HTTPException(status_code=401, detail="Missing API key")
    
    if x_token != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")
    
    return x_token


# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class SampleMetadata(BaseModel):
    sample_id: str
    fasta_path: str
    created_at: str
    status: str


class ResultItem(BaseModel):
    sample_id: str
    element_type: str
    element_id: str
    location: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    classification: str
    metadata: Dict[str, Any]
    timestamp: str


class ResultSubmission(BaseModel):
    sample_id: str
    element_type: str
    element_id: str
    location: str
    confidence: float
    classification: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class SampleReport(BaseModel):
    sample_id: str
    total_elements: int
    element_types: Dict[str, int]
    avg_confidence: float
    classifications: Dict[str, int]
    timestamp: str


class PipelineStats(BaseModel):
    total_samples: int
    total_results: int
    samples_by_status: Dict[str, int]
    timestamp: str


# ============================================================================
# STARTUP/SHUTDOWN
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize database connection on startup."""
    logger.info("Starting MGE-Sift API server...")
    if db_manager.connect():
        logger.info("Database connected successfully")
    else:
        logger.error("Failed to connect to database")


@app.on_event("shutdown")
async def shutdown_event():
    """Close database connection on shutdown."""
    db_manager.disconnect()
    logger.info("API server shutdown")


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "MGE-Sift Results API",
        "version": "2.0.0",
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
            "stats": "/stats",
            "results": "/results",
            "samples": "/samples"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "database": "connected" if db_manager.connection else "disconnected"
    }


@app.get("/stats", response_model=PipelineStats, dependencies=[Depends(verify_api_key)])
async def get_pipeline_stats():
    """Get pipeline-wide statistics."""
    cursor = db_manager.connection.cursor()
    
    # Total samples
    cursor.execute("SELECT COUNT(DISTINCT sample_id) FROM samples")
    total_samples = cursor.fetchone()[0]
    
    # Total results
    cursor.execute("SELECT COUNT(*) FROM analysis_results")
    total_results = cursor.fetchone()[0]
    
    # Samples by status
    cursor.execute("SELECT status, COUNT(*) FROM samples GROUP BY status")
    samples_by_status = dict(cursor.fetchall())
    
    return {
        "total_samples": total_samples,
        "total_results": total_results,
        "samples_by_status": samples_by_status,
        "timestamp": datetime.now().isoformat()
    }


@app.get("/samples", response_model=List[SampleMetadata], dependencies=[Depends(verify_api_key)])
async def list_samples(skip: int = 0, limit: int = 100):
    """List all samples."""
    cursor = db_manager.connection.cursor()
    cursor.execute("""
        SELECT sample_id, fasta_path, created_at, status
        FROM samples
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """, (limit, skip))
    
    samples = []
    for row in cursor.fetchall():
        samples.append({
            "sample_id": row[0],
            "fasta_path": row[1],
            "created_at": row[2],
            "status": row[3]
        })
    
    return samples


@app.get("/samples/{sample_id}", response_model=SampleMetadata, dependencies=[Depends(verify_api_key)])
async def get_sample(sample_id: str):
    """Get sample metadata."""
    cursor = db_manager.connection.cursor()
    cursor.execute("""
        SELECT sample_id, fasta_path, created_at, status
        FROM samples
        WHERE sample_id = ?
    """, (sample_id,))
    
    row = cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail=f"Sample not found: {sample_id}")
    
    return {
        "sample_id": row[0],
        "fasta_path": row[1],
        "created_at": row[2],
        "status": row[3]
    }


@app.get("/results", response_model=List[ResultItem], dependencies=[Depends(verify_api_key)])
async def get_results(
    sample_id: Optional[str] = None,
    element_type: Optional[str] = None,
    skip: int = 0,
    limit: int = 100
):
    """Query analysis results."""
    cursor = db_manager.connection.cursor()
    
    # Build query
    where_parts = []
    params = []
    
    if sample_id:
        where_parts.append("sample_id = ?")
        params.append(sample_id)
    
    if element_type:
        where_parts.append("element_type = ?")
        params.append(element_type)
    
    where_clause = " AND ".join(where_parts)
    if where_clause:
        where_clause = f"WHERE {where_clause}"
    
    query = f"""
        SELECT sample_id, element_type, element_id, location, confidence, classification, metadata, timestamp
        FROM analysis_results
        {where_clause}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """
    params.extend([limit, skip])
    
    cursor.execute(query, params)
    
    results = []
    for row in cursor.fetchall():
        results.append({
            "sample_id": row[0],
            "element_type": row[1],
            "element_id": row[2],
            "location": row[3],
            "confidence": row[4],
            "classification": row[5],
            "metadata": json.loads(row[6]),
            "timestamp": row[7]
        })
    
    return results


@app.get("/samples/{sample_id}/report", response_model=SampleReport, dependencies=[Depends(verify_api_key)])
async def get_sample_report(sample_id: str):
    """Get analysis report for a sample."""
    cursor = db_manager.connection.cursor()
    
    # Verify sample exists
    cursor.execute("SELECT * FROM samples WHERE sample_id = ?", (sample_id,))
    if not cursor.fetchone():
        raise HTTPException(status_code=404, detail=f"Sample not found: {sample_id}")
    
    # Get results for sample
    cursor.execute("""
        SELECT element_type, classification, confidence
        FROM analysis_results
        WHERE sample_id = ?
    """, (sample_id,))
    
    results = cursor.fetchall()
    
    # Calculate statistics
    element_types = {}
    classifications = {"acquired": 0, "intrinsic": 0}
    confidences = []
    
    for row in results:
        element_type, classification, confidence = row
        element_types[element_type] = element_types.get(element_type, 0) + 1
        classifications[classification] += 1
        confidences.append(confidence)
    
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0
    
    return {
        "sample_id": sample_id,
        "total_elements": len(results),
        "element_types": element_types,
        "avg_confidence": avg_confidence,
        "classifications": classifications,
        "timestamp": datetime.now().isoformat()
    }


@app.post("/results", status_code=201, dependencies=[Depends(verify_api_key)])
async def submit_result(result: ResultSubmission):
    """Submit a new analysis result."""
    analysis_result = AnalysisResult(
        sample_id=result.sample_id,
        element_type=result.element_type,
        element_id=result.element_id,
        location=result.location,
        confidence=result.confidence,
        classification=result.classification,
        metadata=result.metadata
    )
    
    if db_manager.store_result(analysis_result):
        return {"status": "success", "id": result.element_id}
    else:
        raise HTTPException(status_code=500, detail="Failed to store result")


@app.get("/results/export", dependencies=[Depends(verify_api_key)])
async def export_results(
    sample_id: Optional[str] = None,
    format: str = "json"
):
    """Export results in specified format."""
    cursor = db_manager.connection.cursor()
    
    if sample_id:
        cursor.execute("""
            SELECT * FROM analysis_results WHERE sample_id = ?
        """, (sample_id,))
    else:
        cursor.execute("SELECT * FROM analysis_results")
    
    results = cursor.fetchall()
    
    if format == "json":
        data = []
        for row in results:
            data.append({
                "sample_id": row[1],
                "element_type": row[2],
                "element_id": row[3],
                "location": row[4],
                "confidence": row[5],
                "classification": row[6],
                "metadata": json.loads(row[7]),
                "timestamp": row[8]
            })
        return JSONResponse(content=data)
    
    elif format == "csv":
        import csv
        import io
        
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "sample_id", "element_type", "element_id", "location",
            "confidence", "classification", "timestamp"
        ])
        
        for row in results:
            writer.writerow([row[1], row[2], row[3], row[4], row[5], row[6], row[8]])
        
        return JSONResponse(
            content={"data": output.getvalue()},
            headers={"Content-Disposition": "attachment; filename=mge_results.csv"}
        )
    
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported format: {format}")


@app.get("/docs", include_in_schema=False)
async def docs():
    """API documentation."""
    return {"message": "See /docs for interactive documentation"}


# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Custom HTTP exception handler."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail, "timestamp": datetime.now().isoformat()}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
