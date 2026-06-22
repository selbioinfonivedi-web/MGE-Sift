#!/bin/bash
# MGE Pipeline Validation and Testing Framework

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PIPELINE_HOME="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=0
QUICK_MODE=0
FULL_MODE=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --quick) QUICK_MODE=1; shift ;;
    --full) FULL_MODE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo "  $1"; }

# ============================================================================
# VALIDATION TESTS
# ============================================================================

echo "=== MGE Pipeline Validation Suite ==="
echo ""

PASS=0
FAIL=0
WARN=0

# Test 1: Directory structure
echo "[1/15] Checking directory structure..."
for dir in single batch config modules lib scripts tests; do
  if [ -d "$PIPELINE_HOME/$dir" ]; then
    log_pass "Directory: $dir"
    ((PASS++)) || true
  else
    log_fail "Missing directory: $dir"
    ((FAIL++)) || true
  fi
done

# Test 2: Essential scripts exist
echo ""
echo "[2/15] Checking essential scripts..."
for script in single/mge_single.sh batch/mge_batch.sh scripts/install_dbs.sh; do
  if [ -f "$PIPELINE_HOME/$script" ]; then
    log_pass "Script: $script"
    ((PASS++)) || true
  else
    log_fail "Missing script: $script"
    ((FAIL++)) || true
  fi
done

# Test 3: Configuration file
echo ""
echo "[3/15] Checking configuration..."
if [ -f "$PIPELINE_HOME/config/mge_pipeline.cfg" ]; then
  log_pass "Configuration file found"
  ((PASS++)) || true
  
  # Check key parameters
  for param in ANNOTATION_TOOL MOB_DB GC_THRESHOLD_ACQUIRED IS_THRESHOLD_ACQUIRED; do
    if grep -q "^$param=" "$PIPELINE_HOME/config/mge_pipeline.cfg"; then
      log_info "  ✓ $param configured"
    else
      log_warn "  ! $param not configured"
      ((WARN++)) || true
    fi
  done
else
  log_fail "Configuration file not found"
  ((FAIL++)) || true
fi

# Test 4: Module scripts
echo ""
echo "[4/15] Checking detection modules..."
for i in {01..10}; do
  if [ -i -lt 10 ]; then
    module="${i}_*.sh"
  else
    module="${i}_integration.py"
  fi
  
  found=$(find "$PIPELINE_HOME/modules" -name "$module" | wc -l)
  if [ $found -gt 0 ]; then
    log_pass "Module $i present"
    ((PASS++)) || true
  else
    log_warn "Module $i not found (might be OK if not all installed)"
    ((WARN++)) || true
  fi
done

# Test 5: Library functions
echo ""
echo "[5/15] Checking library functions..."
if [ -f "$PIPELINE_HOME/lib/common_functions.sh" ]; then
  # Check key functions
  for func in log_info log_success log_error check_tool; do
    if grep -q "^$func()" "$PIPELINE_HOME/lib/common_functions.sh"; then
      log_pass "Function: $func"
      ((PASS++)) || true
    else
      log_fail "Function not found: $func"
      ((FAIL++)) || true
    fi
  done
else
  log_fail "common_functions.sh not found"
  ((FAIL++)) || true
fi

# Test 6: Error handling
echo ""
echo "[6/15] Checking error handling..."
if [ -f "$PIPELINE_HOME/lib/error_handling.sh" ]; then
  for func in die warn_and_continue check_output; do
    if grep -q "^$func()" "$PIPELINE_HOME/lib/error_handling.sh"; then
      log_pass "Error handler: $func"
      ((PASS++)) || true
    fi
  done
else
  log_warn "error_handling.sh not found"
  ((WARN++)) || true
fi

# Test 7: Script permissions
echo ""
echo "[7/15] Checking script permissions..."
for script in "$PIPELINE_HOME/single/mge_single.sh" \
              "$PIPELINE_HOME/batch/mge_batch.sh" \
              "$PIPELINE_HOME/scripts/install_dbs.sh"; do
  if [ -x "$script" ]; then
    log_pass "Executable: $(basename $script)"
    ((PASS++)) || true
  else
    log_warn "Not executable: $(basename $script)"
    log_info "  Run: chmod +x $script"
    ((WARN++)) || true
  fi
done

# Test 8: Documentation
echo ""
echo "[8/15] Checking documentation..."
if [ -f "$PIPELINE_HOME/README.md" ]; then
  lines=$(wc -l < "$PIPELINE_HOME/README.md")
  if [ $lines -gt 100 ]; then
    log_pass "README.md present ($lines lines)"
    ((PASS++)) || true
  else
    log_warn "README.md too short"
    ((WARN++)) || true
  fi
else
  log_fail "README.md not found"
  ((FAIL++)) || true
fi

# Test 9: Environment file
echo ""
echo "[9/15] Checking environment specification..."
if [ -f "$PIPELINE_HOME/environment.yml" ]; then
  packages=$(grep -c "^  -" "$PIPELINE_HOME/environment.yml")
  log_pass "environment.yml with $packages packages"
  ((PASS++)) || true
else
  log_fail "environment.yml not found"
  ((FAIL++)) || true
fi

# Test 10: Quick mode tools check
echo ""
echo "[10/15] Checking tool availability..."
if [ "$QUICK_MODE" -eq 1 ] || [ "$FULL_MODE" -eq 1 ]; then
  tools=("bash" "python3" "awk" "sed")
  
  for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
      log_pass "Tool available: $tool"
      ((PASS++)) || true
    else
      log_fail "Tool not found: $tool"
      ((FAIL++)) || true
    fi
  done
fi

# Test 11: Conda environment (if available)
echo ""
echo "[11/15] Checking conda environment..."
if command -v conda &> /dev/null; then
  if conda env list | grep -q "mge_pipeline"; then
    log_pass "Conda environment 'mge_pipeline' found"
    ((PASS++)) || true
  else
    log_warn "Conda environment 'mge_pipeline' not found"
    log_info "  Run: conda create -f environment.yml"
    ((WARN++)) || true
  fi
else
  log_warn "Conda not installed"
  ((WARN++)) || true
fi

# Test 12: Write permissions
echo ""
echo "[12/15] Checking directory permissions..."
test_dir="$PIPELINE_HOME/results"
mkdir -p "$test_dir"
if touch "$test_dir/.write_test" 2>/dev/null; then
  rm -f "$test_dir/.write_test"
  log_pass "Write permissions OK: $test_dir"
  ((PASS++)) || true
else
  log_fail "Cannot write to: $test_dir"
  ((FAIL++)) || true
fi

# Test 13: Python dependencies (for 10_integration.py)
echo ""
echo "[13/15] Checking Python dependencies..."
python3 -c "import pandas" 2>/dev/null && {
  log_pass "Python: pandas"
  ((PASS++)) || true
} || {
  log_warn "Python: pandas not installed"
  ((WARN++)) || true
}

# Test 14: Output structure
echo ""
echo "[14/15] Checking output structure..."
for dir in 01_annotation 02_plasmid 03_IS_elements 04_integrons 05_prophage \
           06_genomic_islands 07_repeats 08_HGT 09_AMR 10_integration; do
  # These should be created by pipeline, just verify path structure is OK
  path="$PIPELINE_HOME/results/test/$dir"
  if mkdir -p "$path" 2>/dev/null; then
    log_pass "Path structure OK: $dir"
    ((PASS++)) || true
    rm -rf "$PIPELINE_HOME/results/test"
  fi
done

# Test 15: Syntax validation
echo ""
echo "[15/15] Validating script syntax..."
for script in "$PIPELINE_HOME/single/mge_single.sh" \
              "$PIPELINE_HOME/batch/mge_batch.sh"; do
  if bash -n "$script" 2>/dev/null; then
    log_pass "Syntax OK: $(basename $script)"
    ((PASS++)) || true
  else
    log_fail "Syntax error: $(basename $script)"
    ((FAIL++)) || true
  fi
done

# Summary
echo ""
echo "=== Validation Summary ==="
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}✓ Pipeline structure is valid${NC}"
  exit 0
else
  echo -e "${RED}✗ Pipeline has $FAIL issues to fix${NC}"
  exit 1
fi
