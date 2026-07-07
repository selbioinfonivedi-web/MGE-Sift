import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    # Ensure our Phase 4 DB/Redis health checks are running (even if they fail in the mock CI environment, they should be present)
    assert "database" in data
    assert "redis" in data

def test_upload_missing_file():
    # Attempting to upload without a file to the v1 endpoint
    response = client.post("/api/v1/upload/")
    assert response.status_code == 422 # Unprocessable Entity (missing file)
