#!/bin/bash
# MGE-Sift Production Validation Script
# Verify all production components are working correctly

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[✓]${NC} $*"
    ((CHECKS_PASSED++))
}

log_fail() {
    echo -e "${RED}[✗]${NC} $*"
    ((CHECKS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

check_tool() {
    if command -v "$1" &> /dev/null; then
        log_pass "$1 installed"
    else
        log_fail "$1 not found"
    fi
}

check_file() {
    if [ -f "$1" ]; then
        log_pass "File exists: $1"
    else
        log_fail "File missing: $1"
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        log_pass "Directory exists: $1"
    else
        log_fail "Directory missing: $1"
    fi
}

# ============================================================================
# VALIDATION CHECKS
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║          MGE-Sift Production Pipeline Validation                   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check System Tools
echo -e "\n${BLUE}=== System Tools ===${NC}"
check_tool "bash"
check_tool "python3"
check_tool "git"
check_tool "docker"
check_tool "nextflow"

# Check Project Structure
echo -e "\n${BLUE}=== Project Structure ===${NC}"
check_dir "$PROJECT_ROOT/nextflow"
check_dir "$PROJECT_ROOT/python"
check_dir "$PROJECT_ROOT/tests"
check_dir "$PROJECT_ROOT/infrastructure"
check_file "$PROJECT_ROOT/environment.yml"
check_file "$PROJECT_ROOT/Dockerfile.production"
check_file "$PROJECT_ROOT/docker-compose.yml"

# Check Configuration Files
echo -e "\n${BLUE}=== Configuration Files ===${NC}"
check_file "$PROJECT_ROOT/nextflow/production.nf"
check_file "$PROJECT_ROOT/config/mge_pipeline.cfg"
check_file "$PROJECT_ROOT/requirements-dev.txt"
check_file "$PROJECT_ROOT/.github/workflows/production.yml"

# Check Python Modules
echo -e "\n${BLUE}=== Python Modules ===${NC}"
python3 - <<'PYTHON'
import sys
import os
sys.path.insert(0, os.path.join(os.getcwd(), 'python'))

modules_to_check = [
    ('mge_utilities', 'Sample, AnalysisResult, PipelineConfig'),
    ('api_server', 'FastAPI, SQLiteDatabaseManager'),
]

for module, exports in modules_to_check:
    try:
        __import__(module)
        print(f"[✓] {module} module loads successfully")
    except Exception as e:
        print(f"[✗] {module} failed: {e}")
PYTHON

# Check Database Setup
echo -e "\n${BLUE}=== Database Setup ===${NC}"
if [ -d "./databases" ]; then
    num_files=$(find ./databases -type f | wc -l)
    if [ $num_files -gt 0 ]; then
        log_pass "Database files present ($num_files files)"
    else
        log_warn "Database directory empty - run: bash scripts/install_dbs.sh ./databases"
    fi
else
    log_warn "Database directory not found - run: bash scripts/install_dbs.sh ./databases"
fi

# Check Nextflow Configuration
echo -e "\n${BLUE}=== Nextflow Configuration ===${NC}"
if nextflow info > /dev/null 2>&1; then
    nextflow_version=$(nextflow -v)
    log_pass "Nextflow is functional: $nextflow_version"
else
    log_fail "Nextflow not functional"
fi

# Check Docker
echo -e "\n${BLUE}=== Docker Configuration ===${NC}"
if docker ps > /dev/null 2>&1; then
    docker_version=$(docker --version)
    log_pass "Docker daemon running: $docker_version"
else
    log_fail "Docker daemon not accessible"
fi

if docker-compose ps > /dev/null 2>&1; then
    log_pass "Docker Compose is functional"
else
    log_warn "Docker Compose not available"
fi

# Check Conda Environment
echo -e "\n${BLUE}=== Conda Environment ===${NC}"
if [ ! -z "${CONDA_PREFIX:-}" ]; then
    log_pass "Conda environment active: $CONDA_PREFIX"
    
    # Check key packages
    python3 -c "import nextflow" 2>/dev/null && log_pass "Nextflow Python support available" || log_warn "Nextflow Python support not available"
    python3 -c "import fastapi" 2>/dev/null && log_pass "FastAPI installed" || log_fail "FastAPI not installed"
    python3 -c "import pytest" 2>/dev/null && log_pass "Pytest installed" || log_warn "Pytest not installed"
else
    log_fail "No Conda environment active"
fi

# Check Git Configuration
echo -e "\n${BLUE}=== Git Configuration ===${NC}"
if git rev-parse --git-dir > /dev/null 2>&1; then
    log_pass "Git repository initialized"
    
    git_status=$(git status --porcelain)
    if [ -z "$git_status" ]; then
        log_pass "Working directory clean"
    else
        log_warn "Uncommitted changes present"
    fi
else
    log_fail "Not a Git repository"
fi

# Check CI/CD Pipeline
echo -e "\n${BLUE}=== CI/CD Pipeline ===${NC}"
if [ -f "$PROJECT_ROOT/.github/workflows/production.yml" ]; then
    log_pass "GitHub Actions workflow configured"
else
    log_warn "GitHub Actions workflow not found"
fi

# Test Run
echo -e "\n${BLUE}=== Functionality Tests ===${NC}"
log_info "Testing Python module imports..."
python3 - <<'PYTHON'
import sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd() / 'python'))

try:
    from mge_utilities import (
        get_logger, Sample, AnalysisResult, 
        SQLiteDatabaseManager, PipelineOrchestrator
    )
    from api_server import app
    print("[✓] All core modules import successfully")
except ImportError as e:
    print(f"[✗] Import error: {e}")
    sys.exit(1)
PYTHON

# ============================================================================
# SUMMARY
# ============================================================================

TOTAL=$((CHECKS_PASSED + CHECKS_FAILED))

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    Validation Summary                              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "Checks Passed:  ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks Failed:  ${RED}$CHECKS_FAILED${NC}"
echo -e "Total Checks:   $TOTAL"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run tests:           pytest tests/test_pipeline.py -v"
    echo "  2. Integration tests:   bash tests/integration_tests.sh"
    echo "  3. Start development:   python -m uvicorn python.api_server:app --reload"
    echo "  4. Run pipeline:        nextflow run nextflow/production.nf --input genomes/"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review errors above.${NC}"
    echo ""
    echo "Recommended fixes:"
    echo "  - Install missing tools"
    echo "  - Download databases: bash scripts/install_dbs.sh ./databases"
    echo "  - Initialize conda environment: conda env create -f environment.yml"
    echo "  - Check Docker daemon is running"
    echo ""
    exit 1
fi
