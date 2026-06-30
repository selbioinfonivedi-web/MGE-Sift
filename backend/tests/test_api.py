import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "mge-sift-api"}

def test_upload_missing_file():
    response = client.post("/upload")
    assert response.status_code == 422 # Unprocessable Entity (missing file)
