from fastapi import APIRouter
from api.endpoints import analysis, upload, results

api_router = APIRouter()
api_router.include_router(analysis.router, prefix="/analysis", tags=["analysis"])
api_router.include_router(upload.router, prefix="/upload", tags=["upload"])
api_router.include_router(results.router, prefix="/results", tags=["results"])
