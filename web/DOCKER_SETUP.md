# MGE-Sift Web UI Docker Compose Integration
# This file shows how to integrate the web frontend with existing services

# Add this service to docker-compose.yml under the services section:

# web:
#   build:
#     context: ./web
#     dockerfile: Dockerfile
#   image: mge-sift-web:2.0.0
#   container_name: mge-web
#   ports:
#     - "3000:3000"
#   environment:
#     - VITE_API_URL=http://api:8000
#   depends_on:
#     - api
#   networks:
#     - mge-network
#   restart: unless-stopped
#   healthcheck:
#     test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000"]
#     interval: 30s
#     timeout: 10s
#     retries: 3

# Access the web UI at: http://localhost:3000
