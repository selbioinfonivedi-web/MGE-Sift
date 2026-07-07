# Use official Python runtime as a parent image
FROM python:3.10-slim

# Install system dependencies (needed for psycopg2 and Nextflow)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    default-jre \
    parallel \
    && rm -rf /var/lib/apt/lists/*

# Install Nextflow
RUN curl -s https://get.nextflow.io | bash && \
    mv nextflow /usr/local/bin/

# Install Conda and Nextflow for the celery worker
RUN curl -o Miniconda3.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3.sh -b -p /opt/conda && \
    rm Miniconda3.sh

ENV PATH="$PATH:/opt/conda/bin"

# Accept Conda Terms of Service for automated environments
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

RUN conda install -y -c bioconda nextflow
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source code
COPY . .

# Expose port for FastAPI
EXPOSE 8000

# Command to run FastAPI server (overridden in compose for Celery)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
