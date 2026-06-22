#!/bin/bash
# Module 02: Plasmid Detection (MOB-suite + PlasmidFinder)
# Identifies conjugative plasmids, mobilizable plasmids, and replicon types

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/02_plasmid"
mkdir -p "$MODULE_DIR"

log_info "Module 02: Plasmid Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# MOB-suite Detection (primary method)
# ============================================================================
log_info "Running MOB-suite for plasmid detection..."

MOB_OUTPUT="$MODULE_DIR/mob_suite_output"
mkdir -p "$MOB_OUTPUT"

mob_recon \
  --infile "$GENOME_FA" \
  --outdir "$MOB_OUTPUT" \
  --num_processes "$ANNOTATION_CPUS" \
  --force 2>&1 || log_warn "MOB-suite detected no plasmids (may be chromosomal)"

# Extract plasmid BED file from MOB results
MOB_PLASMID_BED="$MODULE_DIR/${SAMPLE_NAME}_plasmids_mob.bed"

if [ -f "$MOB_OUTPUT/plasmidfinder_results.txt" ]; then
  # Parse MOB-suite output
  tail -n +2 "$MOB_OUTPUT/plasmidfinder_results.txt" 2>/dev/null | \
    awk -F'\t' '{
      print $1, $2-1, $3, "MOB_"$4"_"$5, $6, $7
    }' OFS='\t' > "$MOB_PLASMID_BED" || true
else
  > "$MOB_PLASMID_BED"
fi

log_info "MOB-suite output: $(basename $MOB_PLASMID_BED)"

# ============================================================================
# PlasmidFinder Detection (secondary/validation)
# ============================================================================
log_info "Running PlasmidFinder for replicon type detection..."

PLASMID_FINDER_OUTPUT="$MODULE_DIR/plasmidfinder_output"
mkdir -p "$PLASMID_FINDER_OUTPUT"

plasmidfinder \
  --inputfasta "$GENOME_FA" \
  --outputdir "$PLASMID_FINDER_OUTPUT" \
  --threshold "$PLASMIDFINDER_IDENTITY" \
  --num_processes "$ANNOTATION_CPUS" 2>&1 || log_warn "PlasmidFinder found no replicons"

# Parse PlasmidFinder results
PF_BED="$MODULE_DIR/${SAMPLE_NAME}_plasmids_pf.bed"

if [ -f "$PLASMID_FINDER_OUTPUT/results_tab.txt" ]; then
  tail -n +2 "$PLASMID_FINDER_OUTPUT/results_tab.txt" 2>/dev/null | \
    awk -F'\t' '{
      # PlasmidFinder: Contig, Start, End, Replicon, Identity, Coverage
      print $1, $2-1, $3, "PF_"$4, $5, $6
    }' OFS='\t' > "$PF_BED" || true
else
  > "$PF_BED"
fi

log_info "PlasmidFinder output: $(basename $PF_BED)"

# ============================================================================
# BLASTN vs known plasmids
# ============================================================================
log_info "Running BLAST against known plasmid database..."

BLAST_OUTPUT="$MODULE_DIR/${SAMPLE_NAME}_plasmid_blast.txt"

if [ -f "${PLASMIDFINDER_DB}/plasmids.fasta" ]; then
  blastn \
    -query "$GENOME_FA" \
    -subject "${PLASMIDFINDER_DB}/plasmids.fasta" \
    -evalue 1e-30 \
    -outfmt 6 \
    -max_target_seqs 10 \
    -num_threads "$ANNOTATION_CPUS" \
    -out "$BLAST_OUTPUT" 2>&1 || true
else
  log_warn "Plasmid BLAST database not found: ${PLASMIDFINDER_DB}"
  > "$BLAST_OUTPUT"
fi

# ============================================================================
# Merge and annotate plasmid calls
# ============================================================================
log_info "Merging plasmid predictions..."

ALL_PLASMIDS_BED="$MODULE_DIR/${SAMPLE_NAME}_all_plasmids.bed"

# Combine all predictions and remove duplicates
cat "$MOB_PLASMID_BED" "$PF_BED" 2>/dev/null | \
  sort -k1,1 -k2,2n | \
  uniq > "$ALL_PLASMIDS_BED" || true

# ============================================================================
# Classification: Conjugative vs Mobilizable
# ============================================================================
log_info "Classifying plasmids..."

PLASMID_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_plasmid_classification.tsv"

{
  echo -e "Contig\tStart\tEnd\tReplicon\tType\tConjugative\tMobilizable\tEvidenceScore"
  
  if [ -s "$ALL_PLASMIDS_BED" ]; then
    while IFS=$'\t' read -r contig start end replicon rest; do
      # Score based on replicon type and evidence
      conjugative=0
      mobilizable=0
      score=0
      
      # Known conjugative replicons
      if [[ "$replicon" =~ "IncF"|"IncP"|"IncN"|"IncI" ]]; then
        conjugative=1
        score=$((score + 2))
      fi
      
      # Known mobilizable indicators
      if [[ "$replicon" =~ "Inc" ]]; then
        mobilizable=1
        score=$((score + 1))
      fi
      
      echo -e "$contig\t$start\t$end\t$replicon\tplasmid\t$conjugative\t$mobilizable\t$score"
    done < "$ALL_PLASMIDS_BED"
  fi
} > "$PLASMID_CLASSIFICATION"

log_success "Plasmid classification: $(basename $PLASMID_CLASSIFICATION)"

# ============================================================================
# Statistics and Summary
# ============================================================================
log_info "Generating summary statistics..."

PLASMID_STATS="$MODULE_DIR/${SAMPLE_NAME}_plasmid_stats.txt"

{
  echo "=== Plasmid Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "MOB-suite predictions: $(wc -l < "$MOB_PLASMID_BED")"
  echo "PlasmidFinder predictions: $(wc -l < "$PF_BED")"
  echo "Combined unique predictions: $(wc -l < "$ALL_PLASMIDS_BED")"
  echo "BLAST hits: $(wc -l < "$BLAST_OUTPUT" 2>/dev/null || echo 0)"
  echo ""
  
  if [ -s "$PLASMID_CLASSIFICATION" ]; then
    conjug_count=$(tail -n +2 "$PLASMID_CLASSIFICATION" | awk -F'\t' '$6==1' | wc -l)
    mobiliz_count=$(tail -n +2 "$PLASMID_CLASSIFICATION" | awk -F'\t' '$7==1' | wc -l)
    echo "Conjugative plasmids: $conjug_count"
    echo "Mobilizable plasmids: $mobiliz_count"
  fi
} > "$PLASMID_STATS"

cat "$PLASMID_STATS"

# Validate outputs
check_output "$ALL_PLASMIDS_BED" 0 || true
check_output "$PLASMID_CLASSIFICATION" 1 || die "Classification file not created"

log_success "Module 02 complete"
log_info "Outputs:"
log_info "  All plasmids: $(basename $ALL_PLASMIDS_BED)"
log_info "  Classification: $(basename $PLASMID_CLASSIFICATION)"
