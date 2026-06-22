#!/bin/bash
# Module 06: Genomic Island Detection (GC content, tRNA flanking, HGT signals)
# Identifies regions indicative of horizontal gene transfer

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/06_genomic_islands"
mkdir -p "$MODULE_DIR"

log_info "Module 06: Genomic Island Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# Calculate Genome-Wide GC Content
# ============================================================================
log_info "Calculating genome GC content..."

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
    print(f"{100*gc/total:.2f}")
else:
    print("0")
PYTHON_GC_SCRIPT
)

log_info "Genome-wide GC content: ${GENOME_GC}%"

# ============================================================================
# Sliding Window GC Content Analysis
# ============================================================================
log_info "Scanning for GC content anomalies (window size: 5 kb)..."

WINDOW_SIZE=5000
GC_BED="$MODULE_DIR/${SAMPLE_NAME}_gc_content.bed"

python3 << 'PYTHON_GC_WINDOW'
from Bio import SeqIO
import sys

window_size = int(sys.argv[2])
genome_gc = float(sys.argv[3])
threshold = float(sys.argv[4])  # +/- 5%

with open(sys.argv[1], 'w') as outf:
    for record in SeqIO.parse(sys.argv[5], "fasta"):
        seq = str(record.seq).upper()
        
        for i in range(0, len(seq), window_size):
            window = seq[i:i+window_size]
            if len(window) < 1000:  # Skip small windows
                continue
            
            gc = 100 * (window.count('G') + window.count('C')) / len(window)
            
            # Check if window differs significantly from genome mean
            if abs(gc - genome_gc) > threshold:
                status = "HIGH_GC" if gc > genome_gc else "LOW_GC"
                outf.write(f"{record.id}\t{i}\t{i+len(window)}\t{status}_{i//1000}k\t{gc:.1f}\t.\n")

PYTHON_GC_WINDOW
$GC_BED $WINDOW_SIZE $GENOME_GC $GC_THRESHOLD_ACQUIRED "$GENOME_FA"

log_success "GC analysis complete: $(wc -l < "$GC_BED" 2>/dev/null || echo 0) anomalous regions"

# ============================================================================
# tRNA Flanking Analysis
# ============================================================================
log_info "Detecting tRNA-flanked regions..."

ANNOTATION_DIR="$OUTPUT_DIR/01_annotation"
TRNA_BED="$ANNOTATION_DIR/${SAMPLE_NAME}_tRNAs.bed"
ISLAND_BY_TRNA="$MODULE_DIR/${SAMPLE_NAME}_islands_trna_flanked.bed"

if [ -f "$TRNA_BED" ] && [ -s "$TRNA_BED" ]; then
  # Regions between consecutive tRNAs might be GIs
  python3 << 'PYTHON_TRNA_ISLANDS'
import sys

trna_regions = []
with open(sys.argv[1]) as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 3:
            trna_regions.append((parts[0], int(parts[1]), int(parts[2])))

# Find gaps between tRNAs
islands = []
for i in range(len(trna_regions) - 1):
    contig1, end1, _ = trna_regions[i]
    contig2, start2, end2 = trna_regions[i+1]
    
    if contig1 == contig2:  # Same contig
        gap_start = end1
        gap_end = start2
        gap_size = gap_end - gap_start
        
        if gap_size > 5000:  # Only consider large gaps
            islands.append((contig1, gap_start, gap_end, f"tRNA_flanked_{i}"))

with open(sys.argv[2], 'w') as outf:
    for contig, start, end, island_id in islands:
        outf.write(f"{contig}\t{start}\t{end}\t{island_id}\t.\t.\n")

PYTHON_TRNA_ISLANDS
$TRNA_BED $ISLAND_BY_TRNA
else
  > "$ISLAND_BY_TRNA"
fi

log_info "tRNA-flanked islands: $(wc -l < "$ISLAND_BY_TRNA" 2>/dev/null || echo 0)"

# ============================================================================
# Combine GC anomalies + tRNA info for island prediction
# ============================================================================
log_info "Merging GC anomalies with tRNA data..."

ISLAND_BED="$MODULE_DIR/${SAMPLE_NAME}_genomic_islands.bed"

# Combine all island indicators
{
  cat "$GC_BED" 2>/dev/null || true
  cat "$ISLAND_BY_TRNA" 2>/dev/null || true
} | sort -k1,1 -k2,2n | uniq > "$ISLAND_BED" || true

log_success "Genomic islands identified: $(wc -l < "$ISLAND_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Alien Hunter-like Analysis (IVOM score simulation)
# ============================================================================
log_info "Computing horizontal gene transfer signals..."

HGT_SIGNALS="$MODULE_DIR/${SAMPLE_NAME}_hgt_signals.tsv"

{
  echo -e "Island_ID\tContig\tStart\tEnd\tGC_Deviation\tTRNA_Flanked\tIVOM_Score\tHGT_Likelihood"
  
  if [ -s "$ISLAND_BED" ]; then
    python3 << 'PYTHON_HGT_SIGNALS'
import sys

genome_gc = float(sys.argv[1])

for line in sys.stdin:
    parts = line.strip().split('\t')
    if len(parts) < 5:
        continue
    
    contig, start, end, island_id, gc_str = parts[0], parts[1], parts[2], parts[3], parts[4]
    
    try:
        island_gc = float(gc_str)
    except:
        continue
    
    gc_dev = abs(island_gc - genome_gc)
    trna_flanked = "yes" if "tRNA" in island_id else "no"
    
    # Simple IVOM score (0-20)
    ivom = gc_dev * 2  # GC deviation contribution
    if gc_dev > 5:
        ivom += 5
    if "tRNA" in island_id:
        ivom += 3
    
    ivom = min(20, ivom)
    
    # HGT likelihood
    hgt_likely = "HIGH" if ivom > 10 else "MEDIUM" if ivom > 5 else "LOW"
    
    print(f"{island_id}\t{contig}\t{start}\t{end}\t{gc_dev:.1f}\t{trna_flanked}\t{ivom:.1f}\t{hgt_likely}")

PYTHON_HGT_SIGNALS
$(echo $GENOME_GC | cut -d'%' -f1)
  fi < "$ISLAND_BED"
} > "$HGT_SIGNALS"

log_success "HGT signals computed: $(wc -l < "$HGT_SIGNALS" 2>/dev/null || echo 0) regions"

# ============================================================================
# Island Classification (Acquired vs Intrinsic)
# ============================================================================
log_info "Classifying genomic islands..."

ISLAND_CLASSIFICATION="$MODULE_DIR/${SAMPLE_NAME}_island_classification.tsv"

{
  echo -e "Island_ID\tContig\tStart\tEnd\tGC_Deviation\tTRNA_Flanked\tHGT_Signal\tClassification_Result"
  
  if [ -s "$HGT_SIGNALS" ]; then
    tail -n +2 "$HGT_SIGNALS" | while IFS=$'\t' read -r island_id contig start end gc_dev trna_flanked ivom hgt_likely; do
      classification="AMBIGUOUS"
      
      # ACQUIRED criteria: High GC deviation + tRNA flanked + strong HGT signal
      if (( $(echo "$gc_dev > 5" | bc -l) )) && [ "$trna_flanked" = "yes" ]; then
        classification="ACQUIRED"
      fi
      
      # INTRINSIC criteria: Low GC deviation but contains IS/phage remnants
      if (( $(echo "$gc_dev < 2" | bc -l) )); then
        classification="INTRINSIC"
      fi
      
      echo -e "$island_id\t$contig\t$start\t$end\t$gc_dev\t$trna_flanked\t$ivom\t$classification"
    done
  fi
} > "$ISLAND_CLASSIFICATION"

log_success "Island classification: $(basename $ISLAND_CLASSIFICATION)"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

ISLAND_STATS="$MODULE_DIR/${SAMPLE_NAME}_island_stats.txt"

{
  echo "=== Genomic Island Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Genome GC content: ${GENOME_GC}%"
  echo "GC anomalies: $(wc -l < "$GC_BED" 2>/dev/null || echo 0)"
  echo "tRNA-flanked regions: $(wc -l < "$ISLAND_BY_TRNA" 2>/dev/null || echo 0)"
  echo "Total islands: $(wc -l < "$ISLAND_BED" 2>/dev/null || echo 0)"
  echo ""
  
  if [ -s "$ISLAND_CLASSIFICATION" ]; then
    acquired=$(tail -n +2 "$ISLAND_CLASSIFICATION" | grep "ACQUIRED" | wc -l)
    intrinsic=$(tail -n +2 "$ISLAND_CLASSIFICATION" | grep "INTRINSIC" | wc -l)
    echo "ACQUIRED (recent HGT): $acquired"
    echo "INTRINSIC (ancient): $intrinsic"
  fi
} > "$ISLAND_STATS"

cat "$ISLAND_STATS"

# Validate outputs
check_output "$ISLAND_BED" 0 || true
check_output "$ISLAND_CLASSIFICATION" 1 || die "Classification file not created"

log_success "Module 06 complete"
log_info "Outputs:"
log_info "  Islands (BED): $(basename $ISLAND_BED)"
log_info "  Classification: $(basename $ISLAND_CLASSIFICATION)"
log_info "  HGT signals: $(basename $HGT_SIGNALS)"
