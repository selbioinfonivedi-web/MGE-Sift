#!/bin/bash
# MGE Detection Pipeline - Single Sample Processing
# Usage: ./mge_single.sh <input_genome.fa> <sample_name> [config_file]

set -euo pipefail

# ============================================================================
# SETUP & VALIDATION
# ============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PIPELINE_HOME="$( cd "$SCRIPT_DIR/.." && pwd )"

# Input validation
if [ $# -lt 2 ]; then
  echo "Usage: $0 <input_genome.fa> <sample_name> [config_file]"
  echo ""
  echo "Arguments:"
  echo "  input_genome.fa   - Input FASTA file (can be gzipped)"
  echo "  sample_name       - Sample identifier (no spaces)"
  echo "  config_file       - Optional config file (default: config/mge_pipeline.cfg)"
  exit 1
fi

INPUT_GENOME="$1"
SAMPLE_NAME="$2"
CONFIG_FILE="${3:=$PIPELINE_HOME/config/mge_pipeline.cfg}"

# Source configuration and utilities
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"
source "$PIPELINE_HOME/lib/common_functions.sh"
source "$PIPELINE_HOME/lib/error_handling.sh"

# Validate input
if [ ! -f "$INPUT_GENOME" ]; then
  die "Input file not found: $INPUT_GENOME"
fi

# Setup environment
export CONDA_PREFIX="$CONDA_PATH/envs/$CONDA_ENV"
export PATH="$CONDA_PREFIX/bin:$PATH"

# Initialize directories and logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$PIPELINE_HOME/${LOG_DIR:=./logs}"
OUTPUT_DIR="$PIPELINE_HOME/${OUTPUT_DIR:=./results}"
mkdir -p "$LOG_DIR" "$OUTPUT_DIR"

LOG_FILE="$LOG_DIR/${SAMPLE_NAME}_${TIMESTAMP}.log"
SAMPLE_OUTPUT_DIR="$OUTPUT_DIR/$SAMPLE_NAME"
mkdir -p "$SAMPLE_OUTPUT_DIR"

# ============================================================================
# MAIN EXECUTION
# ============================================================================

log_header "MGE Detection Pipeline - Single Sample"
log_info "Sample: $SAMPLE_NAME"
log_info "Input: $INPUT_GENOME"
log_info "Output: $SAMPLE_OUTPUT_DIR"
log_info "Log: $LOG_FILE"

# Pre-flight checks
log_info "Performing pre-flight checks..."
check_tools_installed || die "Required tools not installed"
check_input_validity "$INPUT_GENOME" || die "Input validation failed"

# Decompress if needed
GENOME_FA="$SAMPLE_OUTPUT_DIR/${SAMPLE_NAME}_prep.fa"
if [[ "$INPUT_GENOME" == *.gz ]]; then
  log_info "Decompressing input genome..."
  gunzip -c "$INPUT_GENOME" > "$GENOME_FA"
else
  cp "$INPUT_GENOME" "$GENOME_FA"
fi

log_info "Genome size: $(wc -c < "$GENOME_FA") bp"

# ============================================================================
# MODULE 1: ANNOTATION (Prokka/Bakta)
# ============================================================================
log_header "Step 1/10: Genome Annotation"
bash "$PIPELINE_HOME/modules/01_annotation.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Annotation step failed"

# ============================================================================
# MODULE 2: PLASMID DETECTION (MOB-suite + PlasmidFinder)
# ============================================================================
log_header "Step 2/10: Plasmid Detection"
bash "$PIPELINE_HOME/modules/02_plasmid.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Plasmid detection step failed"

# ============================================================================
# MODULE 3: IS ELEMENT DETECTION (ISEScan)
# ============================================================================
log_header "Step 3/10: IS Element Detection"
bash "$PIPELINE_HOME/modules/03_is_elements.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "IS element detection failed"

# ============================================================================
# MODULE 4: INTEGRON DETECTION (IntegronFinder)
# ============================================================================
log_header "Step 4/10: Integron Detection"
bash "$PIPELINE_HOME/modules/04_integrons.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Integron detection failed"

# ============================================================================
# MODULE 5: PROPHAGE DETECTION (PhiSpy + PHASTER)
# ============================================================================
log_header "Step 5/10: Prophage Detection"
bash "$PIPELINE_HOME/modules/05_prophages.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Prophage detection failed"

# ============================================================================
# MODULE 6: GENOMIC ISLAND DETECTION (IslandPath + GC content + tRNA)
# ============================================================================
log_header "Step 6/10: Genomic Island Detection"
bash "$PIPELINE_HOME/modules/06_genomic_islands.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Genomic island detection failed"

# ============================================================================
# MODULE 7: REPEAT DETECTION (TSDs, inverted repeats)
# ============================================================================
log_header "Step 7/10: Repeat Detection"
bash "$PIPELINE_HOME/modules/07_repeats.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Repeat detection failed"

# ============================================================================
# MODULE 8: HGT DETECTION (Alien Hunter, SIGI-HMM, CAI)
# ============================================================================
log_header "Step 8/10: HGT Signal Detection"
bash "$PIPELINE_HOME/modules/08_hgt_signals.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "HGT detection failed"

# ============================================================================
# MODULE 9: AMR DETECTION (RGI, ResFinder, ABRicate)
# ============================================================================
log_header "Step 9/10: Antimicrobial Resistance Detection"
bash "$PIPELINE_HOME/modules/09_amr_detection.sh" \
  "$GENOME_FA" \
  "$SAMPLE_NAME" \
  "$SAMPLE_OUTPUT_DIR" \
  "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "AMR detection failed"

# ============================================================================
# MODULE 10: INTEGRATION & CLASSIFICATION
# ============================================================================
log_header "Step 10/10: Integration & Classification"
python3 "$PIPELINE_HOME/modules/10_integration.py" \
  --sample "$SAMPLE_NAME" \
  --output_dir "$SAMPLE_OUTPUT_DIR" \
  --config "$CONFIG_FILE" \
  2>&1 | tee -a "$LOG_FILE" || die "Integration step failed"

# ============================================================================
# FINAL REPORT
# ============================================================================
log_header "Pipeline Complete"
log_success "All modules completed successfully"
log_info "Final outputs:"
log_info "  - $SAMPLE_OUTPUT_DIR/${SAMPLE_NAME}_all_MGEs.bed"
log_info "  - $SAMPLE_OUTPUT_DIR/${SAMPLE_NAME}_MGE_classification_report.tsv"
log_info "  - $SAMPLE_OUTPUT_DIR/${SAMPLE_NAME}_AMR_in_MGE.tsv"
log_info ""
log_info "Logs: $LOG_FILE"
log_info "Outputs: $SAMPLE_OUTPUT_DIR"

exit 0
