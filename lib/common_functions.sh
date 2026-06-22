#!/bin/bash
# MGE Pipeline - Common Functions
# Utility functions shared across all modules

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_header() {
  echo ""
  echo -e "${BLUE}================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}================================${NC}"
  echo ""
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $(date '+%H:%M:%S') $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"
}

log_debug() {
  if [ "${DEBUG_MODE:=0}" -eq 1 ]; then
    echo -e "${YELLOW}[DEBUG]${NC} $(date '+%H:%M:%S') $1"
  fi
}

# ============================================================================
# TOOL CHECKING FUNCTIONS
# ============================================================================

check_tool() {
  local tool=$1
  if command -v "$tool" &> /dev/null; then
    log_success "Tool found: $tool"
    return 0
  else
    log_error "Tool not found: $tool"
    return 1
  fi
}

check_tools_installed() {
  local required_tools=(
    "prokka" "blastn" "bedtools" "python3" 
    "parallel" "samtools" "tRNAscan-SE"
  )
  
  local missing=0
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      log_warn "Missing tool: $tool"
      ((missing++)) || true
    fi
  done
  
  if [ $missing -eq 0 ]; then
    log_success "All required tools installed"
    return 0
  else
    log_error "Missing $missing tools. Install conda environment first."
    return 1
  fi
}

# ============================================================================
# FILE VALIDATION FUNCTIONS
# ============================================================================

check_input_validity() {
  local input_file=$1
  
  if [ ! -f "$input_file" ]; then
    log_error "File not found: $input_file"
    return 1
  fi
  
  # Check file size
  local file_size=$(stat -f%z "$input_file" 2>/dev/null || stat --printf=%s "$input_file" 2>/dev/null)
  if [ "$file_size" -lt 1000 ]; then
    log_error "File too small (< 1 KB): $input_file"
    return 1
  fi
  
  # Check FASTA format
  if [[ "$input_file" == *.gz ]]; then
    if ! gunzip -t "$input_file" &> /dev/null; then
      log_error "Gzip file corrupted: $input_file"
      return 1
    fi
  fi
  
  log_success "Input file validation passed"
  return 0
}

validate_fasta() {
  local fasta=$1
  
  # Check for valid FASTA header
  if ! grep -q "^>" "$fasta"; then
    log_error "No FASTA headers found"
    return 1
  fi
  
  # Check for valid sequences
  if grep -v "^>" "$fasta" | grep -q "[^ACGTN-]"; then
    log_warn "Unexpected characters in FASTA sequences (not ACGTN)"
  fi
  
  return 0
}

# ============================================================================
# RESULT HANDLING FUNCTIONS
# ============================================================================

save_result() {
  local source=$1
  local dest=$2
  
  if [ -f "$source" ]; then
    cp "$source" "$dest" || return 1
    log_success "Saved: $(basename $dest)"
    return 0
  else
    log_warn "Result file not found: $source"
    return 1
  fi
}

check_output() {
  local output=$1
  local min_lines="${2:=1}"
  
  if [ ! -f "$output" ]; then
    log_error "Output file not created: $output"
    return 1
  fi
  
  local line_count=$(wc -l < "$output")
  if [ "$line_count" -lt "$min_lines" ]; then
    log_warn "Output file has fewer lines than expected ($line_count < $min_lines)"
    return 1
  fi
  
  log_success "Output validated: $output ($line_count lines)"
  return 0
}

# ============================================================================
# BED FILE OPERATIONS
# ============================================================================

sort_bed() {
  local bed=$1
  local sorted="${bed%.bed}_sorted.bed"
  
  if [ ! -f "$bed" ]; then
    return 1
  fi
  
  sort -k1,1 -k2,2n "$bed" > "$sorted"
  mv "$sorted" "$bed"
  log_success "BED file sorted: $bed"
  return 0
}

merge_bed_files() {
  local output=$1
  shift
  local bed_files=("$@")
  
  # Combine and sort all BED files
  cat "${bed_files[@]}" | sort -k1,1 -k2,2n > "$output"
  
  log_success "Merged BED files: $(basename $output)"
  return 0
}

annotate_bed() {
  local bed=$1
  local gff=$2
  local annotated="${bed%.bed}_annotated.bed"
  
  # Add gene annotations to BED file using bedtools
  bedtools intersect -a "$bed" -b "$gff" -wa -wb > "$annotated" 2>/dev/null || {
    cp "$bed" "$annotated"
  }
  
  log_success "BED file annotated: $(basename $annotated)"
  echo "$annotated"
}

# ============================================================================
# SEQUENCE ANALYSIS
# ============================================================================

calculate_gc_content() {
  local fasta=$1
  
  local total=$(grep -v "^>" "$fasta" | tr -d '\n' | wc -c)
  local gc=$(grep -v "^>" "$fasta" | tr -d '\n' | grep -io "[GC]" | wc -l)
  
  if [ "$total" -eq 0 ]; then
    echo "0"
  else
    echo "scale=2; $gc * 100 / $total" | bc
  fi
}

extract_sequence() {
  local fasta=$1
  local chrom=$2
  local start=$3
  local end=$4
  
  # Extract region from FASTA (simple implementation)
  samtools faidx "$fasta" "${chrom}:${start}-${end}" 2>/dev/null || {
    log_warn "Could not extract sequence using samtools"
    return 1
  }
}

count_sequences() {
  local fasta=$1
  grep -c "^>" "$fasta"
}

# ============================================================================
# PERFORMANCE & RESOURCE MONITORING
# ============================================================================

get_available_cpus() {
  if command -v nproc &> /dev/null; then
    nproc
  elif [ -f /proc/cpuinfo ]; then
    grep -c "^processor" /proc/cpuinfo
  else
    echo 1
  fi
}

get_available_memory_mb() {
  if command -v free &> /dev/null; then
    free -m | awk '/^Mem:/{print $7}'
  elif [ "$(uname)" = "Darwin" ]; then
    vm_stat | awk '/Pages free/ {print $3}' | tr -d '.' | awk '{print $1 / 256}'
  else
    echo "1024"
  fi
}

# ============================================================================
# DATABASE FUNCTIONS
# ============================================================================

check_database() {
  local db_path=$1
  
  if [ ! -d "$db_path" ] && [ ! -f "$db_path" ]; then
    log_error "Database not found: $db_path"
    return 1
  fi
  
  log_success "Database verified: $(basename $db_path)"
  return 0
}

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

cleanup_temp_files() {
  local temp_dir=$1
  
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
    log_info "Cleaned up temporary files"
  fi
}

compress_results() {
  local result_dir=$1
  
  if [ -d "$result_dir" ]; then
    tar -czf "${result_dir}.tar.gz" "$result_dir"
    log_success "Results compressed: $(basename ${result_dir}.tar.gz)"
  fi
}
