# MGE-Sift v2.0 - Production Pipeline

A comprehensive, enterprise-grade bioinformatics pipeline for detecting and classifying mobile genetic elements (MGEs) in bacterial genomes. It distinguishes acquired vs intrinsic elements and identifies antimicrobial resistance (AMR) genes within MGEs.

## 🚀 Features

- **Nextflow DSL2 Orchestration**: Modular, scalable, and parallelizable workflow.
- **Multi-module Detection Pipeline**:
  - Genome annotation (Prokka/Bakta)
  - Plasmid detection (MOB-suite)
  - IS element detection (ISEScan)
  - Integron detection (IntegronFinder)
  - Prophage detection (PhiSpy)
  - Genomic island and repeat detection
  - HGT signals and AMR detection (RGI, ResFinder, ABRicate)
- **FastAPI Backend**: REST API for results access, querying, and exporting.
- **Vue.js 3 Web UI**: Modern, responsive dashboard for real-time statistics, sample uploads, and interactive result visualization.
- **Docker & Container Orchestration**: Multi-stage builds and `docker-compose` setup for complete reproducibility.
- **CI/CD Automation**: Automated testing, security scanning, and deployment via GitHub Actions.

## 🏗️ Architecture

MGE-Sift provides a robust architecture incorporating Nextflow for pipeline execution, FastAPI for the backend service, SQLite/PostgreSQL for result tracking, and Vue.js for user interaction.

```text
┌─────────────────────────────────────────────────────────────┐
│                    User Browser (Port 3000)                 │
│                      Vue.js 3 Web UI                        │
├─────────────────────────────────────────────────────────────┤
│            FastAPI Backend (Port 8000)                      │
├─────────────────────────────────────────────────────────────┤
│    Nextflow Pipeline Orchestration (Data Processing)        │
│  ┌──────────────────────────────────────────────────┐      │
│  │ Annotation → Plasmid → IS → Integrons → AMR ... │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## ⚡ Quick Start

### 1. Run via Docker Compose (Recommended)

The easiest way to run the complete MGE-Sift stack (Web UI, API, Database) is using Docker Compose:

```bash
# Clone the repository
git clone https://github.com/MGE_VetgenomeHub/MGE_Bio.git
cd MGE-Sift

# Start all services
docker-compose up -d

# Wait a few seconds for the services to boot up
```

- **Web UI**: [http://localhost:3000](http://localhost:3000)
- **API**: [http://localhost:8000](http://localhost:8000)
- **API Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)

### 2. Manual Development Setup

If you wish to run the pipeline manually or develop locally:

```bash
# Setup Conda environment
conda env create -f environment.yml
conda activate mge_pipeline

# Install database dependencies
bash scripts/install_dbs.sh ./databases

# Run the Nextflow pipeline directly
nextflow run nextflow/production.nf --input genomes/ --outdir results/
```

## 📊 MGE Classification Logic

- **IS Elements**: Scored based on intact transposases, flanking TSDs, and copies to classify as ACQUIRED (active/mobilized) or INTRINSIC (immobilized).
- **Integrons**: Complete integrons with cassettes are ACQUIRED; CALIN-type are INTRINSIC.
- **Prophages**: High GC deviation + lytic genes = ACQUIRED; GC near host mean + remnants = INTRINSIC.
- **Genomic Islands**: GC deviation > 5% + tRNA flanking = ACQUIRED.

## 📚 Documentation

For more detailed information, please refer to the following guides:
- [Production Guide](PRODUCTION_GUIDE.md): Comprehensive deployment and architecture documentation.
- [Web UI Integration](WEB_UI_SUMMARY.md) & [Web Quickref](WEB_QUICKREF.md): Web interface setup and features.
- [Integration Guide](INTEGRATION_GUIDE.md): Backend and frontend integration details.
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md): Development features and tools incorporated in v2.0.

## 🧪 Testing

The pipeline comes with a comprehensive testing suite.
```bash
# Unit and Integration Tests
pytest tests/test_pipeline.py
bash tests/integration_tests.sh

# Complete Validation Script
bash validate_production.sh
```

## 📝 License & Citation

**MGE Detection Pipeline v2.0.0**  
Multi-element MGE detection and classification system  
[https://github.com/MGE_VetgenomeHub/MGE_Bio](https://github.com/MGE_VetgenomeHub/MGE_Bio)

If you use this pipeline in your research, please ensure you also cite the constituent tools used in the analysis (Prokka/Bakta, MOB-suite, ISEScan, etc.).
