# MGE-Sift Web UI Integration - Quick Reference

## 5-Minute Setup

```bash
# Start complete stack
docker-compose up -d

# Verify all services running
docker-compose ps

# Access web UI
open http://localhost:3000
```

## Services

| Service | URL | Port | Purpose |
|---------|-----|------|---------|
| Web UI | http://localhost:3000 | 3000 | User Interface |
| API | http://localhost:8000 | 8000 | REST Backend |
| API Docs | http://localhost:8000/docs | 8000 | API Documentation |

## Key Features

### 📊 Dashboard
- Real-time statistics
- Sample upload
- Recent activity

### 🔍 Results Viewer
- Filter by sample/element type
- Confidence filtering
- Export results (JSON/CSV)

### 📈 Reports
- Sample summaries
- Element distribution
- Classification analysis

### ⚙️ Settings
- API configuration
- Theme selection
- Pipeline defaults

## Common Tasks

### Upload Sample
1. Go to Dashboard
2. Click "Upload Sample"
3. Select FASTA file
4. Enter sample name
5. Click "Upload & Process"

### View Results
1. Go to Results tab
2. Select sample (optional)
3. Filter by element type (optional)
4. Adjust confidence threshold
5. Click "Export CSV" to download

### Generate Report
1. Go to Reports tab
2. Select sample from dropdown
3. Review summary cards
4. View distributions
5. Download JSON/PDF

### Configure API
1. Go to Settings
2. Update API endpoint if needed
3. Enter API key
4. Click "Test Connection"
5. Click "Save Settings"

## API Key

### Get API Key
```bash
# From .env file or environment
echo $MGE_API_KEY

# Or generate new one
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Set in UI
1. Settings → API Configuration
2. Paste API key
3. Click "Test Connection"
4. "Save Settings"

## Troubleshooting

### Web UI Won't Load
```bash
# Check if running
docker-compose ps web

# View logs
docker-compose logs web

# Restart
docker-compose restart web
```

### Can't Connect to API
```bash
# Check API running
curl http://localhost:8000/health

# Check API key
docker-compose logs api | grep -i key

# Verify in UI settings
```

### No Results Showing
```bash
# Check database
curl -H "x-token: your-key" http://localhost:8000/stats

# Check samples
curl -H "x-token: your-key" http://localhost:8000/samples
```

## File Structure

```
MGE-Sift/
├── web/                    # Frontend code
│   ├── src/
│   │   ├── components/    # Reusable components
│   │   ├── pages/         # Page components
│   │   ├── stores/        # State management
│   │   └── api.ts         # API client
│   ├── Dockerfile         # Frontend image
│   └── package.json       # Dependencies
├── docker-compose.yml      # Complete stack
├── INTEGRATION_GUIDE.md    # Full integration docs
└── PRODUCTION_QUICKSTART.md
```

## Environment Variables

```env
# For docker-compose
MGE_API_KEY=your-key
POSTGRES_PASSWORD=secure-pw

# For web UI (.env in web/)
VITE_API_URL=http://localhost:8000
```

## Development

### Run Web UI Locally
```bash
cd web
npm install
npm run dev
# Visit http://localhost:5173
```

### Build for Production
```bash
cd web
npm run build
npm run preview
```

### Run Tests
```bash
cd web
npm run type-check
npm run lint
```

## Useful Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f web

# Restart service
docker-compose restart api

# Rebuild image
docker-compose build web

# Remove volumes (WARNING: deletes data)
docker-compose down -v

# Access database
docker-compose exec api sqlite3 /data/mge_results.db

# Check resource usage
docker stats
```

## Next Steps

1. [Read Integration Guide](./INTEGRATION_GUIDE.md) - Full documentation
2. [Production Guide](./PRODUCTION_GUIDE.md) - Deployment guide
3. [Web README](./web/README.md) - Frontend details
4. [API Documentation](./python/api_server.py) - API reference

---

**Version**: 2.0.0 | **Status**: Production Ready
