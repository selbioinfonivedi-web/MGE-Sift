import requests
import time
import sys
import os

# Default path if none is provided via command line
FASTA_FILE = r"I:\Epistatic_data\Phase1_Metadata_and_Profiling\consensus_genomes\SRR11589112.consensus.fa"
API_BASE_URL = "http://localhost:8000/api/v1"

def test_pipeline(file_path):
    print(f"--- MGE-Sift Pipeline Tester ---")
    
    if not os.path.exists(file_path):
        print(f"[ERROR] Could not find the file at: {file_path}")
        print("Please check the path and try again.")
        sys.exit(1)
        
    print(f"[1] Uploading {os.path.basename(file_path)}...")
    
    with open(file_path, "rb") as f:
        files = {"file": (os.path.basename(file_path), f, "application/octet-stream")}
        try:
            response = requests.post(f"{API_BASE_URL}/upload/", files=files)
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] Upload failed: {e}")
            if e.response:
                print(e.response.text)
            sys.exit(1)
            
    upload_data = response.json()
    job_id = upload_data.get("job_id")
    print(f"[OK] Upload successful! Job ID: {job_id}")
    print(f"[2] Waiting for Celery and Nextflow to process the genome...")
    
    # Poll for results
    while True:
        try:
            res = requests.get(f"{API_BASE_URL}/results/{job_id}")
            if res.status_code == 200:
                data = res.json()
                status = data.get("status")
                
                if status == "COMPLETED":
                    mges = data.get("results", [])
                    print(f"\n[OK] Pipeline COMPLETED successfully!")
                    print(f"[OK] Found {len(mges)} Mobile Genetic Elements/AMR genes.")
                    
                    # Print a summary of the first 5 hits
                    print("\n--- Top 5 Hits ---")
                    for hit in mges[:5]:
                        print(f"- {hit['mge_type']} | {hit['prediction']} | {hit['classification']} | Pos: {hit['location_start']}-{hit['location_end']}")
                    break
                elif status == "FAILED":
                    print(f"\n[X] Pipeline FAILED.")
                    print(f"Error: {data.get('error')}")
                    break
                else:
                    print(".", end="", flush=True)
                    time.sleep(5) # Wait 5 seconds before checking again
            else:
                print(".", end="", flush=True)
                time.sleep(5)
                
        except requests.exceptions.RequestException as e:
            print(f"\n[ERROR] Failed to check status: {e}")
            sys.exit(1)

if __name__ == "__main__":
    target_file = FASTA_FILE
    if len(sys.argv) > 1:
        target_file = sys.argv[1]
    test_pipeline(target_file)
