#!/bin/bash
# Module 04: Integron Detection (IntegronFinder)
# Identifies class 1, 2, 3 integrons, and CALIN integrons

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/04_integrons"
mkdir -p "$MODULE_DIR"

log_info "Module 04: Integron Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# IntegronFinder Detection
# ============================================================================
log_info "Running IntegronFinder..."

integron_finder \
  --fasta "$GENOME_FA" \
  --outdir "$MODULE_DIR" \
  --prefix "$SAMPLE_NAME" \
  --local-max \
  --max-evalue "$INTEGRON_MAX_EVALUE" \
  --min-attc-size 39 \
  --max-attc-size 41 \
  --cpu "$ANNOTATION_CPUS" 2>&1 || log_warn "IntegronFinder found no integrons"

# Parse IntegronFinder results
INTEGRON_BED="$MODULE_DIR/${SAMPLE_NAME}_integrons.bed"
INTEGRON_DETAILED="$MODULE_DIR/${SAMPLE_NAME}_integrons_detailed.tsv"

# IntegronFinder outputs GFF, extract to BED
INTEGRON_GFF="$MODULE_DIR/${SAMPLE_NAME}.gff"

if [ -f "$INTEGRON_GFF" ]; then
  {
    echo -e "Contig\tStart\tEnd\tIntegron_ID\tClass\tCompleteness"
    
    grep "integron" "$INTEGRON_GFF" | awk -F'\t' '{
      split($9, attrs, ";")
      integron_id=""
      for (a in attrs) {
        if (attrs[a] ~ /ID=/) {
          gsub(/ID=/, "", attrs[a])
          integron_id=attrs[a]
        }
      }
      print $1, $4-1, $5, integron_id, "unknown", "complete"
    }' OFS='\t'
  } > "$INTEGRON_DETAILED"
  
  # Create BED from detailed file
  tail -n +2 "$INTEGRON_DETAILED" | \
    awk -F'\t' '{print $1"\t"$2"\t"$3"\t"$4"\t.\t."}' OFS='\t' > "$INTEGRON_BED" || true
else
  > "$INTEGRON_BED"
  > "$INTEGRON_DETAILED"
fi

log_info "IntegronFinder output: $(basename $INTEGRON_DETAILED)"

# ============================================================================
# Extract Integron Cassettes (attC sites)
# ============================================================================
log_info "Extracting attC cassettes..."

CASSETTE_BED="$MODULE_DIR/${SAMPLE_NAME}_cassettes.bed"
CASSETTE_SEQUENCES="$MODULE_DIR/${SAMPLE_NAME}_cassettes.fa"

if [ -f "$INTEGRON_GFF" ]; then
  grep "attC" "$INTEGRON_GFF" | awk -F'\t' '{
    split($9, attrs, ";")
    cassette_id=""
    for (a in attrs) {
      if (attrs[a] ~ /ID=/) {
        gsub(/ID=/, "", attrs[a])
        cassette_id=attrs[a]
      }
    }
    print $1, $4-1, $5, cassette_id, ".", $7
  }' OFS='\t' > "$CASSETTE_BED" || true
else
  > "$CASSETTE_BED"
fi

log_info "Cassettes detected: $(wc -l < "$CASSETTE_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Integron Classification (Acquired vs Intrinsic)
# ============================================================================
log_info "Classifying integrons..."

INTEGRON_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_integron_classification.tsv"

{
  echo -e "Integron_ID\tContig\tStart\tEnd\tClass\tIntI_Status\tCassette_Count\tClassification_Result"
  
  if [ -s "$INTEGRON_DETAILED" ]; then
    tail -n +2 "$INTEGRON_DETAILED" | while IFS=$'\t' read -r contig start end integron_id class completeness; do
      
      # Determine intI presence
      intI_status="absent"
      
      # Count cassettes in this integron
      cassette_count=$(grep "^$contig" "$CASSETTE_BED" 2>/dev/null | awk -v s="$start" -v e="$end" \
        '$2 >= s && $3 <= e' | wc -l)
      
      # Classification logic
      classification="AMBIGUOUS"
      
      # IntegronFinder "complete" class indicates ACQUIRED
      if [[ "$completeness" == "complete" ]] && [ "$cassette_count" -gt 0 ]; then
        classification="ACQUIRED"
        intI_status="present"
      fi
      
      # CALIN integrons (no intI, old chromosomal) = INTRINSIC
      if [[ "$class" =~ "CALIN" ]]; then
        classification="INTRINSIC"
        intI_status="absent"
      fi
      
      # In0 or incomplete with no cassettes = AMBIGUOUS
      if [[ "$class" =~ "In0" ]] || [ "$cassette_count" -eq 0 ]; then
        classification="AMBIGUOUS"
      fi
      
      echo -e "$integron_id\t$contig\t$start\t$end\t$class\t$intI_status\t$cassette_count\t$classification"
    done
  fi
} > "$INTEGRON_CLASSIFICATION"

log_success "Integron classification: $(basename $INTEGRON_CLASSIFICATION)"

# ============================================================================
# Extract protein sequences from cassettes
# ============================================================================
log_info "Extracting cassette gene sequences..."

# Try to extract CDS from cassette regions (if GFF available from annotation module)
ANNOTATION_DIR="$OUTPUT_DIR/01_annotation"
if [ -f "$ANNOTATION_DIR/${SAMPLE_NAME}.gff" ] || [ -f "$ANNOTATION_DIR/${SAMPLE_NAME}.gff3" ]; then
  GFF_FILE=$(ls "$ANNOTATION_DIR/${SAMPLE_NAME}.gff"* 2>/dev/null | head -1)
  
  # Extract CDS within cassettes
  CASSETTE_CDS="$MODULE_DIR/${SAMPLE_NAME}_cassette_CDS.bed"
  
  bedtools intersect -a <(grep "CDS" "$GFF_FILE" | awk -F'\t' '{print $1"\t"$4-1"\t"$5"\t.\t.\t."}' OFS='\t') \
    -b "$CASSETTE_BED" -wa > "$CASSETTE_CDS" 2>/dev/null || true
  
  log_info "Cassette CDS genes: $(wc -l < "$CASSETTE_CDS" 2>/dev/null || echo 0)"
fi

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

INTEGRON_STATS="$MODULE_DIR/${SAMPLE_NAME}_integron_stats.txt"

{
  echo "=== Integron Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Total integrons: $(wc -l < "$INTEGRON_BED" 2>/dev/null || echo 0)"
  echo "Total cassettes: $(wc -l < "$CASSETTE_BED" 2>/dev/null || echo 0)"
  echo ""
  
  if [ -s "$INTEGRON_CLASSIFICATION" ]; then
    acquired=$(tail -n +2 "$INTEGRON_CLASSIFICATION" | grep "ACQUIRED" | wc -l)
    intrinsic=$(tail -n +2 "$INTEGRON_CLASSIFICATION" | grep "INTRINSIC" | wc -l)
    ambiguous=$(tail -n +2 "$INTEGRON_CLASSIFICATION" | grep "AMBIGUOUS" | wc -l)
    echo "ACQUIRED integrons: $acquired"
    echo "INTRINSIC (CALIN): $intrinsic"
    echo "Ambiguous: $ambiguous"
  fi
} > "$INTEGRON_STATS"

cat "$INTEGRON_STATS"

# Validate outputs
check_output "$INTEGRON_BED" 0 || true
check_output "$INTEGRON_CLASSIFICATION" 1 || die "Classification file not created"

log_success "Module 04 complete"
log_info "Outputs:"
log_info "  Integrons (BED): $(basename $INTEGRON_BED)"
log_info "  Cassettes: $(basename $CASSETTE_BED)"
log_info "  Classification: $(basename $INTEGRON_CLASSIFICATION)"
