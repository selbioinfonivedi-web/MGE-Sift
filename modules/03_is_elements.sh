#!/bin/bash
# Module 03: IS Element Detection (ISEScan + BLAST)
# Identifies insertion sequences and classifies them (active/degraded)

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/03_IS_elements"
mkdir -p "$MODULE_DIR"

log_info "Module 03: IS Element Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# ISEScan Detection (primary method)
# ============================================================================
log_info "Running ISEScan for IS element detection..."

ISESCAN_OUTPUT="$MODULE_DIR/isescan_output"
mkdir -p "$ISESCAN_OUTPUT"

isescan.py \
  --seqfile "$GENOME_FA" \
  --outdir "$ISESCAN_OUTPUT" \
  --evalue "$ISESCAN_E_VALUE" \
  --min_len "$ISESCAN_MIN_LENGTH" 2>&1 || log_warn "ISEScan found no IS elements"

# Parse ISEScan output
IS_BED="$MODULE_DIR/${SAMPLE_NAME}_IS_elements.bed"
IS_DETAILED="$MODULE_DIR/${SAMPLE_NAME}_IS_elements_detailed.tsv"

if [ -f "$ISESCAN_OUTPUT/orf.txt" ]; then
  {
    echo -e "Contig\tStart\tEnd\tIS_ID\tType\tIdentity\tTransposase_Status"
    
    tail -n +2 "$ISESCAN_OUTPUT/orf.txt" 2>/dev/null | \
    while IFS=$'\t' read -r contig start end orf_id orf_type score evalue trans_type; do
      # Filter by min identity
      if (( $(echo "$score >= $ISESCAN_MIN_IDENTITY" | bc -l) )); then
        bed_start=$((start - 1))
        
        # Classify transposase status: c=complete, p=partial/truncated
        trans_status="unknown"
        if [[ "$trans_type" == "c" ]]; then
          trans_status="intact"
        elif [[ "$trans_type" == "p" ]]; then
          trans_status="partial"
        fi
        
        echo -e "$contig\t$bed_start\t$end\t$orf_id\t$orf_type\t$score\t$trans_status"
        echo "$contig\t$bed_start\t$end\tIS_${orf_id}\t.\t." >> "$IS_BED" 2>/dev/null || true
      fi
    done
  } > "$IS_DETAILED"
  
  sort -k1,1 -k2,2n "$IS_BED" > "${IS_BED}.sorted" 2>/dev/null || true
  mv "${IS_BED}.sorted" "$IS_BED" 2>/dev/null || true
else
  > "$IS_BED"
  > "$IS_DETAILED"
fi

log_info "ISEScan output: $(basename $IS_DETAILED)"

# ============================================================================
# BLAST vs ISfinder Database
# ============================================================================
log_info "Running BLAST against ISfinder database..."

ISBLAST_OUTPUT="$MODULE_DIR/${SAMPLE_NAME}_IS_blast.txt"

if [ -f "${ISESCAN_DB}/isdb.fa" ] || [ -f "${ISESCAN_DB}/is.fa" ]; then
  DB_FILE="${ISESCAN_DB}/isdb.fa"
  [ ! -f "$DB_FILE" ] && DB_FILE="${ISESCAN_DB}/is.fa"
  
  blastn \
    -query "$GENOME_FA" \
    -subject "$DB_FILE" \
    -evalue "$ISESCAN_E_VALUE" \
    -outfmt 6 \
    -max_target_seqs 50 \
    -num_threads "$ANNOTATION_CPUS" \
    -out "$ISBLAST_OUTPUT" 2>&1 || {
    log_warn "BLAST against ISfinder failed"
    > "$ISBLAST_OUTPUT"
  }
else
  log_warn "ISfinder BLAST database not found"
  > "$ISBLAST_OUTPUT"
fi

# ============================================================================
# TSD (Target Site Duplication) Detection
# ============================================================================
log_info "Detecting Target Site Duplications (TSDs)..."

TSD_BED="$MODULE_DIR/${SAMPLE_NAME}_TSDs.bed"

python3 << 'PYTHON_TSD_SCRIPT'
import sys
import re
from Bio import SeqIO

genome_fa = sys.argv[1]
is_bed = sys.argv[2]
tsd_out = sys.argv[3]

# Load genome
genome = {}
for record in SeqIO.parse(genome_fa, "fasta"):
    genome[record.id] = str(record.seq)

tsd_regions = []

# Read IS elements BED
if os.path.exists(is_bed):
    with open(is_bed) as f:
        for line in f:
            if line.startswith('#'): continue
            parts = line.strip().split('\t')
            if len(parts) < 3: continue
            
            contig, start, end = parts[0], int(parts[1]), int(parts[2])
            is_id = parts[3] if len(parts) > 3 else f"IS_{start}"
            
            # Look for TSD flanking regions (typically 2-14 bp repeats)
            flank_size = 50
            
            # Extract flanking sequences
            if contig in genome:
                seq = genome[contig]
                left_flank_start = max(0, start - flank_size)
                right_flank_end = min(len(seq), end + flank_size)
                
                left_flank = seq[left_flank_start:start]
                right_flank = seq[end:right_flank_end]
                
                # Simple TSD detection: look for short repeats
                for tsd_len in range(2, 15):
                    if len(left_flank) >= tsd_len and len(right_flank) >= tsd_len:
                        left_tsd = left_flank[-tsd_len:]
                        right_tsd = right_flank[:tsd_len]
                        
                        if left_tsd == right_tsd:
                            tsd_regions.append({
                                'contig': contig,
                                'is_start': start,
                                'is_end': end,
                                'is_id': is_id,
                                'tsd': left_tsd,
                                'tsd_len': tsd_len
                            })
                            break

# Write TSD BED
with open(tsd_out, 'w') as f:
    for region in tsd_regions:
        f.write(f"{region['contig']}\t{region['is_start']}\t{region['is_end']}\t"
                f"{region['is_id']}_TSD{region['tsd_len']}\t{region['tsd']}\t.\n")
PYTHON_TSD_SCRIPT

# Fallback if Python script fails
if [ ! -f "$TSD_BED" ]; then
  > "$TSD_BED"
fi

log_info "TSD detection output: $(basename $TSD_BED)"

# ============================================================================
# IS Element Classification (Scoring)
# ============================================================================
log_info "Classifying IS elements..."

IS_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_IS_classification.tsv"

{
  echo -e "IS_ID\tContig\tStart\tEnd\tType\tTransposase_Status\tCopy_Number\tTSD_Count\tBlast_Hit_Identity\tClassification_Score\tClassification_Result"
  
  # Count IS copies
  copy_count=$(wc -l < "$IS_BED" 2>/dev/null || echo 0)
  
  # Count TSDs
  tsd_count=$(wc -l < "$TSD_BED" 2>/dev/null || echo 0)
  
  if [ -s "$IS_DETAILED" ]; then
    tail -n +2 "$IS_DETAILED" | while IFS=$'\t' read -r contig start end is_id type identity trans_status; do
      score=0
      classification="AMBIGUOUS"
      
      # Scoring for IS element classification (acquired vs intrinsic)
      
      # Intact transposase: +2 points toward ACQUIRED
      if [[ "$trans_status" == "intact" ]]; then
        score=$((score + 2))
      fi
      
      # TSDs present: +2 points toward ACQUIRED
      if grep -q "$is_id" "$TSD_BED" 2>/dev/null; then
        score=$((score + 2))
      fi
      
      # Multiple copies: +1 point toward ACQUIRED
      if [ "$copy_count" -gt 1 ]; then
        score=$((score + 1))
      fi
      
      # Recent BLAST hit: +1 point (if identity > 95%)
      if (( $(echo "$identity >= 0.95" | bc -l) )); then
        score=$((score + 1))
      fi
      
      # Truncated transposase: -2 points toward INTRINSIC
      if [[ "$trans_status" == "partial" ]]; then
        score=$((score - 2))
      fi
      
      # Determine classification
      if [ "$score" -ge 3 ]; then
        classification="ACQUIRED_ACTIVE"
      elif [ "$score" -ge 1 ]; then
        classification="ACQUIRED_MOBILIZED"
      else
        classification="INTRINSIC_IMMOBILIZED"
      fi
      
      echo -e "$is_id\t$contig\t$start\t$end\t$type\t$trans_status\t$copy_count\t$tsd_count\t$identity\t$score\t$classification"
    done
  fi
} > "$IS_CLASSIFICATION"

log_success "IS classification: $(basename $IS_CLASSIFICATION)"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

IS_STATS="$MODULE_DIR/${SAMPLE_NAME}_IS_stats.txt"

{
  echo "=== IS Element Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Total IS elements: $(wc -l < "$IS_BED" 2>/dev/null || echo 0)"
  echo "ISEScan detections: $(wc -l < "$IS_DETAILED" 2>/dev/null || echo 0)"
  echo "BLAST hits: $(wc -l < "$ISBLAST_OUTPUT" 2>/dev/null || echo 0)"
  echo "Regions with TSD: $(wc -l < "$TSD_BED" 2>/dev/null || echo 0)"
  echo ""
  
  if [ -s "$IS_CLASSIFICATION" ]; then
    acquired=$(tail -n +2 "$IS_CLASSIFICATION" | grep "ACQUIRED" | wc -l)
    intrinsic=$(tail -n +2 "$IS_CLASSIFICATION" | grep "INTRINSIC" | wc -l)
    echo "ACQUIRED (active/mobilized): $acquired"
    echo "INTRINSIC (immobilized): $intrinsic"
  fi
} > "$IS_STATS"

cat "$IS_STATS"

# Validate outputs
check_output "$IS_BED" 0 || true
check_output "$IS_CLASSIFICATION" 1 || die "Classification file not created"

log_success "Module 03 complete"
log_info "Outputs:"
log_info "  IS elements (BED): $(basename $IS_BED)"
log_info "  Classification: $(basename $IS_CLASSIFICATION)"
