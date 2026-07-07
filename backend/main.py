from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.config import settings
from api.router import api_router
from db.session import engine
from db.models import Base

# Initialize Database schemas and indexes
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    description="Production-ready REST API for MGE-Sift VetGenome Hub Integration"
)

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

import redis
from sqlalchemy.sql import text

@app.get("/health", tags=["health"])
async def health_check():
    health_status = {"status": "ok", "version": settings.VERSION}
    
    # Check PostgreSQL
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        health_status["database"] = "ok"
    except Exception as e:
        health_status["database"] = "failed"
        health_status["status"] = "degraded"
        
    # Check Redis
    try:
        import os
        redis_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")
        r = redis.from_url(redis_url)
        r.ping()
        health_status["redis"] = "ok"
    except Exception as e:
        health_status["redis"] = "failed"
        health_status["status"] = "degraded"
        
    return health_status
