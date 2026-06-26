# MGE-Sift Complete Integration Guide

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Web Browser (HTTP/HTTPS)                      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Vue.js Web UI    │
                    │  :3000 (3 containers│
                    │  - Dashboard       │
                    │  - Results Viewer  │
                    │  - Reports         │
                    │  - Settings        │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   FastAPI Server   │
                    │  :8000 (1 container)
                    │  - REST API        │
                    │  - Auth Mgmt       │
                    │  - Data Export     │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
     ┌──────────▼────────┐ ┌──▼──────────────┬──────────┐
     │   Nextflow       │ │  Database        │ Storage   │
     │  :5432 (batch)   │ │  - SQLite/PG    │ - S3/GCS  │
     │  - Orchestration │ │  - Results      │ - Azure   │
     │  - Monitoring    │ │  - Samples      │ - Local   │
     └──────────────────┘ └─────────────────┴──────────┘
           │
     ┌─────▼─────────┐
     │ Compute Nodes │
     │ (Cloud/Local) │
     │ - Annotation  │
     │ - Detection   │
     │ - Integration │
     └───────────────┘
```

## Component Interaction

### 1. User Interface (Web UI)
- **Framework**: Vue.js 3 with TypeScript
- **Location**: http://localhost:3000
- **Container**: `mge-web`
- **Responsibilities**:
  - Sample upload and job submission
  - Real-time pipeline status monitoring
  - Results visualization and filtering
  - Report generation and export
  - API key management

### 2. API Server
- **Framework**: FastAPI with Python 3.10+
- **Location**: http://localhost:8000
- **Container**: `mge-api`
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /stats` - Pipeline statistics
  - `GET /samples` - List samples
  - `GET /results` - Query results
  - `GET /samples/{id}/report` - Get report
  - `POST /results` - Submit result
  - `GET /results/export` - Export data
- **Authentication**: API Key (X-Token header)

### 3. Pipeline Orchestration
- **Framework**: Nextflow DSL2
- **Location**: Runs in container `mge-pipeline`
- **Stages**:
  1. Annotation (Prokka/Bakta)
  2. Plasmid detection
  3. IS element detection
  4. Integron detection
  5. Prophage detection
  6. Genomic island detection
  7. Repeat detection
  8. HGT signals
  9. AMR detection
  10. Integration & reporting

### 4. Data Persistence
- **Primary**: SQLite or PostgreSQL
- **Results**: Stored in `mge_results.db` or PostgreSQL
- **Genomic Data**: FASTA files in `/workspace/genomes`
- **Pipeline Outputs**: Results in `/workspace/results`

## Quick Start

### Complete System Setup

```bash
# 1. Clone and navigate
git clone https://github.com/yourorg/MGE-Sift.git
cd MGE-Sift

# 2. Create environment file
cat > .env <<EOF
MGE_API_KEY=your-secure-api-key-here
POSTGRES_USER=mge
POSTGRES_PASSWORD=secure-db-password
POSTGRES_DB=mge_results
EOF

# 3. Build all services
docker-compose build

# 4. Start services
docker-compose up -d

# 5. Verify services
docker-compose ps

# 6. Access applications
# Web UI: http://localhost:3000
# API Docs: http://localhost:8000/docs
# API: http://localhost:8000
```

### Access Points

| Component | URL | Purpose |
|-----------|-----|---------|
| Web UI | http://localhost:3000 | Interactive user interface |
| API | http://localhost:8000 | REST API endpoints |
| API Docs | http://localhost:8000/docs | Interactive API documentation |
| API Redoc | http://localhost:8000/redoc | Alternative API documentation |

## Workflow

### 1. Sample Upload via Web UI
```
User Upload → Web UI → Validates → Sends to API → Creates job → DB
```

### 2. Pipeline Execution
```
API triggers → Nextflow → Stages execute → Results stored → API notified
```

### 3. Results Retrieval
```
Web UI → Queries API → Database fetch → Processes → Displays
```

### 4. Report Generation
```
Web UI → Aggregates results → Calculates stats → Generates report → Export
```

## Configuration

### Environment Variables

Create `.env` file in project root:

```env
# API Configuration
MGE_API_KEY=your-secure-key-change-in-production

# Database
POSTGRES_USER=mge
POSTGRES_PASSWORD=secure-password
POSTGRES_DB=mge_results

# Web UI
VITE_API_URL=http://api:8000

# Pipeline
NEXTFLOW_HOME=/opt/nextflow
NXF_WORK=/workspace/work

# Environment
ENVIRONMENT=production
LOG_LEVEL=INFO
```

### Docker Compose Profiles

```bash
# Standard setup (SQLite)
docker-compose up

# With PostgreSQL
docker-compose --profile prod-pg up

# Single service
docker-compose up web   # Just web UI
docker-compose up api   # Just API
```

## API Integration Example

### JavaScript/TypeScript
```typescript
import axios from 'axios'

const apiClient = axios.create({
  baseURL: 'http://localhost:8000',
  headers: { 'x-token': 'your-api-key' }
})

// Get stats
const stats = await apiClient.get('/stats')
console.log(stats.data.total_samples)

// Get samples
const samples = await apiClient.get('/samples')
samples.data.forEach(s => console.log(s.sample_id))

// Get results
const results = await apiClient.get('/results?sample_id=sample_001')
results.data.forEach(r => console.log(r.element_type))
```

### Python
```python
import requests

headers = {'x-token': 'your-api-key'}
base_url = 'http://localhost:8000'

# Health check
response = requests.get(f'{base_url}/health', headers=headers)
print(response.json())

# Get statistics
stats = requests.get(f'{base_url}/stats', headers=headers).json()
print(f"Total samples: {stats['total_samples']}")

# Get results
results = requests.get(
    f'{base_url}/results',
    params={'sample_id': 'sample_001'},
    headers=headers
).json()
```

### cURL
```bash
# Health check
curl http://localhost:8000/health

# Get statistics
curl -H "x-token: your-api-key" http://localhost:8000/stats

# List samples
curl -H "x-token: your-api-key" http://localhost:8000/samples

# Get results
curl -H "x-token: your-api-key" \
  "http://localhost:8000/results?sample_id=sample_001"

# Export results as CSV
curl -H "x-token: your-api-key" \
  "http://localhost:8000/results/export?format=csv" \
  > results.csv
```

## Data Flow Examples

### Example 1: Upload Sample and Monitor

```
User Interface             Backend API            Database           Pipeline
     │                         │                      │                  │
     │─ Upload FASTA ─────────→ │                      │                  │
     │                         │─ Validate ──────────→ │                  │
     │                         │─ Create entry ──────→ │                  │
     │                         │                      │                  │
     │ ← Sample ID            │                      │                  │
     │                         │─ Submit job ────────────────────────────→ │
     │                         │                      │                  │
     │ Poll status            │                      │                  │
     │─ GET /stats ─────────→ │─ Query results ────→ │                  │
     │ ← Status              │ ← Data returns ────→ │ Running...         │
     │                         │                      │                  │
     │ Poll again             │                      │                  │
     │─ GET /samples ────────→ │                      │ [Processing]     │
     │ ← Updated info ────────│                      │                  │
     │                         │                      │                  │
```

### Example 2: View Results

```
User Interface             Backend API            Database
     │                         │                      │
     │─ GET /results ────────→ │─ Query results ────→ │
     │                         │                      │
     │                         │ ← Filtered data ───← │
     │ ← JSON results ────────│                      │
     │                         │                      │
     │ Display table          │                      │
     │ Render charts          │                      │
     │ Allow filtering        │                      │
     │                         │                      │
     │─ GET /results/export ─→ │─ Generate CSV ─────→ │
     │                         │                      │
     │                         │ ← CSV stream ──────← │
     │ ← Download file ───────│                      │
     │                         │                      │
```

## Monitoring

### Check Service Status
```bash
# All services
docker-compose ps

# Specific service
docker-compose ps api

# View logs
docker-compose logs -f web      # Web UI logs
docker-compose logs -f api      # API logs
docker-compose logs -f pipeline # Pipeline logs

# Real-time monitoring
docker stats
```

### Health Checks

```bash
# API health
curl http://localhost:8000/health

# Web UI health
curl http://localhost:3000

# Database connection
curl -H "x-token: your-key" http://localhost:8000/stats
```

## Troubleshooting

### Web UI Can't Connect to API
```bash
# Check API is running
docker-compose ps api

# Check API is responsive
curl http://localhost:8000/health

# Check network connectivity
docker-compose logs api | tail -20

# Restart services
docker-compose restart api web
```

### Results Not Appearing

```bash
# Check database
docker-compose exec api python -c \
  "from mge_utilities import SQLiteDatabaseManager; db = SQLiteDatabaseManager('/data/mge_results.db'); db.connect(); print(db.query_results(sample_id='sample_001'))"

# Check API logs
docker-compose logs api | grep -i error

# Check file permissions
docker-compose exec api ls -la /data/
```

### Pipeline Not Processing

```bash
# Check Nextflow status
docker-compose logs pipeline | tail -50

# Check work directory
docker-compose exec pipeline ls -la /workspace/work/

# Manually trigger (if needed)
docker-compose exec pipeline nextflow run /app/nextflow/production.nf --help
```

### Database Issues

```bash
# Check database size
docker-compose exec api sqlite3 /data/mge_results.db ".info"

# Backup database
docker-compose exec api cp /data/mge_results.db /data/backup.db

# View tables
docker-compose exec api sqlite3 /data/mge_results.db ".tables"

# Query sample data
docker-compose exec api sqlite3 /data/mge_results.db \
  "SELECT sample_id, status FROM samples LIMIT 5;"
```

## Performance Tuning

### Resource Allocation

```bash
# Edit docker-compose.yml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

### Database Optimization

```sql
-- Create indexes for faster queries
CREATE INDEX idx_sample_id ON analysis_results(sample_id);
CREATE INDEX idx_element_type ON analysis_results(element_type);
CREATE INDEX idx_timestamp ON analysis_results(timestamp);
```

## Security Best Practices

1. **Change Default API Key**
   ```bash
   # Generate secure key
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   
   # Set in .env
   MGE_API_KEY=your-generated-secure-key
   ```

2. **Use HTTPS in Production**
   - Add reverse proxy (Nginx)
   - Configure SSL certificates

3. **Database Security**
   - Use strong passwords
   - Restrict network access
   - Regular backups

4. **API Rate Limiting**
   - Implement in API gateway
   - Monitor for abuse

## Scaling

### Horizontal Scaling
```bash
# Run multiple API instances with load balancer
# Update docker-compose for multiple replicas
services:
  api:
    deploy:
      replicas: 3
```

### Vertical Scaling
```bash
# Increase resources per service
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
```

## Deployment

### Production Checklist
- [ ] Change all default credentials
- [ ] Enable HTTPS/SSL
- [ ] Configure backups
- [ ] Set up monitoring/alerts
- [ ] Configure auto-scaling
- [ ] Test failover procedures
- [ ] Document runbooks
- [ ] Plan disaster recovery

### Backup Strategy
```bash
# Automated daily backup
0 2 * * * docker-compose exec api \
  cp /data/mge_results.db /backups/mge_$(date +\%Y\%m\%d).db

# Upload to S3
aws s3 sync /backups/ s3://mge-backups/
```

## Support & Resources

- [Web UI Documentation](./web/README.md)
- [API Documentation](./python/api_server.py)
- [Production Guide](./PRODUCTION_GUIDE.md)
- [Quick Start](./PRODUCTION_QUICKSTART.md)
- GitHub Issues: Report bugs and request features
- GitHub Discussions: Community support

---

**Integration Guide Version**: 2.0.0  
**Last Updated**: 2026-06-26  
**Status**: Production Ready
