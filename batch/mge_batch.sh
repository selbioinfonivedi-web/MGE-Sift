#!/bin/bash
# MGE Detection Pipeline - Batch Processing
# Usage: ./mge_batch.sh <assembly_dir> [config_file] [--parallel N]

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PIPELINE_HOME="$( cd "$SCRIPT_DIR/.." && pwd )"

# Input validation
if [ $# -lt 1 ]; then
  echo "Usage: $0 <assembly_dir> [config_file] [--parallel N]"
  echo ""
  echo "Arguments:"
  echo "  assembly_dir      - Directory containing FASTA files"
  echo "  config_file       - Optional config file (default: config/mge_pipeline.cfg)"
  echo "  --parallel N      - Run N samples in parallel (default: 1)"
  echo ""
  echo "Example:"
  echo "  $0 ./genomes config/mge_pipeline.cfg --parallel 4"
  exit 1
fi

ASSEMBLY_DIR="$1"
CONFIG_FILE="${2:=$PIPELINE_HOME/config/mge_pipeline.cfg}"
PARALLEL=1

# Parse optional --parallel flag
if [ $# -ge 3 ] && [ "$3" = "--parallel" ]; then
  PARALLEL="${4:=1}"
fi

source "$CONFIG_FILE"
source "$PIPELINE_HOME/lib/common_functions.sh"
source "$PIPELINE_HOME/lib/error_handling.sh"

# Validate input directory
if [ ! -d "$ASSEMBLY_DIR" ]; then
  die "Assembly directory not found: $ASSEMBLY_DIR"
fi

# Find all FASTA files
FASTA_FILES=$(find "$ASSEMBLY_DIR" -maxdepth 1 \( -name "*.fa" -o -name "*.fasta" -o -name "*.fna" -o -name "*.fa.gz" -o -name "*.fasta.gz" \))
FILE_COUNT=$(echo "$FASTA_FILES" | wc -w)

if [ "$FILE_COUNT" -eq 0 ]; then
  die "No FASTA files found in $ASSEMBLY_DIR"
fi

# Setup directories
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$PIPELINE_HOME/${LOG_DIR:=./logs}"
BATCH_LOG="$LOG_DIR/batch_${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

log_header "MGE Detection Pipeline - Batch Processing" | tee -a "$BATCH_LOG"
log_info "Assembly directory: $ASSEMBLY_DIR" | tee -a "$BATCH_LOG"
log_info "Number of samples: $FILE_COUNT" | tee -a "$BATCH_LOG"
log_info "Parallel workers: $PARALLEL" | tee -a "$BATCH_LOG"
log_info "Master log: $BATCH_LOG" | tee -a "$BATCH_LOG"

# Process samples
SINGLE_SCRIPT="$PIPELINE_HOME/single/mge_single.sh"
PROCESSED=0
FAILED=0
FAILED_SAMPLES=()

process_sample() {
  local fasta=$1
  local config=$2
  
  # Extract sample name (without extension)
  local sample_name=$(basename "$fasta" | sed 's/\.[^.]*$//' | sed 's/\.[^.]*$//')
  
  log_info "Processing: $sample_name" | tee -a "$BATCH_LOG"
  
  if bash "$SINGLE_SCRIPT" "$fasta" "$sample_name" "$config" >> "$BATCH_LOG" 2>&1; then
    log_success "Completed: $sample_name" | tee -a "$BATCH_LOG"
    return 0
  else
    log_error "Failed: $sample_name" | tee -a "$BATCH_LOG"
    return 1
  fi
}

export -f process_sample log_info log_success log_error
export SINGLE_SCRIPT BATCH_LOG CONFIG_FILE PIPELINE_HOME LOG_DIR

# Run samples (sequential or parallel)
if [ "$PARALLEL" -eq 1 ]; then
  # Sequential processing
  log_info "Running in sequential mode..." | tee -a "$BATCH_LOG"
  
  while IFS= read -r fasta; do
    if process_sample "$fasta" "$CONFIG_FILE"; then
      ((PROCESSED++)) || true
    else
      ((FAILED++)) || true
      FAILED_SAMPLES+=("$fasta")
    fi
  done <<< "$FASTA_FILES"
else
  # Parallel processing
  log_info "Running in parallel mode ($PARALLEL workers)..." | tee -a "$BATCH_LOG"
  
  export -f process_sample
  echo "$FASTA_FILES" | \
    parallel --jobs "$PARALLEL" --line-buffer --halt soon,fail=1 \
      process_sample {} "$CONFIG_FILE" || true
  
  PROCESSED=$(find "$PIPELINE_HOME/results" -maxdepth 1 -type d | wc -l)
fi

# Generate batch summary
log_header "Batch Processing Summary" | tee -a "$BATCH_LOG"
log_info "Total samples processed: $PROCESSED" | tee -a "$BATCH_LOG"
log_info "Failed samples: $FAILED" | tee -a "$BATCH_LOG"

if [ $FAILED -gt 0 ]; then
  log_warn "Failed samples:" | tee -a "$BATCH_LOG"
  for sample in "${FAILED_SAMPLES[@]}"; do
    log_warn "  - $sample" | tee -a "$BATCH_LOG"
  done
fi

# Generate cohort summary report
log_info "Generating cohort summary..." | tee -a "$BATCH_LOG"
python3 "$PIPELINE_HOME/modules/cohort_summary.py" \
  --results_dir "$PIPELINE_HOME/results" \
  --output_prefix "cohort_$TIMESTAMP" \
  2>&1 | tee -a "$BATCH_LOG" || log_warn "Cohort summary generation had issues"

log_success "Batch processing complete!" | tee -a "$BATCH_LOG"
log_info "Logs: $BATCH_LOG" | tee -a "$BATCH_LOG"
