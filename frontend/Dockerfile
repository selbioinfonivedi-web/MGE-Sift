# Frontend Dockerfile for Development
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Expose port for Vite development server
EXPOSE 3000

# We mount the source code dynamically in docker-compose.
# The startup command installs dependencies and starts the dev server.
CMD ["sh", "-c", "npm install && npm run dev"]
