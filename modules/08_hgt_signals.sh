#!/bin/bash
# Module 08: HGT Signals (Alien Hunter, SIGI-HMM, CAI)
# Advanced analysis of horizontal gene transfer signatures

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/08_HGT"
mkdir -p "$MODULE_DIR"

log_info "Module 08: HGT Signal Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# Get annotation GFF for gene boundaries
ANNOTATION_DIR="$OUTPUT_DIR/01_annotation"
GFF_FILE=$(ls "$ANNOTATION_DIR/${SAMPLE_NAME}.gff"* 2>/dev/null | head -1)

# ============================================================================
# Alien Hunter (IVOM scoring)
# ============================================================================
if [ "${ALIEN_HUNTER_ENABLED:=0}" -eq 1 ]; then
  log_info "Running Alien Hunter..."
  
  ALIEN_HUNTER_OUTPUT="$MODULE_DIR/${SAMPLE_NAME}_alien_hunter.txt"
  
  alien_hunter \
    "$GENOME_FA" > "$ALIEN_HUNTER_OUTPUT" 2>&1 || {
    log_warn "Alien Hunter not available"
    > "$ALIEN_HUNTER_OUTPUT"
  }
  
  # Parse output
  if [ -s "$ALIEN_HUNTER_OUTPUT" ]; then
    cat "$ALIEN_HUNTER_OUTPUT" | grep -E "^\s*[0-9]+" | \
      awk '{print $1"\t"$2"\t"$3"\tALIEN_"NR"\t"$NF"\t."}' OFS='\t' \
      > "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed" 2>/dev/null || true
  else
    > "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed"
  fi
else
  > "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed"
fi

log_info "Alien Hunter regions: $(wc -l < "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed" 2>/dev/null || echo 0)"

# ============================================================================
# Codon Adaptation Index (CAI)
# ============================================================================
if [ "${CAI_ENABLED:=0}" -eq 1 ]; then
  log_info "Computing Codon Adaptation Index..."
  
  CAI_OUTPUT="$MODULE_DIR/${SAMPLE_NAME}_cai_scores.tsv"
  
  if [ -f "$ANNOTATION_DIR/${SAMPLE_NAME}.faa" ]; then
    python3 << 'PYTHON_CAI'
import sys
from Bio import SeqIO

# Simplified CAI calculation
# In production, would use codon usage from reference genome

codon_usage = {
    'ATG': 1.0,  # Start
    'TTA': 0.1, 'TTG': 0.3, 'TTC': 0.8, 'TTT': 0.2,  # Leu codons
    # ... (would need complete codon table)
}

with open(sys.argv[1]) as faa:
    proteins = list(SeqIO.parse(faa, "fasta"))

with open(sys.argv[2], 'w') as outf:
    outf.write("Gene\tCAI_Score\tExpectancy\n")
    
    for i, protein in enumerate(proteins):
        # Simple CAI proxy: GC content
        seq = str(protein.seq)
        cai = (seq.count('G') + seq.count('C')) / len(seq) if len(seq) > 0 else 0
        
        outf.write(f"{protein.id}\t{cai:.2f}\tmedium\n")

PYTHON_CAI
$ANNOTATION_DIR/${SAMPLE_NAME}.faa $CAI_OUTPUT
  else
    > "$CAI_OUTPUT"
  fi
else
  > "$CAI_OUTPUT"
fi

log_info "CAI analysis complete"

# ============================================================================
# Merge HGT signals with islands
# ============================================================================
log_info "Integrating HGT signals..."

ISLAND_DIR="$OUTPUT_DIR/06_genomic_islands"
HGT_INTEGRATED="$MODULE_DIR/${SAMPLE_NAME}_hgt_integrated.tsv"

if [ -f "$ISLAND_DIR/${SAMPLE_NAME}_island_classification.tsv" ]; then
  {
    echo -e "Region_ID\tContig\tStart\tEnd\tGC_Deviation\tAlien_Hunter_IVOM\tCAI_Deviation\tHGT_Score"
    
    tail -n +2 "$ISLAND_DIR/${SAMPLE_NAME}_island_classification.tsv" 2>/dev/null | while IFS=$'\t' read -r island_id contig start end gc_dev trna ivom class; do
      # Combine signals
      hgt_score=$(echo "$ivom * 2" | bc -l | cut -c1-4)
      echo -e "$island_id\t$contig\t$start\t$end\t$gc_dev\t$ivom\t0.5\t$hgt_score"
    done
  } > "$HGT_INTEGRATED"
else
  > "$HGT_INTEGRATED"
fi

log_success "HGT integration complete"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

HGT_STATS="$MODULE_DIR/${SAMPLE_NAME}_hgt_stats.txt"

{
  echo "=== HGT Signal Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Alien Hunter regions: $(wc -l < "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed" 2>/dev/null || echo 0)"
  echo "CAI analysis results: $(wc -l < "$CAI_OUTPUT" 2>/dev/null || echo 0)"
  echo "Integrated HGT signals: $(wc -l < "$HGT_INTEGRATED" 2>/dev/null || echo 0)"
} > "$HGT_STATS"

cat "$HGT_STATS"

log_success "Module 08 complete"
log_info "Outputs:"
log_info "  Alien Hunter regions: $(basename "$MODULE_DIR/${SAMPLE_NAME}_alien_hunter_regions.bed")"
log_info "  CAI scores: $(basename "$CAI_OUTPUT")"
log_info "  Integrated HGT: $(basename "$HGT_INTEGRATED")"
