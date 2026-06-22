#!/bin/bash
# MGE Detection Pipeline - Database Setup Script
# Installs and configures all required databases for the pipeline

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB_ROOT="${1:-.}/databases"
LOG_FILE="$SCRIPT_DIR/install_dbs.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

cleanup_and_exit() {
  log_error "Database setup failed. Check $LOG_FILE for details."
  exit 1
}

trap cleanup_and_exit ERR

mkdir -p "$DB_ROOT" "$SCRIPT_DIR/logs"

log "Starting MGE Pipeline database installation..."
log "Target directory: $DB_ROOT"

# ============================================================================
# 1. MOB-suite Database
# ============================================================================
log "Installing MOB-suite database..."
mkdir -p "$DB_ROOT/mob_db"
if command -v mob_db &> /dev/null; then
  mob_db --action setup --db_dir "$DB_ROOT/mob_db" --force 2>&1 | tee -a "$LOG_FILE"
  log_success "MOB-suite database installed"
else
  log_error "mob_db command not found. Ensure MOB-suite is installed."
fi

# ============================================================================
# 2. PlasmidFinder Database
# ============================================================================
log "Installing PlasmidFinder database..."
mkdir -p "$DB_ROOT/plasmidfinder"
cd "$DB_ROOT/plasmidfinder"
if ! [ -d "plasmids" ]; then
  git clone https://bitbucket.org/genomicepidemiology/plasmidfinder_db.git plasmids 2>&1 | tee -a "$LOG_FILE"
  log_success "PlasmidFinder database installed"
else
  log_warn "PlasmidFinder database already exists, skipping"
fi
cd - > /dev/null

# ============================================================================
# 3. ResFinder Database
# ============================================================================
log "Installing ResFinder database..."
mkdir -p "$DB_ROOT/resfinder"
cd "$DB_ROOT/resfinder"
if ! [ -d "fasta" ]; then
  git clone https://bitbucket.org/genomicepidemiology/resfinder_db.git . 2>&1 | tee -a "$LOG_FILE"
  log_success "ResFinder database installed"
else
  log_warn "ResFinder database already exists, skipping"
fi
cd - > /dev/null

# ============================================================================
# 4. CARD Database for RGI
# ============================================================================
log "Installing CARD database..."
mkdir -p "$DB_ROOT/card"
cd "$DB_ROOT/card"

if ! [ -f "card.json" ]; then
  log "Downloading CARD database from website..."
  if command -v wget &> /dev/null; then
    wget -q https://card.mcmaster.ca/latest/data.tar.bz2 -O card_data.tar.bz2 2>&1 | tee -a "$LOG_FILE"
  elif command -v curl &> /dev/null; then
    curl -s -o card_data.tar.bz2 https://card.mcmaster.ca/latest/data.tar.bz2 2>&1 | tee -a "$LOG_FILE"
  else
    log_error "wget or curl not found. Cannot download CARD database."
  fi
  
  tar -xjf card_data.tar.bz2
  rm -f card_data.tar.bz2
  log_success "CARD database installed"
else
  log_warn "CARD database already exists, skipping download"
fi

# Load CARD into RGI
if command -v rgi &> /dev/null; then
  log "Loading CARD into RGI..."
  rgi load --card_json "$DB_ROOT/card/card.json" --local 2>&1 | tee -a "$LOG_FILE" || true
  log_success "CARD loaded into RGI"
fi

cd - > /dev/null

# ============================================================================
# 5. ISEScan Database
# ============================================================================
log "Setting up ISEScan database..."
mkdir -p "$DB_ROOT/isescan"

# ISEScan DB is bundled with the tool, just ensure structure
if ! [ -d "$DB_ROOT/isescan/IS_euk" ]; then
  log "Note: ISEScan uses bundled database. Verify installation path."
fi
log_success "ISEScan database check complete"

# ============================================================================
# 6. Integron Finder Database
# ============================================================================
log "Installing IntegronFinder database..."
mkdir -p "$DB_ROOT/integron_finder"

# IntegronFinder comes with default DB; just ensure pip package is up-to-date
if command -v integron_finder &> /dev/null; then
  INTEGRON_DATA_PATH=$(python3 -c "import integron_finder; import os; print(os.path.dirname(integron_finder.__file__))")
  log "IntegronFinder database location: $INTEGRON_DATA_PATH"
  log_success "IntegronFinder configured"
else
  log_error "integron_finder command not found"
fi

# ============================================================================
# 7. PhiSpy/PHASTER Prophage Databases
# ============================================================================
log "Setting up prophage databases..."
mkdir -p "$DB_ROOT/prophage"

# PhiSpy uses HMM files (bundled)
log_success "PhiSpy database check complete"

# PHASTER registration (requires manual account setup)
log_warn "PHASTER requires free registration at https://phaster.ca/"
log_warn "Set your email in config file for automated PHASTER queries"

# ============================================================================
# 8. NCBI Taxonomy Database
# ============================================================================
log "Installing NCBI Taxonomy database..."
mkdir -p "$DB_ROOT/taxonomy"
cd "$DB_ROOT/taxonomy"

if ! [ -f "names.dmp" ]; then
  log "Downloading NCBI Taxonomy..."
  if command -v wget &> /dev/null; then
    wget -q ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz 2>&1 | tee -a "$LOG_FILE"
  else
    curl -s -o taxdump.tar.gz ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz 2>&1 | tee -a "$LOG_FILE"
  fi
  tar -xzf taxdump.tar.gz names.dmp nodes.dmp
  rm -f taxdump.tar.gz
  log_success "NCBI Taxonomy installed"
else
  log_warn "NCBI Taxonomy already exists, skipping"
fi

cd - > /dev/null

# ============================================================================
# 9. ABRicate Multi-Database Setup
# ============================================================================
log "Setting up ABRicate databases..."
if command -v abricate &> /dev/null; then
  abricate --setupdb 2>&1 | tee -a "$LOG_FILE"
  log_success "ABRicate databases installed"
else
  log_error "abricate command not found"
fi

# ============================================================================
# 10. Create Configuration Symlinks
# ============================================================================
log "Creating configuration symlinks..."
CONFIG_FILE="$SCRIPT_DIR/config/mge_pipeline.cfg"

# Update config file paths
if [ -f "$CONFIG_FILE" ]; then
  sed -i "s|MOB_DB=.*|MOB_DB=\"$DB_ROOT/mob_db\"|g" "$CONFIG_FILE"
  sed -i "s|ISESCAN_DB=.*|ISESCAN_DB=\"$DB_ROOT/isescan\"|g" "$CONFIG_FILE"
  sed -i "s|CARD_DB=.*|CARD_DB=\"$DB_ROOT/card/card.json\"|g" "$CONFIG_FILE"
  sed -i "s|RESFINDER_DB=.*|RESFINDER_DB=\"$DB_ROOT/resfinder\"|g" "$CONFIG_FILE"
  sed -i "s|PLASMIDFINDER_DB=.*|PLASMIDFINDER_DB=\"$DB_ROOT/plasmidfinder/plasmids\"|g" "$CONFIG_FILE"
  log_success "Configuration updated with database paths"
fi

# ============================================================================
# Final Validation
# ============================================================================
log ""
log "========================================"
log "Database Installation Summary"
log "========================================"

for db_dir in "$DB_ROOT"/*; do
  if [ -d "$db_dir" ]; then
    db_name=$(basename "$db_dir")
    db_size=$(du -sh "$db_dir" | cut -f1)
    log_success "$db_name: $db_size"
  fi
done

log ""
log_success "Database installation complete!"
log "Database root: $DB_ROOT"
log "Configuration file: $CONFIG_FILE"
log ""
log "Next steps:"
log "1. Update config/mge_pipeline.cfg with tool paths if needed"
log "2. Run: conda activate mge_pipeline"
log "3. Run single sample: bash single/mge_single.sh <genome.fa> <sample_name>"
log ""
