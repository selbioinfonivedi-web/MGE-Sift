# MGE-Sift

**MGE-Sift** (Mobile Genetic Element Sift) is a comprehensive, high-throughput bioinformatics pipeline and web dashboard designed to automatically detect, parse, and visualize Mobile Genetic Elements (MGEs) and Antimicrobial Resistance (AMR) genes in bacterial genomes.

## 🧬 Features

- **Automated Detection Pipeline**: Leverages Nextflow to orchestrate leading bioinformatics tools in parallel.
  - **Plasmids**: MOB-suite
  - **Prophages**: PhiSpy
  - **Integrons**: IntegronFinder 2.0
  - **IS Elements**: ISEScan
  - **Genomic Islands**: IslandPath
  - **AMR Genes**: ABRicate
- **Smart Classification**: Automatically determines whether AMR genes are **Intrinsic** (chromosomal) or **Acquired** (overlapping with a detected Mobile Genetic Element).
- **Interactive Scientific Visualization**: Fully integrated with the Broad Institute's **IGV.js** (Integrative Genomics Viewer) to provide an interactive, zoomed-in, stacked-track linear genome browser directly in the dashboard.
- **Full-Stack Dockerized Architecture**: Completely containerized for instant, reproducible deployments.

## 🏗️ Architecture

The application is split into several microservices coordinated via `docker-compose`:

- **Frontend (`/frontend`)**: A sleek, reactive dashboard built with **Vue 3**, **Tailwind CSS**, and **Vite**. It features an IGV.js genome viewer and a dynamic data table with pagination.
- **Backend API (`/backend`)**: A fast, asynchronous REST API built with **FastAPI**. It handles genome uploads, serves dynamic FASTA/BED files for IGV, and queries the database.
- **Message Broker & Workers (`/backend/worker`)**: **Redis** and **Celery** handle asynchronous job queueing, ensuring the heavy Nextflow pipelines run reliably in the background without blocking the UI.
- **Database**: **PostgreSQL** stores analysis jobs, parsed MGE coordinates, evidence scores, and classifications.
- **Bioinformatics Pipeline (`/workflows`)**: A **Nextflow** pipeline that utilizes Conda/Bioconda to provision dependencies and run the bioinformatics software.

## 🚀 Quick Start

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Running Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/YourUsername/MGE-Sift.git
   cd MGE-Sift
   ```

2. **Spin up the entire stack**:
   ```bash
   docker-compose up --build
   ```
   *(Note: The initial build may take some time as it installs Python packages, Node modules, and prepares the bioinformatics environment.)*

3. **Access the Application**:
   - **Frontend Dashboard**: Open your browser to `http://localhost:5173`
   - **Backend API Docs (Swagger)**: `http://localhost:8000/docs`

## 🧪 Usage

1. Navigate to the **Upload** page on the frontend.
2. Upload your assembled bacterial genome (`.fasta` or `.consensus.fa`).
3. The system will return a **Job ID** and queue the pipeline in the background.
4. Navigate to the **Queue** page to monitor the live status of your job.
5. Once marked as `COMPLETED`, open the **Dashboard**, enter your Job ID, and click Fetch to explore the interactive IGV genome track and tabular results.

## 🛠️ Built With

- [Nextflow](https://www.nextflow.io/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Vue.js](https://vuejs.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [IGV.js](https://github.com/igvteam/igv.js)
- [Celery](https://docs.celeryq.dev/) & [Redis](https://redis.io/)
- [PostgreSQL](https://www.postgresql.org/)
