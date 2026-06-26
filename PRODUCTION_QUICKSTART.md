# MGE-Sift Production Pipeline Quickstart

## 5-Minute Setup

### 1. Clone & Initialize
```bash
git clone https://github.com/yourorg/MGE-Sift.git
cd MGE-Sift
conda env create -f environment.yml
conda activate mge_pipeline
pip install -r requirements-dev.txt
bash scripts/install_dbs.sh ./databases
```

### 2. Run Your First Analysis
```bash
# Single sample
nextflow run nextflow/production.nf --input genomes/sample.fa --outdir ./results

# View results
cat results/published/integration/sample_mge_summary.tsv
```

### 3. Start API Server
```bash
python -m uvicorn python.api_server:app --host 0.0.0.0 --port 8000
open http://localhost:8000/docs
```

## Docker Quick Deploy

```bash
# Build and run
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f api
```

## Production Deployment

### AWS
```bash
aws cloudformation create-stack --stack-name mge-sift-prod \
  --template-body file://infrastructure/cloudformation.yaml
```

### GCP
```bash
gcloud run deploy mge-sift-api \
  --image gcr.io/your-project/mge-sift:2.0.0 \
  --platform managed --region us-central1
```

### Azure
```bash
az deployment group create --resource-group mge-sift-rg \
  --template-file infrastructure/azure_deployment.json
```

## Key Endpoints

- **Health**: `GET /health`
- **Stats**: `GET /stats`
- **Samples**: `GET /samples`
- **Results**: `GET /results?sample_id=xxx`
- **Report**: `GET /samples/{id}/report`
- **Export**: `GET /results/export?format=json|csv`

## Common Commands

```bash
# Run with custom parameters
nextflow run nextflow/production.nf \
  --input ./genomes \
  --max_cpus 8 \
  --max_memory_gb 16 \
  --outdir ./results

# Resume failed workflow
nextflow run nextflow/production.nf -resume

# Generate execution report
nextflow run nextflow/production.nf -with-report report.html

# DAG visualization
nextflow run nextflow/production.nf -with-dag dag.pdf
```

## Documentation

- [Full Production Guide](./PRODUCTION_GUIDE.md)
- [API Documentation](./python/api_server.py)
- [Nextflow Pipeline](./nextflow/production.nf)
- [Python Utilities](./python/mge_utilities.py)

## Support

- Issues: https://github.com/yourorg/MGE-Sift/issues
- Discussions: https://github.com/yourorg/MGE-Sift/discussions
- Email: support@example.com
