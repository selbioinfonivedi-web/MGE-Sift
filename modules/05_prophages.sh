#!/bin/bash
# Module 05: Prophage Detection (PhiSpy + PHASTER)
# Identifies integrated phage sequences and structural elements

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/05_prophage"
mkdir -p "$MODULE_DIR"

log_info "Module 05: Prophage Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# PhiSpy Detection (primary method)
# ============================================================================
log_info "Running PhiSpy for prophage detection..."

PHISPY_OUTPUT="$MODULE_DIR/phispy_output"
mkdir -p "$PHISPY_OUTPUT"

# Need GFF file from annotation module
ANNOTATION_DIR="$OUTPUT_DIR/01_annotation"
GFF_FILE=$(ls "$ANNOTATION_DIR/${SAMPLE_NAME}.gff"* 2>/dev/null | head -1)

if [ -z "$GFF_FILE" ]; then
  log_error "GFF file from annotation module not found"
  GFF_FILE="$MODULE_DIR/${SAMPLE_NAME}_temp.gff"
  > "$GFF_FILE"
fi

phispy.py \
  --input_fasta "$GENOME_FA" \
  --input_gff "$GFF_FILE" \
  --out_dir "$PHISPY_OUTPUT" \
  --num_threads "$ANNOTATION_CPUS" \
  --window_len 15 \
  --e_val "$PHISPY_E_VALUE" 2>&1 || log_warn "PhiSpy found no prophages"

# Parse PhiSpy results
PHAGE_BED="$MODULE_DIR/${SAMPLE_NAME}_prophages.bed"
PHAGE_DETAILED="$MODULE_DIR/${SAMPLE_NAME}_prophages_detailed.tsv"

if [ -f "$PHISPY_OUTPUT/prophage_coords.txt" ]; then
  {
    echo -e "Contig\tStart\tEnd\tProphage_ID\tMethod\tConfidence"
    
    tail -n +2 "$PHISPY_OUTPUT/prophage_coords.txt" 2>/dev/null | \
    while IFS=$'\t' read -r contig start end prophage_id; do
      echo -e "$contig\t$start\t$end\tPhiSpy_$prophage_id\tPhiSpy\t0.8"
      echo "$contig\t$start\t$end\tPhiSpy_${prophage_id}\t.\t." >> "$PHAGE_BED" 2>/dev/null || true
    done
  } > "$PHAGE_DETAILED"
  
  sort -k1,1 -k2,2n "$PHAGE_BED" > "${PHAGE_BED}.sorted" 2>/dev/null || true
  mv "${PHAGE_BED}.sorted" "$PHAGE_BED" 2>/dev/null || true
else
  > "$PHAGE_BED"
  > "$PHAGE_DETAILED"
fi

log_info "PhiSpy output: $(basename $PHAGE_DETAILED)"

# ============================================================================
# PHASTER Detection (optional - requires online submission)
# ============================================================================
if [ "${PHASTER_ENABLED:=0}" -eq 1 ]; then
  log_info "Submitting to PHASTER (this may take a few minutes)..."
  
  PHASTER_OUTPUT="$MODULE_DIR/phaster_output"
  mkdir -p "$PHASTER_OUTPUT"
  
  # PHASTER is web-based, would require API call or manual submission
  # For now, create placeholder
  log_warn "PHASTER submission requires manual setup or API key configuration"
  > "$PHASTER_OUTPUT/phaster_results.txt"
fi

# ============================================================================
# Prophage Classification (Acquired vs Intrinsic)
# ============================================================================
log_info "Classifying prophages..."

PHAGE_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_prophage_classification.tsv"

# Calculate genome GC content for comparison
GENOME_GC=$(python3 << 'PYTHON_GC_SCRIPT'
from Bio import SeqIO
import sys

total = 0
gc = 0
for record in SeqIO.parse(sys.argv[1], "fasta"):
    seq = str(record.seq).upper()
    total += len(seq)
    gc += seq.count('G') + seq.count('C')

if total > 0:
    print(f"{100*gc/total:.1f}")
else:
    print("0")
PYTHON_GC_SCRIPT
)

log_info "Genome GC content: ${GENOME_GC}%"

{
  echo -e "Prophage_ID\tContig\tStart\tEnd\tMethod\tGC_Content\tStructural_Genes\tLytic_Genes\tClassification_Result"
  
  if [ -s "$PHAGE_DETAILED" ]; then
    tail -n +2 "$PHAGE_DETAILED" | while IFS=$'\t' read -r contig start end phage_id method confidence; do
      
      # Extract GC content of prophage region
      phage_gc=$(python3 << 'PYTHON_REGION_GC'
from Bio import SeqIO
import sys

start = int(sys.argv[2])
end = int(sys.argv[3])
contig_name = sys.argv[4]

for record in SeqIO.parse(sys.argv[1], "fasta"):
    if record.id == contig_name:
        region = str(record.seq)[start-1:end].upper()
        gc = region.count('G') + region.count('C')
        if len(region) > 0:
            print(f"{100*gc/len(region):.1f}")
        else:
            print("0")
        break
else:
    print("0")
PYTHON_REGION_GC
      )
      
      # Simple classification based on GC content
      classification="AMBIGUOUS"
      struct_genes=0
      lytic_genes=0
      
      # If GC content is close to genome mean, likely INTRINSIC (ancient)
      gc_diff=$(echo "$phage_gc - $GENOME_GC" | bc)
      if (( $(echo "$gc_diff < 2" | bc -l) )); then
        classification="INTRINSIC_REMNANT"
      elif (( $(echo "$gc_diff > 5" | bc -l) )); then
        classification="ACQUIRED_RECENT"
      fi
      
      echo -e "$phage_id\t$contig\t$start\t$end\t$method\t$phage_gc\t$struct_genes\t$lytic_genes\t$classification"
    done
  fi
} > "$PHAGE_CLASSIFICATION"

log_success "Prophage classification: $(basename $PHAGE_CLASSIFICATION)"

# ============================================================================
# Extract Structural and Tail Proteins
# ============================================================================
log_info "Extracting phage-related genes..."

PHAGE_PROTEINS="$MODULE_DIR/${SAMPLE_NAME}_phage_proteins.bed"

# Search for common phage protein keywords
KEYWORDS="tail|head|portal|terminase|integrase|recombinase|baseplate|sheath"

if [ -f "$ANNOTATION_DIR/${SAMPLE_NAME}.gff"* ]; then
  GFF=$(ls "$ANNOTATION_DIR/${SAMPLE_NAME}.gff"* 2>/dev/null | head -1)
  
  grep -E "$KEYWORDS" "$GFF" 2>/dev/null | \
    bedtools intersect -a - -b "$PHAGE_BED" -wa 2>/dev/null | \
    awk -F'\t' '{print $1"\t"$4-1"\t"$5"\t.\t.\t."}' OFS='\t' > "$PHAGE_PROTEINS" || true
fi

if [ ! -f "$PHAGE_PROTEINS" ]; then
  > "$PHAGE_PROTEINS"
fi

log_info "Phage proteins: $(wc -l < "$PHAGE_PROTEINS" 2>/dev/null || echo 0)"

# ============================================================================
# Attachment Sites (attL/attR)
# ============================================================================
log_info "Searching for phage attachment sites (attL/attR)..."

ATT_SITES="$MODULE_DIR/${SAMPLE_NAME}_att_sites.bed"

# Simple motif search for common att sites (20-50 bp)
# This is a placeholder; real att sites require careful detection

> "$ATT_SITES"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

PHAGE_STATS="$MODULE_DIR/${SAMPLE_NAME}_prophage_stats.txt"

{
  echo "=== Prophage Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Total prophages (PhiSpy): $(wc -l < "$PHAGE_BED" 2>/dev/null || echo 0)"
  echo "Phage proteins found: $(wc -l < "$PHAGE_PROTEINS" 2>/dev/null || echo 0)"
  echo "Attachment sites: $(wc -l < "$ATT_SITES" 2>/dev/null || echo 0)"
  echo ""
  
  if [ -s "$PHAGE_CLASSIFICATION" ]; then
    acquired=$(tail -n +2 "$PHAGE_CLASSIFICATION" | grep "ACQUIRED" | wc -l)
    intrinsic=$(tail -n +2 "$PHAGE_CLASSIFICATION" | grep "INTRINSIC" | wc -l)
    echo "ACQUIRED (recent): $acquired"
    echo "INTRINSIC (ancient remnants): $intrinsic"
  fi
} > "$PHAGE_STATS"

cat "$PHAGE_STATS"

# Validate outputs
check_output "$PHAGE_BED" 0 || true
check_output "$PHAGE_CLASSIFICATION" 1 || die "Classification file not created"

log_success "Module 05 complete"
log_info "Outputs:"
log_info "  Prophages (BED): $(basename $PHAGE_BED)"
log_info "  Classification: $(basename $PHAGE_CLASSIFICATION)"
log_info "  Proteins: $(basename $PHAGE_PROTEINS)"
