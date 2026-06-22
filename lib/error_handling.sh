#!/bin/bash
# MGE Pipeline - Error Handling
# Centralized error handling and recovery mechanisms

# ============================================================================
# ERROR FUNCTIONS
# ============================================================================

die() {
  local msg="$1"
  log_error "$msg"
  cleanup_on_error
  exit 1
}

warn_and_continue() {
  local msg="$1"
  log_warn "$msg - continuing with caution"
}

assert_file_exists() {
  local file=$1
  local msg="${2:=File not found}"
  
  if [ ! -f "$file" ]; then
    die "$msg: $file"
  fi
}

assert_dir_exists() {
  local dir=$1
  local msg="${2:=Directory not found}"
  
  if [ ! -d "$dir" ]; then
    die "$msg: $dir"
  fi
}

assert_tools_exist() {
  local missing=0
  for tool in "$@"; do
    if ! command -v "$tool" &> /dev/null; then
      log_error "Required tool not found: $tool"
      ((missing++)) || true
    fi
  done
  
  if [ $missing -gt 0 ]; then
    die "$missing required tools are missing. Install conda environment first."
  fi
}

# ============================================================================
# ERROR RECOVERY
# ============================================================================

cleanup_on_error() {
  log_warn "Cleaning up after error..."
  
  # Kill any background processes
  jobs -p | xargs -r kill 2>/dev/null || true
  
  # Optional: Remove incomplete outputs
  if [ "${CLEANUP_INTERMEDIATE:=0}" -eq 1 ]; then
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
      rm -rf "$TEMP_DIR"
      log_info "Removed temporary directory: $TEMP_DIR"
    fi
  fi
}

trap cleanup_on_error ERR EXIT INT TERM

# ============================================================================
# VALIDATION WRAPPERS
# ============================================================================

run_command_safe() {
  local cmd="$1"
  local error_msg="${2:=Command failed}"
  
  if ! eval "$cmd"; then
    die "$error_msg: $cmd"
  fi
}

check_command_exists() {
  local cmd=$1
  
  if ! command -v "$cmd" &> /dev/null; then
    die "Command not found: $cmd"
  fi
}

# ============================================================================
# RETRY LOGIC
# ============================================================================

retry_command() {
  local max_attempts=3
  local delay=5
  local cmd="$1"
  
  for attempt in $(seq 1 $max_attempts); do
    log_info "Attempt $attempt/$max_attempts: $cmd"
    
    if eval "$cmd"; then
      log_success "Command succeeded"
      return 0
    fi
    
    if [ $attempt -lt $max_attempts ]; then
      log_warn "Command failed, retrying in ${delay}s..."
      sleep $delay
    fi
  done
  
  die "Command failed after $max_attempts attempts: $cmd"
}

# ============================================================================
# VALIDATION CHECKSUMS
# ============================================================================

validate_checksum() {
  local file=$1
  local expected_checksum=$2
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  local actual_checksum=$(md5sum "$file" | awk '{print $1}')
  
  if [ "$actual_checksum" != "$expected_checksum" ]; then
    log_error "Checksum mismatch for $file"
    return 1
  fi
  
  return 0
}

# ============================================================================
# OUTPUT VALIDATION
# ============================================================================

assert_output_not_empty() {
  local file=$1
  
  if [ ! -f "$file" ]; then
    die "Output file not created: $file"
  fi
  
  if [ ! -s "$file" ]; then
    die "Output file is empty: $file"
  fi
}

validate_tsv() {
  local file=$1
  local min_columns="${2:=1}"
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  # Check first line (header)
  local header_cols=$(head -1 "$file" | awk -F'\t' '{print NF}')
  if [ "$header_cols" -lt "$min_columns" ]; then
    log_warn "TSV has fewer columns than expected: $header_cols < $min_columns"
    return 1
  fi
  
  return 0
}

validate_bed() {
  local file=$1
  
  if [ ! -f "$file" ]; then
    return 1
  fi
  
  # Check BED format (at least 3 columns)
  if ! awk 'NR==1 {if (NF < 3) exit 1}' "$file"; then
    log_error "Invalid BED file format: $file"
    return 1
  fi
  
  return 0
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

check_conda_env() {
  local env_name=$1
  
  if ! conda env list | grep -q "^$env_name "; then
    die "Conda environment not found: $env_name"
  fi
  
  log_success "Conda environment verified: $env_name"
}

activate_conda_env() {
  local env_name=$1
  
  if [ -z "$CONDA_PREFIX" ]; then
    die "Conda not initialized"
  fi
  
  # Source conda functions
  if [ -f "$CONDA_PREFIX/etc/profile.d/conda.sh" ]; then
    source "$CONDA_PREFIX/etc/profile.d/conda.sh"
  fi
  
  conda activate "$env_name" 2>/dev/null || die "Failed to activate conda environment: $env_name"
  log_success "Activated conda environment: $env_name"
}

# ============================================================================
# LOGGING CONTEXT
# ============================================================================

log_command_execution() {
  local cmd="$1"
  local output_file="$2"
  
  log_debug "Executing: $cmd"
  
  if eval "$cmd" > "$output_file" 2>&1; then
    log_success "Command completed: $(basename ${cmd%% *})"
    return 0
  else
    log_error "Command failed: $cmd"
    log_error "Output: $(tail -5 $output_file)"
    return 1
  fi
}

# ============================================================================
# EXCEPTION HANDLING
# ============================================================================

handle_missing_dependency() {
  local dep=$1
  local install_cmd=$2
  
  log_error "Missing dependency: $dep"
  log_info "Install with: $install_cmd"
  die "Cannot proceed without: $dep"
}

# ============================================================================
# TIMEOUT HANDLING
# ============================================================================

run_with_timeout() {
  local timeout_sec=$1
  shift
  local cmd="$@"
  
  log_info "Running command with ${timeout_sec}s timeout: $cmd"
  
  if timeout "$timeout_sec" bash -c "$cmd"; then
    return 0
  else
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      log_error "Command timed out after ${timeout_sec}s: $cmd"
    fi
    return $exit_code
  fi
}
