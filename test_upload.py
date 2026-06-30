import requests

print("========================================")
print("🧪 MGE-Sift End-to-End Upload Test 🧪")
print("========================================")

# 1. Create a mock fasta file
fasta_content = ">test_contig\nATGCGTACGTAGCTAGCTAGCTAGCTGATCGATCGTAGCTAGCTAGCTAGCTAGCTAGCTAGC"
files = {'file': ('test_genome.fasta', fasta_content, 'application/octet-stream')}

print("\n1. Submitting genome to FastAPI backend...")
response = requests.post('http://localhost:8000/upload', files=files)

if response.status_code == 200:
    data = response.json()
    job_id = data.get('job_id')
    print(f"✅ Success! Genome uploaded.")
    print(f"✅ Job ID Generated: {job_id}")
    print(f"✅ Message: {data.get('message')}")
    
    print("\n2. Checking Job Queue Status via API...")
    status_resp = requests.get(f'http://localhost:8000/analysis/{job_id}')
    print(f"Status Response: {status_resp.json()}")
    
    print("\nCheck your docker-compose terminal to watch the Celery worker pick up the job and execute Nextflow!")
else:
    print(f"❌ Failed. Status Code: {response.status_code}")
    print(response.text)
