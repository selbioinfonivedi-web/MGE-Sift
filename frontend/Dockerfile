# Frontend Dockerfile for Development
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Expose port for Vite development server
EXPOSE 3000

# We mount the source code dynamically in docker-compose.
# The startup command installs dependencies and starts the dev server.
CMD ["sh", "-c", "if [ ! -f package.json ]; then npm create vite@latest temp-app -- --template vue-ts && mv temp-app/* temp-app/.* . 2>/dev/null || true && rm -rf temp-app && npm install && npm install -D tailwindcss postcss autoprefixer && npx tailwindcss init -p; fi; npm install && npm run dev -- --host 0.0.0.0 --port 3000"]
