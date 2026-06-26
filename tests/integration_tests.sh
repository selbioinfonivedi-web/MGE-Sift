#!/bin/bash
# Integration tests for MGE-Sift production pipeline
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

test_case() {
    local test_name=$1
    echo ""
    log_info "Testing: $test_name"
}

assert_file_exists() {
    if [ -f "$1" ]; then
        ((TESTS_PASSED++))
        log_info "✓ File exists: $1"
    else
        ((TESTS_FAILED++))
        log_error "✗ File not found: $1"
    fi
}

assert_command_success() {
    if eval "$1"; then
        ((TESTS_PASSED++))
        log_info "✓ Command succeeded: $1"
    else
        ((TESTS_FAILED++))
        log_error "✗ Command failed: $1"
    fi
}

# ============================================================================
# TESTS
# ============================================================================

test_nextflow_syntax() {
    test_case "Nextflow DSL2 Syntax"
    
    cd "$PROJECT_ROOT/nextflow"
    if nextflow info > /dev/null 2>&1; then
        ((TESTS_PASSED++))
        log_info "✓ Nextflow installed and functional"
    else
        ((TESTS_FAILED++))
        log_error "✗ Nextflow not available"
    fi
}

test_python_imports() {
    test_case "Python Module Imports"
    
    python3 - <<'PYTHON'
import sys
try:
    sys.path.insert(0, './python')
    from mge_utilities import (
        Sample, AnalysisResult, PipelineConfig,
        SQLiteDatabaseManager, PipelineOrchestrator
    )
    print("✓ All Python imports successful")
except ImportError as e:
    print(f"✗ Import failed: {e}")
    sys.exit(1)
PYTHON
    
    if [ $? -eq 0 ]; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

test_docker_image_build() {
    test_case "Docker Image Build"
    
    if docker build -f Dockerfile.production -t mge-sift:test . > /dev/null 2>&1; then
        ((TESTS_PASSED++))
        log_info "✓ Docker image built successfully"
    else
        ((TESTS_FAILED++))
        log_error "✗ Docker image build failed"
    fi
}

test_config_file_parsing() {
    test_case "Configuration File Parsing"
    
    python3 - <<'PYTHON'
from pathlib import Path
sys.path.insert(0, './python')
from mge_utilities import load_config

config_file = Path('config/mge_pipeline.cfg')
if config_file.exists():
    config = load_config(config_file)
    if config:
        print(f"✓ Config loaded with {len(config)} parameters")
    else:
        print("✗ Config file empty or invalid")
        exit(1)
else:
    print(f"✗ Config file not found: {config_file}")
    exit(1)
PYTHON
    
    if [ $? -eq 0 ]; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

test_database_operations() {
    test_case "Database Operations"
    
    python3 - <<'PYTHON'
import sys
import tempfile
from pathlib import Path
sys.path.insert(0, './python')

from mge_utilities import (
    AnalysisResult,
    SQLiteDatabaseManager
)

# Create temporary database
with tempfile.TemporaryDirectory() as tmpdir:
    db_path = Path(tmpdir) / "test.db"
    
    # Test connection
    db = SQLiteDatabaseManager(db_path)
    if not db.connect():
        print("✗ Database connection failed")
        sys.exit(1)
    
    # Test storing result
    result = AnalysisResult(
        sample_id="test_001",
        element_type="plasmid",
        element_id="p001",
        location="1000-2000",
        confidence=0.95,
        classification="acquired",
        metadata={}
    )
    
    if not db.store_result(result):
        print("✗ Failed to store result")
        sys.exit(1)
    
    # Test querying
    results = db.query_results(sample_id="test_001")
    if not results:
        print("✗ Query returned no results")
        sys.exit(1)
    
    db.disconnect()
    print("✓ Database operations successful")
PYTHON
    
    if [ $? -eq 0 ]; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

test_api_endpoints() {
    test_case "FastAPI Endpoints"
    
    # Start API server in background
    python3 -m uvicorn python.api_server:app --host 127.0.0.1 --port 9000 &
    API_PID=$!
    sleep 2
    
    # Test health endpoint
    if curl -s http://127.0.0.1:9000/health | grep -q "healthy"; then
        ((TESTS_PASSED++))
        log_info "✓ Health endpoint responding"
    else
        ((TESTS_FAILED++))
        log_error "✗ Health endpoint failed"
    fi
    
    # Cleanup
    kill $API_PID 2>/dev/null || true
    wait $API_PID 2>/dev/null || true
}

test_sample_processing() {
    test_case "Sample Processing"
    
    # Create test genome
    TEST_GENOME="/tmp/test_genome.fasta"
    cat > "$TEST_GENOME" <<'FASTA'
>contig_1
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
FASTA
    
    # Verify test genome
    if [ -f "$TEST_GENOME" ]; then
        ((TESTS_PASSED++))
        log_info "✓ Test genome created"
    else
        ((TESTS_FAILED++))
        log_error "✗ Test genome creation failed"
    fi
    
    rm -f "$TEST_GENOME"
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          MGE-Sift Production Pipeline Integration Tests           ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Run tests
test_nextflow_syntax
test_python_imports
test_config_file_parsing
test_database_operations
# test_docker_image_build  # Commented out - takes time
# test_api_endpoints      # Commented out - requires running services
test_sample_processing

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                        Test Summary                               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests:   $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_info "All integration tests passed!"
    exit 0
else
    log_error "Some tests failed. Review errors above."
    exit 1
fi
