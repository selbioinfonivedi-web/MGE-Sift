# MGE-Sift Production Pipeline - Deployment & Operations Guide

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Local Development](#local-development)
3. [Docker Deployment](#docker-deployment)
4. [Cloud Deployment](#cloud-deployment)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
7. [Best Practices](#best-practices)

---

## Architecture Overview

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    MGE-Sift v2.0 Production                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Nextflow        │         │  FastAPI         │             │
│  │  Pipeline (DSL2) │─────────│  Results Server  │             │
│  │                  │         │                  │             │
│  │  • Modular       │         │  • REST API      │             │
│  │  • Parallelized  │         │  • Authentication│             │
│  │  • Error-safe    │         │  • Export formats│             │
│  └────────┬─────────┘         └────────┬─────────┘             │
│           │                            │                        │
│           v                            v                        │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │  SQLite/PostgreSQL   │  │  S3/GCS/Azure Blob   │            │
│  │  Results Database    │  │  Input/Output Store  │            │
│  └──────────────────────┘  └──────────────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Orchestration | Nextflow DSL2 | 23.10+ |
| API Server | FastAPI | 0.104+ |
| Database | SQLite/PostgreSQL | 3.x / 15 |
| Containerization | Docker | 24.0+ |
| Container Orchestration | Docker Compose / Kubernetes | Latest |
| Cloud Providers | AWS (ECS), GCP (Cloud Run), Azure (App Service) | Latest |
| CI/CD | GitHub Actions | Native |
| Python | 3.10+ | |

---

## Local Development

### Prerequisites

```bash
# System dependencies
- Docker & Docker Compose
- Nextflow (23.10+)
- Python 3.10+
- Conda or Mamba

# Optional for development
- Git
- PostgreSQL client tools
- AWS CLI (for S3 operations)
```

### Setup

```bash
# 1. Clone repository
git clone https://github.com/yourorg/MGE-Sift.git
cd MGE-Sift

# 2. Install conda environment
conda env create -f environment.yml
conda activate mge_pipeline

# 3. Install Python development dependencies
pip install -r requirements-dev.txt

# 4. Download/verify databases
bash scripts/install_dbs.sh ./databases

# 5. Run unit tests
pytest tests/test_pipeline.py -v

# 6. Run integration tests
bash tests/integration_tests.sh
```

### Running Locally

```bash
# Run single sample
nextflow run nextflow/production.nf \
  --input genomes/sample.fasta \
  --outdir ./results \
  --max_cpus 4 \
  --max_memory_gb 8

# Run with sample sheet
cat > samples.csv <<EOF
sample_id,fasta_path
sample_001,./genomes/sample1.fa
sample_002,./genomes/sample2.fa
EOF

nextflow run nextflow/production.nf \
  --sample_sheet samples.csv \
  --outdir ./results

# Run with test data
nextflow run nextflow/production.nf \
  --input ./test_data \
  --test_mode true \
  --sample_limit 2

# View results
ls -la results/published/integration/
```

### Development API Server

```bash
# Start FastAPI server
python -m uvicorn python.api_server:app --reload --host 0.0.0.0 --port 8000

# Access documentation
open http://localhost:8000/docs

# Test API
curl -X GET http://localhost:8000/health
curl -X GET http://localhost:8000/stats -H "x-token: dev-key-change-in-production"
```

---

## Docker Deployment

### Build Docker Image

```bash
# Production image
docker build -f Dockerfile.production -t mge-sift:2.0.0 .

# Push to registry
docker tag mge-sift:2.0.0 ghcr.io/yourorg/mge-sift:2.0.0
docker push ghcr.io/yourorg/mge-sift:2.0.0
```

### Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f api
docker-compose logs -f pipeline

# Run specific service
docker-compose up -d api

# Stop all services
docker-compose down

# Clean up volumes
docker-compose down -v
```

### Docker Configuration

```yaml
# .env file for docker-compose
MGE_API_KEY=your-secure-key-here
POSTGRES_USER=mge
POSTGRES_PASSWORD=secure-password
POSTGRES_DB=mge_results
ENVIRONMENT=production
```

---

## Cloud Deployment

### AWS Deployment

#### Using CloudFormation

```bash
# Deploy stack
aws cloudformation create-stack \
  --stack-name mge-sift-prod \
  --template-body file://infrastructure/cloudformation.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=production \
    ParameterKey=ImageUri,ParameterValue=123456789.dkr.ecr.us-east-1.amazonaws.com/mge-sift:2.0.0 \
    ParameterKey=DesiredCount,ParameterValue=2 \
  --region us-east-1

# Monitor deployment
aws cloudformation describe-stacks \
  --stack-name mge-sift-prod \
  --region us-east-1
```

#### Using AWS CLI

```bash
# Push image to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/mge-sift:2.0.0

# Create ECS task
aws ecs register-task-definition \
  --family mge-sift-task \
  --container-definitions file://task-definition.json \
  --region us-east-1

# Update service
aws ecs update-service \
  --cluster mge-sift-cluster-production \
  --service mge-sift-service-production \
  --force-new-deployment \
  --region us-east-1
```

### GCP Deployment

```bash
# Deploy to Cloud Run
gcloud run deploy mge-sift-api \
  --image gcr.io/your-project/mge-sift:2.0.0 \
  --platform managed \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --set-env-vars ENVIRONMENT=production,DATABASE_URL=postgresql://... \
  --allow-unauthenticated

# Deploy with Kubernetes
kubectl apply -f infrastructure/kubernetes.yaml

# View deployment
kubectl get pods
kubectl logs -f deployment/mge-sift-api
```

### Azure Deployment

```bash
# Deploy ARM template
az deployment group create \
  --resource-group mge-sift-rg \
  --template-file infrastructure/azure_deployment.json \
  --parameters \
    projectName=mge-sift \
    environment=production

# Push image to ACR
az acr build \
  --registry mgesiftacr \
  --image mge-sift:2.0.0 .

# Deploy to App Service
az webapp create \
  --resource-group mge-sift-rg \
  --plan mge-sift-asp-production \
  --name mge-sift-api-production \
  --deployment-container-image-name mgesiftacr.azurecr.io/mge-sift:2.0.0
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

The pipeline automatically:

1. **On Push to Main/Develop**
   - Runs linting (Black, Flake8, Pylint)
   - Runs unit tests (pytest)
   - Runs security scans (Trivy, OWASP)
   - Builds Docker image
   - Runs integration tests
   - Deploys to staging (develop branch)

2. **On Version Tag (v*)**
   - Creates GitHub Release
   - Builds and tags Docker image
   - Runs full test suite
   - Deploys to production
   - Sends Slack notification

### Manual Workflow Trigger

```bash
# Trigger deployment manually
gh workflow run production.yml \
  --ref main \
  -f environment=staging
```

### Secrets Configuration

Add these to GitHub Settings → Secrets:

```
STAGING_DEPLOY_KEY        - SSH key for staging server
STAGING_HOST              - staging.example.com
PROD_DEPLOY_KEY           - SSH key for production server
PROD_HOST                 - prod.example.com
SLACK_WEBHOOK             - Slack notification webhook
```

---

## Monitoring & Troubleshooting

### Health Checks

```bash
# API health
curl http://localhost:8000/health

# Pipeline logs
tail -f results/logs/*.log

# Database connection
sqlite3 results/mge_results.db ".tables"
```

### Common Issues

#### Nextflow Out of Memory

```bash
# Increase memory
export NXF_OPTS='-Xmx8g'
nextflow run nextflow/production.nf ...

# Or in config
process.memory = '8 GB'
```

#### Database Locks

```bash
# Check active connections
sqlite3 results/mge_results.db "PRAGMA database_list"

# PostgreSQL
psql -c "SELECT pid, query FROM pg_stat_activity WHERE pid <> pg_backend_pid();"
```

#### Docker Resource Issues

```bash
# Increase Docker resources
# Edit Docker Desktop settings or /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "memory": 8589934592,
  "cpus": 4.0
}
```

### Logging

```bash
# Enable debug logging
export NXF_DEBUG=1
export LOG_LEVEL=DEBUG

# View Nextflow trace report
open results/.nextflow.log

# PostgreSQL query log
psql -c "ALTER SYSTEM SET log_statement = 'all';"
psql -c "SELECT pg_reload_conf();"
```

---

## Best Practices

### 1. Security

- **Secrets Management**
  ```bash
  # Use environment variables, not hardcoded secrets
  export MGE_API_KEY=$(aws secretsmanager get-secret-value --secret-id mge-api-key | jq -r .SecretString)
  ```

- **API Authentication**
  - Always use HTTPS in production
  - Rotate API keys regularly
  - Use short-lived tokens when possible

- **Database Security**
  - Enable SSL connections
  - Use strong passwords
  - Restrict network access
  - Regular backups

### 2. Performance Optimization

```bash
# Parallel processing
nextflow run nextflow/production.nf \
  --max_cpus 16 \
  --max_memory_gb 32 \
  -with-dag dag.pdf

# Use work directory on fast storage
export NXF_WORK=/ssd/nextflow_work

# Resume failed workflows
nextflow run nextflow/production.nf \
  -resume \
  --max_cpus 4
```

### 3. Monitoring & Alerting

```bash
# Set up CloudWatch alarms (AWS)
aws cloudwatch put-metric-alarm \
  --alarm-name mge-sift-api-cpu \
  --alarm-description "Alert if CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold

# Enable APM (Application Performance Monitoring)
# New Relic, DataDog, or CloudWatch insights
```

### 4. Backup & Disaster Recovery

```bash
# Backup database
pg_dump -h localhost -U mge mge_results | gzip > backup_$(date +%Y%m%d).sql.gz

# Backup to S3
aws s3 cp backup_20231215.sql.gz s3://mge-sift-backups/

# Test restore
gunzip < backup_20231215.sql.gz | psql -U mge mge_results
```

### 5. Version Management

```bash
# Git workflow
git checkout -b feature/new-stage
# ... make changes ...
git commit -m "feat: add new MGE detection stage"
git push origin feature/new-stage
# Create pull request

# Tag release
git tag -a v2.1.0 -m "Release version 2.1.0"
git push origin v2.1.0
```

### 6. Cost Optimization

- Use reserved instances for long-running services
- Schedule non-critical workloads during off-peak hours
- Use spot instances for batch processing
- Implement data retention policies
- Monitor cloud spending with budget alerts

### 7. Documentation

- Keep README updated
- Document configuration options
- Maintain runbooks for common operations
- Record troubleshooting solutions
- Update API documentation with Swagger/OpenAPI

---

## Support & Contribution

- **Issues**: GitHub Issues for bug reports
- **Discussions**: GitHub Discussions for questions
- **Contributions**: See CONTRIBUTING.md
- **Contact**: support@example.com

---

**Last Updated**: 2026-06-26
**Version**: 2.0.0
**Status**: Production Ready
