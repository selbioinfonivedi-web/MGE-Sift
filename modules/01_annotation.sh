#!/bin/bash
# Module 01: Genome Annotation (Prokka/Bakta)
# Annotates protein-coding genes, rRNAs, tRNAs, and other features

set -euo pipefail

GENOME_FA=$1
SAMPLE_NAME=$2
OUTPUT_DIR=$3
CONFIG_FILE=$4

source "$CONFIG_FILE"
source "$(dirname "$0")/../lib/common_functions.sh"
source "$(dirname "$0")/../lib/error_handling.sh"

MODULE_DIR="$OUTPUT_DIR/01_annotation"
mkdir -p "$MODULE_DIR"

log_info "Module 01: Genome Annotation"
log_info "Input: $(basename $GENOME_FA)"
log_info "Output directory: $MODULE_DIR"

# Select annotation tool
if [ "$ANNOTATION_TOOL" = "bakta" ]; then
  log_info "Using BAKTA for annotation..."
  
  bakta --db "$BAKTA_DB" \
    --output "$MODULE_DIR" \
    --prefix "$SAMPLE_NAME" \
    --threads "$ANNOTATION_CPUS" \
    --skip-plot \
    "$GENOME_FA" 2>&1 || die "BAKTA annotation failed"
  
  # Symlink outputs to standard names
  GFF="$MODULE_DIR/${SAMPLE_NAME}.gff3"
  PROTEINS="$MODULE_DIR/${SAMPLE_NAME}.faa"
  NUCLEOTIDES="$MODULE_DIR/${SAMPLE_NAME}.ffn"
  
else
  log_info "Using PROKKA for annotation..."
  
  prokka \
    --outdir "$MODULE_DIR" \
    --prefix "$SAMPLE_NAME" \
    --cpus "$ANNOTATION_CPUS" \
    --kingdom "$ANNOTATION_KINGDOM" \
    --metagenome "$ANNOTATION_METAGENOME" \
    --norrna \
    --notrna \
    --force \
    "$GENOME_FA" 2>&1 || die "PROKKA annotation failed"
  
  # Standard outputs
  GFF="$MODULE_DIR/${SAMPLE_NAME}.gff"
  PROTEINS="$MODULE_DIR/${SAMPLE_NAME}.faa"
  NUCLEOTIDES="$MODULE_DIR/${SAMPLE_NAME}.ffn"
  
  # Move to standard names
  if [ -f "$MODULE_DIR/${SAMPLE_NAME}.gff" ]; then
    mv "$MODULE_DIR/${SAMPLE_NAME}.gff" "$GFF"
  fi
fi

# Extract tRNAs separately for island/HGT analysis
log_info "Extracting tRNA coordinates..."
TRNA_BED="$MODULE_DIR/${SAMPLE_NAME}_tRNAs.bed"

tRNAscan-SE -B -o "$MODULE_DIR/${SAMPLE_NAME}_trnascan.txt" "$GENOME_FA" 2>&1 || {
  log_warn "tRNAscan-SE failed, generating empty tRNA file"
  > "$TRNA_BED"
}

# Convert tRNAscan output to BED format
if [ -s "$MODULE_DIR/${SAMPLE_NAME}_trnascan.txt" ]; then
  tail -n +4 "$MODULE_DIR/${SAMPLE_NAME}_trnascan.txt" | \
    awk '{print $1, $3-1, $4, $5, ".", $6}' OFS='\t' > "$TRNA_BED" || true
else
  > "$TRNA_BED"
fi

# Extract tRNA coordinates from GFF if available
GFF_TRNA_BED="$MODULE_DIR/${SAMPLE_NAME}_tRNAs_from_gff.bed"
if grep -q "tRNA" "$GFF" 2>/dev/null; then
  grep "tRNA" "$GFF" | \
    awk -F'\t' '{print $1, $4-1, $5, "tRNA", ".", $7}' OFS='\t' > "$GFF_TRNA_BED" || true
else
  > "$GFF_TRNA_BED"
fi

# Extract rRNA coordinates
RRNA_BED="$MODULE_DIR/${SAMPLE_NAME}_rRNAs.bed"
if grep -q "rRNA" "$GFF" 2>/dev/null; then
  grep "rRNA" "$GFF" | \
    awk -F'\t' '{print $1, $4-1, $5, "rRNA", ".", $7}' OFS='\t' > "$RRNA_BED" || true
else
  > "$RRNA_BED"
fi

# Extract all CDS coordinates for later overlap checking
CDS_BED="$MODULE_DIR/${SAMPLE_NAME}_CDS.bed"
if grep -q "CDS" "$GFF" 2>/dev/null; then
  grep "CDS" "$GFF" | \
    awk -F'\t' '{print $1, $4-1, $5, "CDS", ".", $7}' OFS='\t' > "$CDS_BED" || true
else
  > "$CDS_BED"
fi

# Calculate genome statistics
log_info "Calculating annotation statistics..."

STATS_FILE="$MODULE_DIR/${SAMPLE_NAME}_annotation_stats.txt"
{
  echo "=== Annotation Statistics for $SAMPLE_NAME ==="
  echo "Total sequences: $(grep -c "^>" "$GENOME_FA")"
  echo "Total CDS: $(grep -c "CDS" "$GFF" 2>/dev/null || echo 0)"
  echo "Total rRNA: $(grep -c "rRNA" "$GFF" 2>/dev/null || echo 0)"
  echo "Total tRNA: $(grep -c "tRNA" "$GFF" 2>/dev/null || echo 0)"
  echo "Proteins predicted: $(grep -c "^>" "$PROTEINS" 2>/dev/null || echo 0)"
  echo "GC content: $(calculate_gc_content "$GENOME_FA")%"
} > "$STATS_FILE"

cat "$STATS_FILE"

# Validate outputs
check_output "$GFF" 1 || die "GFF output not created"
check_output "$PROTEINS" 1 || log_warn "Protein output not created"

log_success "Module 01 complete"
log_info "Outputs:"
log_info "  GFF: $(basename $GFF)"
log_info "  Proteins: $(basename $PROTEINS)"
log_info "  tRNAs: $(basename $TRNA_BED)"
log_info "  rRNAs: $(basename $RRNA_BED)"
log_info "  CDS: $(basename $CDS_BED)"
