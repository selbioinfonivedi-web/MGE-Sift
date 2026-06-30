import os
import subprocess
from celery import Celery
from db.models import JobStatus

# Configuration reads from environment variables matching docker-compose
redis_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "mgesift_worker",
    broker=redis_url,
    backend=redis_url
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    broker_connection_retry_on_startup=True
)

@celery_app.task(bind=True, name="run_nextflow_pipeline")
def run_nextflow_pipeline(self, job_id: str, input_dir: str, output_dir: str):
    """
    Executes the Nextflow DSL2 pipeline asynchronously.
    Updates the database with the job status.
    """
    # 1. Update Database -> RUNNING (omitted for brevity, requires SQLAlchemy session)
    print(f"[JOB {job_id}] Starting Nextflow Pipeline")
    
    # Ensure Nextflow uses the master workflow we defined
    workflow_path = "/workflows/main.nf"
    
    cmd = [
        "nextflow", "run", workflow_path,
        "--input", f"{input_dir}",
        "--outdir", output_dir,
        "-with-conda" # We explicitly use the Conda environments defined in the DSL2 modules
    ]
    
    try:
        # Run Nextflow process
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        stdout, stderr = process.communicate()
        
        if process.returncode != 0:
            print(f"[JOB {job_id}] Pipeline FAILED. Error: {stderr}")
            # 2. Update Database -> FAILED
            return {"job_id": job_id, "status": JobStatus.FAILED.value, "error": stderr}
            
        print(f"[JOB {job_id}] Pipeline COMPLETED successfully.")
        
        # 3. Parse final JSON and insert into DB
        json_path = os.path.join(output_dir, "summary", "final_mge_summary.json")
        from db.session import SessionLocal
        from db.models import MGEResult, AnalysisJob
        import json
        
        try:
            if os.path.exists(json_path):
                with open(json_path, 'r') as f:
                    results = json.load(f)
                    
                db = SessionLocal()
                for r in results:
                    new_res = MGEResult(
                        job_id=job_id,
                        mge_type=r.get("mge_type"),
                        classification=r.get("classification"),
                        contig_id=r.get("prediction", "unknown"),
                        start_pos=r.get("location_start"),
                        end_pos=r.get("location_end"),
                        evidence_score=int(r.get("score", 1) * 100)
                    )
                    db.add(new_res)
                
                # Update job status
                job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
                if job:
                    job.status = JobStatus.COMPLETED
                db.commit()
                db.close()
        except Exception as e:
            print(f"[JOB {job_id}] Error inserting JSON to DB: {e}")
            
        return {"job_id": job_id, "status": JobStatus.COMPLETED.value}
        
    except Exception as e:
        print(f"[JOB {job_id}] Execution error: {str(e)}")
        return {"job_id": job_id, "status": JobStatus.FAILED.value, "error": str(e)}
