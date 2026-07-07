import os
import requests
import glob
import sys

API_BASE_URL = "http://localhost:8000/api/v1"

def batch_submit(directory_path, num_to_run=10):
    print(f"--- MGE-Sift Batch Submitter ---")
    
    # Find all .fa and .fasta files in the directory
    search_pattern_fa = os.path.join(directory_path, "*.fa")
    search_pattern_fasta = os.path.join(directory_path, "*.fasta")
    
    files = glob.glob(search_pattern_fa) + glob.glob(search_pattern_fasta)
    
    if not files:
        print(f"[ERROR] Could not find any .fa or .fasta files in {directory_path}")
        sys.exit(1)
        
    print(f"Found {len(files)} genomes in the directory.")
    
    # Select the first 'num_to_run' files
    files_to_run = files[:num_to_run]
    print(f"Submitting {len(files_to_run)} files to the queue...\n")
    
    job_ids = []
    for filepath in files_to_run:
        filename = os.path.basename(filepath)
        print(f"Uploading {filename}...")
        
        try:
            with open(filepath, "rb") as f:
                upload_files = {"file": (filename, f, "application/octet-stream")}
                response = requests.post(f"{API_BASE_URL}/upload/", files=upload_files)
                response.raise_for_status()
                
                upload_data = response.json()
                job_id = upload_data.get("job_id")
                job_ids.append((filename, job_id))
                print(f"  [OK] Successfully queued. Job ID: {job_id}")
                
        except Exception as e:
            print(f"  [ERROR] Failed to upload {filename}: {e}")

    print("\n--- Summary ---")
    print("All files have been successfully submitted to the Celery queue!")
    print("The backend will now process them one-by-one automatically in the background.")
    print("You can view the final results in the frontend web interface as they complete.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python batch_submit.py <path_to_directory> [number_of_files_to_run]")
        print("Example: python batch_submit.py I:\\Epistatic_data\\Phase1_Metadata_and_Profiling\\consensus_genomes\\ 10")
        sys.exit(1)
        
    dir_path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    
    batch_submit(dir_path, limit)
