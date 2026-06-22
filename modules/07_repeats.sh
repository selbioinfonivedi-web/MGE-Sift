#!/bin/bash
# Module 07: Repeat Detection (TSDs, Inverted Repeats, Direct Repeats)
# Identifies sequence repeats and duplications flanking MGE elements

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/07_repeats"
mkdir -p "$MODULE_DIR"

log_info "Module 07: Repeat Detection"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# ============================================================================
# Inverted Repeat Detection (using einverted)
# ============================================================================
log_info "Detecting inverted repeats..."

INVERTED_RAW="$MODULE_DIR/${SAMPLE_NAME}_inverted_raw.txt"
INVERTED_BED="$MODULE_DIR/${SAMPLE_NAME}_inverted_repeats.bed"

einverted \
  -sequence "$GENOME_FA" \
  -outfile "$INVERTED_RAW" \
  -maxrepeat "$REPEAT_MAX_LENGTH" \
  -maxgap 50 \
  -match "$REPEAT_MIN_LENGTH" 2>&1 || log_warn "einverted found no inverted repeats"

# Parse inverted repeat output to BED
if [ -f "$INVERTED_RAW" ]; then
  python3 << 'PYTHON_INVERTED'
import re
import sys

with open(sys.argv[1]) as f:
    content = f.read()

with open(sys.argv[2], 'w') as outf:
    # Parse EMBOSS einverted format
    sections = re.split(r'Inverted repeat: ', content)
    
    for i, section in enumerate(sections[1:]):
        lines = section.strip().split('\n')
        for line in lines:
            if 'Position' in line and 'bases' in line:
                # Extract coordinates
                match = re.search(r'Position\s+(\d+)\s+to\s+(\d+)', line)
                if match:
                    start = int(match.group(1)) - 1
                    end = int(match.group(2))
                    outf.write(f"contig\t{start}\t{end}\tINVERT_{i}\t.\t.\n")

PYTHON_INVERTED
$INVERTED_RAW $INVERTED_BED
else
  > "$INVERTED_BED"
fi

log_info "Inverted repeats: $(wc -l < "$INVERTED_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Direct Repeat Detection
# ============================================================================
log_info "Detecting direct repeats..."

DIRECT_BED="$MODULE_DIR/${SAMPLE_NAME}_direct_repeats.bed"

python3 << 'PYTHON_DIRECT_REPEATS'
from Bio import SeqIO
import sys

min_rep_len = int(sys.argv[2])
max_rep_len = int(sys.argv[3])
min_identity = float(sys.argv[4])

direct_repeats = []

for record in SeqIO.parse(sys.argv[1], "fasta"):
    seq = str(record.seq).upper()
    
    # Look for direct repeats
    for rep_len in range(min_rep_len, max_rep_len + 1):
        for i in range(len(seq) - rep_len*2 - 100):
            repeat1 = seq[i:i+rep_len]
            
            # Look for second copy within 100 bp
            for j in range(i + rep_len, min(i + rep_len + 100, len(seq) - rep_len)):
                repeat2 = seq[j:j+rep_len]
                
                # Calculate identity
                matches = sum(1 for a, b in zip(repeat1, repeat2) if a == b)
                identity = matches / rep_len
                
                if identity >= min_identity:
                    direct_repeats.append({
                        'contig': record.id,
                        'rep1_start': i,
                        'rep1_end': i + rep_len,
                        'rep2_start': j,
                        'rep2_end': j + rep_len,
                        'length': rep_len,
                        'identity': identity
                    })

# Remove redundant repeats and write output
seen = set()
with open(sys.argv[5], 'w') as outf:
    for rep in direct_repeats:
        key = (rep['contig'], rep['rep1_start'], rep['rep2_start'])
        if key not in seen:
            outf.write(f"{rep['contig']}\t{rep['rep1_start']}\t{rep['rep2_end']}\t"
                      f"DIRECT_{rep['length']}bp\t{rep['identity']:.2f}\t.\n")
            seen.add(key)

PYTHON_DIRECT_REPEATS
$GENOME_FA $REPEAT_MIN_LENGTH $REPEAT_MAX_LENGTH $REPEAT_IDENTITY $DIRECT_BED

log_info "Direct repeats: $(wc -l < "$DIRECT_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Tandem Repeat Detection
# ============================================================================
log_info "Detecting tandem repeats..."

TANDEM_BED="$MODULE_DIR/${SAMPLE_NAME}_tandem_repeats.bed"

trf "$GENOME_FA" 2 7 7 80 10 50 500 -h -d 2>&1 | \
  awk -F' ' 'NR>1 {
    contig=$1; start=$2-1; end=$3; period=$5; copies=$6; score=$7;
    print contig"\t"start"\t"end"\tTANDEM_"NR"\t"score"\t."
  }' OFS='\t' > "$TANDEM_BED" 2>/dev/null || {
  log_warn "trf not available or failed"
  > "$TANDEM_BED"
}

log_info "Tandem repeats: $(wc -l < "$TANDEM_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Merge all repeats
# ============================================================================
log_info "Merging repeat predictions..."

ALL_REPEATS_BED="$MODULE_DIR/${SAMPLE_NAME}_all_repeats.bed"

{
  cat "$INVERTED_BED" 2>/dev/null || true
  cat "$DIRECT_BED" 2>/dev/null || true
  cat "$TANDEM_BED" 2>/dev/null || true
} | sort -k1,1 -k2,2n | uniq > "$ALL_REPEATS_BED" || true

log_success "Total repeats detected: $(wc -l < "$ALL_REPEATS_BED" 2>/dev/null || echo 0)"

# ============================================================================
# Statistics
# ============================================================================
log_info "Generating summary statistics..."

REPEAT_STATS="$MODULE_DIR/${SAMPLE_NAME}_repeat_stats.txt"

{
  echo "=== Repeat Detection Summary for $SAMPLE_NAME ==="
  echo ""
  echo "Inverted repeats: $(wc -l < "$INVERTED_BED" 2>/dev/null || echo 0)"
  echo "Direct repeats: $(wc -l < "$DIRECT_BED" 2>/dev/null || echo 0)"
  echo "Tandem repeats: $(wc -l < "$TANDEM_BED" 2>/dev/null || echo 0)"
  echo "Total: $(wc -l < "$ALL_REPEATS_BED" 2>/dev/null || echo 0)"
} > "$REPEAT_STATS"

cat "$REPEAT_STATS"

log_success "Module 07 complete"
log_info "Outputs:"
log_info "  All repeats: $(basename $ALL_REPEATS_BED)"
log_info "  Inverted: $(basename $INVERTED_BED)"
log_info "  Direct: $(basename $DIRECT_BED)"
