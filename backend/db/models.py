from sqlalchemy import Column, Integer, String, JSON, DateTime, ForeignKey, Enum
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime
import enum
import uuid

Base = declarative_base()

class JobStatus(enum.Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class AnalysisJob(Base):
    """
    Tracks the execution of a Nextflow MGE-Sift pipeline job.
    Normalizing jobs allows for robust tracking and resumability.
    """
    __tablename__ = "analysis_jobs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    sample_name = Column(String, nullable=False)
    status = Column(Enum(JobStatus), default=JobStatus.QUEUED)
    parameters = Column(JSON, default={})
    
    # Track versions for reproducibility
    nextflow_version = Column(String)
    mgesift_version = Column(String)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    error_message = Column(String, nullable=True)

class MGEResult(Base):
    """
    Stores the final integration results for downstream comparative analysis.
    """
    __tablename__ = "mge_results"

    id = Column(Integer, primary_key=True, autoincrement=True)
    job_id = Column(String, ForeignKey("analysis_jobs.id"), nullable=False, index=True)
    
    mge_type = Column(String, nullable=False, index=True) # e.g., 'Plasmid', 'Integron', 'Prophage'
    classification = Column(String, nullable=False, index=True) # 'Acquired' vs 'Intrinsic'
    
    contig_id = Column(String, nullable=False, index=True)
    start_pos = Column(Integer)
    end_pos = Column(Integer)
    
    evidence_score = Column(Integer)
    metadata_json = Column(JSON, default={}) # Holds tool-specific raw outputs (e.g., mob-suite details)
    
    job = relationship("AnalysisJob")
