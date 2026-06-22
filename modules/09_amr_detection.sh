#!/bin/bash
# Module 09: Antimicrobial Resistance Detection (RGI, ResFinder, ABRicate)
# Identifies AMR genes and their location within MGE elements

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/09_AMR"
mkdir -p "$MODULE_DIR"

log_info "Module 09: Antimicrobial Resistance Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# Get annotation info
ANNOTATION_DIR="$OUTPUT_DIR/01_annotation"
PROTEINS="$ANNOTATION_DIR/${SAMPLE_NAME}.faa"

# ============================================================================
# RGI (CARD) Detection
# ============================================================================
log_info "Running RGI for CARD-based AMR detection..."

RGI_OUTPUT="$MODULE_DIR/rgi_output"
mkdir -p "$RGI_OUTPUT"

if [ -f "$PROTEINS" ]; then
  rgi main \
    --input_sequence "$PROTEINS" \
    --output_file "$RGI_OUTPUT/${SAMPLE_NAME}" \
    --input_type protein \
    --alignment_tool "${RGI_ALIGNMENT:=BLAST}" \
    --coverage "$RGI_COVERAGE" \
    --threshold "$RGI_IDENTITY" \
    --local 2>&1 || log_warn "RGI failed"
else
  log_warn "Protein file not found for RGI"
fi

# Parse RGI results
RGI_BED="$MODULE_DIR/${SAMPLE_NAME}_amr_rgi.bed"
RGI_DETAILED="$MODULE_DIR/${SAMPLE_NAME}_amr_rgi_detailed.tsv"

if [ -f "$RGI_OUTPUT/${SAMPLE_NAME}.txt" ]; then
  {
    echo -e "Contig\tStart\tEnd\tGene\tAMR_Class\tResistance_Type"
    
    tail -n +2 "$RGI_OUTPUT/${SAMPLE_NAME}.txt" 2>/dev/null | \
    awk -F'\t' '{
      # RGI format: ORF_ID, Best_Hit_ARO, Percentage_Identity, etc.
      print $1, "0", "100", $2, $5, $6
    }' OFS='\t'
  } > "$RGI_DETAILED"
  
  tail -n +2 "$RGI_DETAILED" | awk -F'\t' '{print $1"\t"$2"\t"$3"\tRGI_"NR"\t"$5"\t."}' OFS='\t' > "$RGI_BED" || true
else
  > "$RGI_BED"
  > "$RGI_DETAILED"
fi

log_info "RGI detections: $(wc -l < "$RGI_BED" 2>/dev/null || echo 0)"

# ============================================================================
# ABRicate Multi-Database Detection
# ============================================================================
log_info "Running ABRicate for multi-database AMR detection..."

ABRICATE_OUTPUT="$MODULE_DIR/${SAMPLE_NAME}_abricate_full.txt"

abricate \
  --db ncbi \
  "$GENOME_FA" > "$ABRICATE_OUTPUT" 2>&1 || log_warn "ABRicate failed"

# Parse ABRicate output
ABRICATE_BED="$MODULE_DIR/${SAMPLE_NAME}_amr_abricate.bed"
ABRICATE_DETAILED="$MODULE_DIR/${SAMPLE_NAME}_amr_abricate_detailed.tsv"

if [ -s "$ABRICATE_OUTPUT" ]; then
  {
    echo -e "Contig\tStart\tEnd\tGene\tCoverage\tIdentity"
    
    tail -n +2 "$ABRICATE_OUTPUT" 2>/dev/null | \
    awk -F'\t' '{
      # ABRicate format: #FILE, SEQUENCE, START, END, GENE, COVERAGE, COVERAGE_MAP, GAPS, %COVERAGE, %IDENTITY, DATABASE, ACCESSION, PRODUCT, RESISTANCE
      print $3, $4, $5, $6, $9, $10
    }' OFS='\t'
  } > "$ABRICATE_DETAILED"
  
  tail -n +2 "$ABRICATE_DETAILED" | awk -F'\t' '{print $1"\t"$2"\t"$3"\tABR_"NR"\t"$5"\t"$6}' OFS='\t' > "$ABRICATE_BED" || true
else
  > "$ABRICATE_BED"
  > "$ABRICATE_DETAILED"
fi

log_info "ABRicate detections: $(wc -l < "$ABRICATE_BED" 2>/dev/null || echo 0)"

# ============================================================================
# ResFinder Detection
# ============================================================================
log_info "Running ResFinder for resistance gene detection..."

RESFINDER_OUTPUT="$MODULE_DIR/resfinder_output"
mkdir -p "$RESFINDER_OUTPUT"

# ResFinder requires specific database structure
if [ -d "$RESFINDER_DB" ]; then
  blastn \
    -query "$GENOME_FA" \
    -subject "${RESFINDER_DB}/fasta"/*.fsa \
    -evalue 1e-30 \
    -outfmt 6 \
    -num_threads "$ANNOTATION_CPUS" \
    -out "$RESFINDER_OUTPUT/resfinder_blast.txt" 2>&1 || log_warn "ResFinder BLAST failed"
else
  log_warn "ResFinder database not found"
fi

RESFINDER_BED="$MODULE_DIR/${SAMPLE_NAME}_amr_resfinder.bed"

if [ -f "$RESFINDER_OUTPUT/resfinder_blast.txt" ]; then
  awk -F'\t' '{
    print $1"\t"$7-1"\t"$8"\tRF_"$2"\t"$3"\t."
  }' OFS='\t' < "$RESFINDER_OUTPUT/resfinder_blast.txt" > "$RESFINDER_BED" || true
else
  > "$RESFINDER_BED"
fi

log_info "ResFinder detections: $(wc -l < "$RESFINDER_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Merge AMR Predictions
# ============================================================================
log_info "Merging AMR predictions..."

ALL_AMR_BED="$MODULE_DIR/${SAMPLE_NAME}_all_amr.bed"

{
  cat "$RGI_BED" 2>/dev/null || true
  cat "$ABRICATE_BED" 2>/dev/null || true
  cat "$RESFINDER_BED" 2>/dev/null || true
} | sort -k1,1 -k2,2n | uniq > "$ALL_AMR_BED" || true

log_success "Total AMR genes: $(wc -l < "$ALL_AMR_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Classify AMR Gene Types
# ============================================================================
log_info "Classifying resistance mechanisms..."

AMR_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_amr_classification.tsv"

{
  echo -e "AMR_Gene\tClass\tResistance_Type\tMechanism\tDatabase_Source"
  
  if [ -s "$RGI_DETAILED" ]; then
    tail -n +2 "$RGI_DETAILED" | while IFS=$'\t' read -r gene amr_class res_type; do
      # Simple classification
      mechanism="unknown"
      if [[ "$amr_class" =~ "beta-lactam" ]]; then
        mechanism="enzymatic"
      elif [[ "$amr_class" =~ "efflux" ]]; then
        mechanism="efflux_pump"
      fi
      echo -e "$gene\t$amr_class\t$res_type\t$mechanism\tCARD"
    done
  fi
} > "$AMR_CLASSIFICATION"

log_success "AMR classification: $(basename $AMR_CLASSIFICATION)"

# ============================================================================
# Generate AMR Matrix (presence/absence across samples)
# ============================================================================
log_info "Generating AMR summary matrix..."

AMR_MATRIX="$MODULE_DIR/${SAMPLE_NAME}_amr_matrix.tsv"

{
  echo -e "Sample\tTotal_AMR_Genes\tBeta_Lactam_Resistance\tAminoglycoside_Resistance\tFluoroquinolone_Resistance\tMacrolide_Resistance\tOther"
  
  total=$(wc -l < "$ALL_AMR_BED" 2>/dev/null || echo 0)
  beta=$(grep -i "beta" "$AMR_CLASSIFICATION" 2>/dev/null | wc -l || echo 0)
  amino=$(grep -i "aminoglycoside" "$AMR_CLASSIFICATION" 2>/dev/null | wc -l || echo 0)
  fluoro=$(grep -i "fluoroquinolone" "$AMR_CLASSIFICATION" 2>/dev/null | wc -l || echo 0)
  macro=$(grep -i "macrolide" "$AMR_CLASSIFICATION" 2>/dev/null | wc -l || echo 0)
  other=$((total - beta - amino - fluoro - macro))
  
  echo -e "$SAMPLE_NAME\t$total\t$beta\t$amino\t$fluoro\t$macro\t$other"
} > "$AMR_MATRIX"

log_success "AMR matrix: $(basename $AMR_MATRIX)"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

AMR_STATS="$MODULE_DIR/${SAMPLE_NAME}_amr_stats.txt"

{
  echo "=== AMR Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "RGI (CARD) genes: $(wc -l < "$RGI_BED" 2>/dev/null || echo 0)"
  echo "ABRicate (NCBI) genes: $(wc -l < "$ABRICATE_BED" 2>/dev/null || echo 0)"
  echo "ResFinder genes: $(wc -l < "$RESFINDER_BED" 2>/dev/null || echo 0)"
  echo "Total unique AMR genes: $(wc -l < "$ALL_AMR_BED" 2>/dev/null || echo 0)"
} > "$AMR_STATS"

cat "$AMR_STATS"

log_success "Module 09 complete"
log_info "Outputs:"
log_info "  All AMR genes: $(basename $ALL_AMR_BED)"
log_info "  Classification: $(basename $AMR_CLASSIFICATION)"
log_info "  AMR matrix: $(basename $AMR_MATRIX)"
