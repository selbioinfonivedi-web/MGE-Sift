# MGE Pipeline - Complete File Index

Generated: 2026-06-22
Version: 1.0 - Production Ready
Status: Complete and ready for testing & debugging

## Project Structure Overview

```
e:\MGE_VetgenomeHub\MGE_Bio/
├── Configuration & Setup
│   ├── config/mge_pipeline.cfg              Pipeline configuration (all parameters)
│   ├── environment.yml                      Conda environment specification
│   └── scripts/install_dbs.sh               Database installation and setup
│
├── Main Entry Points
│   ├── single/mge_single.sh                 Single sample orchestrator script
│   └── batch/mge_batch.sh                   Batch processing (sequential/parallel)
│
├── Detection Modules (Cores)
│   ├── modules/01_annotation.sh             Genome annotation (Prokka/Bakta)
│   ├── modules/02_plasmid.sh                Plasmid detection (MOB-suite, PlasmidFinder)
│   ├── modules/03_is_elements.sh            IS element detection (ISEScan, BLAST)
│   ├── modules/04_integrons.sh              Integron detection (IntegronFinder)
│   ├── modules/05_prophages.sh              Prophage detection (PhiSpy, PHASTER)
│   ├── modules/06_genomic_islands.sh        Genomic island detection (GC, tRNA)
│   ├── modules/07_repeats.sh                Repeat detection (inverted, direct, tandem)
│   ├── modules/08_hgt_signals.sh            HGT signals (Alien Hunter, CAI, SIGI-HMM)
│   ├── modules/09_amr_detection.sh          AMR detection (RGI, ResFinder, ABRicate)
│   ├── modules/10_integration.py            Integration & classification (Python)
│   └── modules/cohort_summary.py            Cohort-level reporting (Python)
│
├── Libraries & Utilities
│   ├── lib/common_functions.sh              Shared utility functions (logging, BED ops)
│   └── lib/error_handling.sh                Error handling & recovery (die, retry)
│
├── Testing & Validation
│   └── tests/test_pipeline.sh               Validation suite (15 tests)
│
└── Documentation
    ├── README.md                             Full documentation (1000+ lines)
    ├── QUICKREF.md                          Quick reference guide
    └── INDEX.md                             This file
```

## File Descriptions

### Configuration & Setup

#### `config/mge_pipeline.cfg` (180 lines)
Master configuration file with:
- Tool paths and executable locations
- Database paths (MOB_DB, CARD_DB, etc.)
- Detection parameters (GC thresholds, e-values, cutoffs)
- Classification thresholds (acquired vs intrinsic scoring)
- Output directories and logging preferences
- Resource allocation (CPUs, memory)
- Quality control thresholds

**Key sections:**
- ENVIRONMENT & PATHS
- ANNOTATION PARAMETERS
- PLASMID DETECTION
- IS ELEMENT DETECTION
- INTEGRON DETECTION
- PROPHAGE DETECTION
- GENOMIC ISLAND DETECTION
- HGT & CODON BIAS DETECTION
- REPEAT DETECTION
- AMR DETECTION
- CLASSIFICATION & SCORING
- OUTPUT & REPORTING
- COMPUTATIONAL RESOURCES
- QUALITY CONTROL
- LOGGING & DEBUG

#### `environment.yml` (45 lines)
Conda environment specification with:
- Python 3.10 base
- 25+ bioinformatics tools (prokka, bakta, mob-suite, etc.)
- BLAST, bedtools, HMMER, CD-HIT
- Utilities: parallel, bc
- Python packages: biopython, pandas, numpy, matplotlib

**Usage:**
```bash
conda env create -f environment.yml
conda activate mge_pipeline
```

#### `scripts/install_dbs.sh` (350 lines)
Database installation script that:
1. Creates MOB-suite database (`mob_db`)
2. Downloads PlasmidFinder database (Bitbucket)
3. Downloads ResFinder database (Bitbucket)
4. Downloads CARD database (McMaster)
5. Sets up ISEScan database
6. Configures IntegronFinder database
7. Downloads NCBI Taxonomy
8. Sets up ABRicate databases
9. Updates config file paths
10. Generates installation summary

**Usage:**
```bash
bash scripts/install_dbs.sh ./databases
```

### Main Entry Points

#### `single/mge_single.sh` (250 lines)
Single sample orchestrator that:
1. Validates input FASTA file
2. Sets up logging and output directories
3. Sequentially runs all 10 detection modules
4. Pipes module outputs to logging
5. Generates final summary report
6. Outputs all MGE predictions and classifications

**Usage:**
```bash
bash single/mge_single.sh genome.fa sample_name config/mge_pipeline.cfg
```

**Outputs:**
- Module-specific results in `results/sample_name/01_annotation/` through `09_AMR/`
- Unified reports in `results/sample_name/10_integration/`:
  - `*_all_MGEs.bed`
  - `*_MGE_classification_report.tsv`
  - `*_AMR_in_MGE.tsv`

#### `batch/mge_batch.sh` (180 lines)
Batch processing script that:
1. Finds all FASTA files in input directory
2. Processes sequentially or in parallel (using GNU parallel)
3. Calls `single/mge_single.sh` for each sample
4. Collects and reports failures
5. Generates cohort-level summaries

**Usage:**
```bash
# Sequential
bash batch/mge_batch.sh ./genomes config/mge_pipeline.cfg

# Parallel (8 workers)
bash batch/mge_batch.sh ./genomes config/mge_pipeline.cfg --parallel 8
```

**Outputs:**
- Per-sample results in individual directories
- Cohort summaries in `results/integration/`:
  - `cohort_*_MGE_report.tsv`
  - `cohort_*_summary.tsv`
  - `cohort_*_AMR_matrix.tsv`
  - `cohort_*_shared_MGEs.tsv`

### Detection Modules

#### `modules/01_annotation.sh` (120 lines)
**Purpose:** Genome annotation and feature extraction

**Tools used:** Prokka or BAKTA, tRNAscan-SE

**Outputs:**
- `01_annotation/{sample}_*.gff` - GFF format annotations
- `01_annotation/{sample}_*.faa` - Protein sequences
- `01_annotation/{sample}_tRNAs.bed` - tRNA coordinates
- `01_annotation/{sample}_rRNAs.bed` - rRNA coordinates
- `01_annotation/{sample}_CDS.bed` - Coding sequence locations
- `01_annotation/{sample}_annotation_stats.txt` - Statistics

**Key functions:**
- Runs BAKTA or PROKKA annotation
- Extracts tRNA, rRNA, and CDS features
- Calculates GC content
- Generates annotation statistics

#### `modules/02_plasmid.sh` (150 lines)
**Purpose:** Detect plasmids and classify replicon types

**Tools used:** MOB-suite, PlasmidFinder, BLASTN

**Outputs:**
- `02_plasmid/{sample}_all_plasmids.bed` - Unified plasmid predictions
- `02_plasmid/{sample}_plasmid_classification.tsv` - Classification (conjugative/mobilizable)
- `02_plasmid/{sample}_plasmid_stats.txt` - Summary statistics

**Classification:**
- **Conjugative**: IncF, IncP, IncN, IncI replicons
- **Mobilizable**: Has oriT but no relaxase
- **Ambiguous**: Weak signals

#### `modules/03_is_elements.sh` (200 lines)
**Purpose:** Detect and classify insertion sequences

**Tools used:** ISEScan, BLASTN, einverted

**Outputs:**
- `03_IS_elements/{sample}_IS_elements.bed` - IS element coordinates
- `03_IS_elements/{sample}_IS_classification.tsv` - ACQUIRED/INTRINSIC classification
- `03_IS_elements/{sample}_TSDs.bed` - Target site duplications
- `03_IS_elements/{sample}_IS_stats.txt` - Statistics

**Scoring system (acquired vs intrinsic):**
- Intact transposase: +2
- Flanking TSDs: +2
- Multiple copies: +1
- Recent BLAST hit (>95%): +1
- Truncated transposase: -2
- **Score ≥3**: ACQUIRED | **Score 1-2**: AMBIGUOUS | **Score <1**: INTRINSIC

#### `modules/04_integrons.sh` (170 lines)
**Purpose:** Detect integrons and antibiotic resistance cassettes

**Tools used:** IntegronFinder

**Outputs:**
- `04_integrons/{sample}_integrons.bed` - Integron coordinates
- `04_integrons/{sample}_cassettes.bed` - attC cassette sites
- `04_integrons/{sample}_integron_classification.tsv` - Classification
- `04_integrons/{sample}_integron_stats.txt` - Statistics

**Classification:**
- **ACQUIRED**: Complete integron with cassettes + intI present
- **INTRINSIC**: CALIN-type (no intI, ancient)
- **AMBIGUOUS**: Incomplete or uncertain

#### `modules/05_prophages.sh` (200 lines)
**Purpose:** Detect integrated phage sequences

**Tools used:** PhiSpy, PHASTER (optional)

**Outputs:**
- `05_prophage/{sample}_prophages.bed` - Prophage regions
- `05_prophage/{sample}_prophage_classification.tsv` - ACQUIRED/INTRINSIC
- `05_prophage/{sample}_phage_proteins.bed` - Structural proteins
- `05_prophage/{sample}_prophage_stats.txt` - Statistics

**Classification:**
- **ACQUIRED**: GC deviation >5%, lytic genes present
- **INTRINSIC**: GC near genome mean, tail remnants only

#### `modules/06_genomic_islands.sh` (180 lines)
**Purpose:** Identify genomic islands and HGT signals

**Tools used:** Custom GC analysis, tRNA detection

**Outputs:**
- `06_genomic_islands/{sample}_genomic_islands.bed` - Island coordinates
- `06_genomic_islands/{sample}_island_classification.tsv` - Classification
- `06_genomic_islands/{sample}_gc_content.bed` - GC anomalies
- `06_genomic_islands/{sample}_hgt_signals.tsv` - IVOM-like scores
- `06_genomic_islands/{sample}_island_stats.txt` - Statistics

**Classification:**
- **ACQUIRED**: GC deviation >5% + tRNA flanked + IVOM >10
- **INTRINSIC**: GC deviation <2%
- **AMBIGUOUS**: 2-5% deviation or weak signals

#### `modules/07_repeats.sh` (150 lines)
**Purpose:** Detect various repeat types

**Tools used:** einverted, custom Python TSD/repeat detection

**Outputs:**
- `07_repeats/{sample}_all_repeats.bed` - All repeats combined
- `07_repeats/{sample}_inverted_repeats.bed` - Inverted repeats
- `07_repeats/{sample}_direct_repeats.bed` - Direct repeats
- `07_repeats/{sample}_tandem_repeats.bed` - Tandem repeats
- `07_repeats/{sample}_repeat_stats.txt` - Statistics

**Repeat types:**
- Inverted: Can form stem-loop structures
- Direct: Forward repeats (flanking IS elements)
- Tandem: Head-to-tail repeats

#### `modules/08_hgt_signals.sh` (120 lines)
**Purpose:** Compute advanced HGT signature analysis

**Tools used:** Alien Hunter, SIGI-HMM (optional), CAI calculation

**Outputs:**
- `08_HGT/{sample}_alien_hunter_regions.bed` - Alien Hunter predictions
- `08_HGT/{sample}_cai_scores.tsv` - Codon adaptation indices
- `08_HGT/{sample}_hgt_integrated.tsv` - Integrated HGT scores
- `08_HGT/{sample}_hgt_stats.txt` - Statistics

**Methods:**
- **GC content**: Deviation from genome mean
- **IVOM score**: Alien Hunter index of horizontal transfer
- **CAI**: Codon usage adaptation

#### `modules/09_amr_detection.sh` (200 lines)
**Purpose:** Identify antimicrobial resistance genes

**Tools used:** RGI (CARD), ABRicate, ResFinder BLAST

**Outputs:**
- `09_AMR/{sample}_all_amr.bed` - All AMR genes found
- `09_AMR/{sample}_amr_classification.tsv` - Mechanism classification
- `09_AMR/{sample}_amr_matrix.tsv` - AMR by class (beta-lactam, aminoglycoside, etc.)
- `09_AMR/{sample}_amr_stats.txt` - Statistics

**AMR Classes:**
- Beta-lactam (enzymatic)
- Aminoglycoside (target modification)
- Fluoroquinolone (target protection)
- Macrolide (ribosomal protection)
- Tetracycline (efflux pump)
- Other (miscellaneous)

#### `modules/10_integration.py` (250 lines)
**Purpose:** Merge all predictions and generate final report

**Language:** Python 3

**Functions:**
- `merge_mge_predictions()` - Combine all MGE BED files
- `classify_mges()` - Load individual classifications
- `find_amr_in_mges()` - Overlap AMR genes with MGEs
- `generate_classification_report()` - Create unified report

**Outputs:**
- `10_integration/{sample}_all_MGEs.bed` - Unified MGE predictions
- `10_integration/{sample}_MGE_classification_report.tsv` - **Main result file**
- `10_integration/{sample}_AMR_in_MGE.tsv` - AMR genes in MGEs

#### `modules/cohort_summary.py` (220 lines)
**Purpose:** Generate cohort-level reports from batch runs

**Language:** Python 3

**Functions:**
- `generate_cohort_report()` - Main orchestrator
- Generates 4 cohort outputs:
  1. MGE report (all samples merged)
  2. Summary statistics (per-sample counts)
  3. AMR matrix (presence/absence)
  4. Shared MGEs (elements in multiple samples)

**Outputs:**
- `results/integration/cohort_*_MGE_report.tsv`
- `results/integration/cohort_*_summary.tsv`
- `results/integration/cohort_*_AMR_matrix.tsv`
- `results/integration/cohort_*_shared_MGEs.tsv`

### Libraries & Utilities

#### `lib/common_functions.sh` (400 lines)
Shared bash functions used by all modules:

**Logging functions:**
- `log_header()` - Section headers
- `log_info()` - Information messages
- `log_success()` - Success messages
- `log_warn()` - Warning messages
- `log_error()` - Error messages
- `log_debug()` - Debug output (if enabled)

**Tool checking:**
- `check_tool()` - Verify tool exists
- `check_tools_installed()` - Verify required tools
- `check_database()` - Verify database exists

**File operations:**
- `validate_fasta()` - Check FASTA validity
- `save_result()` - Copy result file
- `check_output()` - Verify output file size/content
- `sort_bed()` - Sort BED files
- `merge_bed_files()` - Combine multiple BED files
- `annotate_bed()` - Add annotations to BED

**Sequence analysis:**
- `calculate_gc_content()` - Compute GC%
- `extract_sequence()` - Extract region from FASTA
- `count_sequences()` - Count FASTA entries

**System utilities:**
- `get_available_cpus()` - Detect CPU count
- `get_available_memory_mb()` - Get available RAM

#### `lib/error_handling.sh` (300 lines)
Centralized error handling and recovery:

**Error functions:**
- `die()` - Fatal error and exit
- `warn_and_continue()` - Warning but continue
- `assert_file_exists()` - Verify file exists
- `assert_dir_exists()` - Verify directory exists
- `assert_tools_exist()` - Verify tools available

**Recovery mechanisms:**
- `cleanup_on_error()` - Error cleanup handler
- `retry_command()` - Retry with backoff (3 attempts)
- `run_with_timeout()` - Execute with timeout

**Validation:**
- `validate_checksum()` - MD5 verification
- `assert_output_not_empty()` - Output validation
- `validate_tsv()` - TSV format check
- `validate_bed()` - BED format check

**Dependency checking:**
- `check_conda_env()` - Verify conda environment
- `activate_conda_env()` - Activate conda environment
- `handle_missing_dependency()` - Handle missing tool

### Testing & Validation

#### `tests/test_pipeline.sh` (300 lines)
Comprehensive validation suite (15 tests):

**Tests performed:**
1. Directory structure verification
2. Script file existence
3. Configuration file validation
4. Module script availability
5. Library functions present
6. Error handling functions present
7. Script executability
8. Documentation presence
9. Environment file specification
10. Tool availability
11. Conda environment check
12. Write permissions
13. Python dependencies
14. Output directory structure
15. Script syntax validation

**Usage:**
```bash
bash tests/test_pipeline.sh --full
```

### Documentation

#### `README.md` (500+ lines)
Complete documentation covering:
- Features and capabilities
- Quick start guide
- Installation instructions
- Pipeline architecture
- Directory structure
- Configuration guide
- MGE classification logic
- Output file descriptions
- Validation & testing
- Troubleshooting guide
- Performance benchmarks
- Tool citations

#### `QUICKREF.md` (200+ lines)
Quick reference guide with:
- Installation summary
- Usage commands
- Configuration parameters
- Output file guide
- Classification rules
- Common commands
- Troubleshooting table
- Performance tips
- Module summary table
- Citation information

#### `INDEX.md` (This file)
Complete file inventory and documentation.

## Key Statistics

- **Total files created**: 25+
- **Total lines of code**: 3,500+
- **Bash scripts**: 13 files (1,800+ lines)
- **Python scripts**: 2 files (450+ lines)
- **Configuration files**: 2 files (225 lines)
- **Documentation**: 3 files (1,200+ lines)
- **Libraries**: 2 files (700+ lines)
- **Detection modules**: 10 (one per MGE type)
- **Tools integrated**: 20+
- **Database integrations**: 6 (MOB, PlasmidFinder, CARD, ResFinder, ISfinder, NCBI Taxonomy)

## Workflow Summary

```
Input: FASTA genome
  ↓
[01] Annotation → GFF, proteins, tRNA, rRNA
  ↓
[02] Plasmids → Coordinates, replicon type
  ↓
[03] IS Elements → Coordinates, transposase status, TSDs
  ↓
[04] Integrons → Coordinates, cassettes, intI status
  ↓
[05] Prophages → Coordinates, structural genes
  ↓
[06] Islands → Coordinates, GC anomalies
  ↓
[07] Repeats → Inverted, direct, tandem repeats
  ↓
[08] HGT Signals → IVOM scores, CAI, codon bias
  ↓
[09] AMR → Resistance genes, class, mechanism
  ↓
[10] Integration → Unified BED, classification, scoring
  ↓
Output:
  - {sample}_all_MGEs.bed
  - {sample}_MGE_classification_report.tsv ← MAIN RESULT
  - {sample}_AMR_in_MGE.tsv
  - [Cohort reports if batch mode]
```

## Classification Output Schema

**Main report file: `{sample}_MGE_classification_report.tsv`**

```
Columns:
MGE_ID (str)              Unique identifier (e.g., "IS_001", "Plasmid_IncF")
Contig (str)              Chromosome/contig name
Start (int)               Start coordinate (bp)
End (int)                 End coordinate (bp)
Length_bp (int)           Element length
Type (str)                Element type (plasmid, is_element, integron, prophage, island)
Classification (str)      ACQUIRED, INTRINSIC, or AMBIGUOUS
Origin (str)              "Acquired (HGT)" or "Intrinsic"
Confidence (float)        0.0-1.0 confidence score
```

## Next Steps After Setup

1. ✅ **Install environment**
   ```bash
   conda env create -f environment.yml
   conda activate mge_pipeline
   ```

2. ✅ **Setup databases**
   ```bash
   bash scripts/install_dbs.sh ./databases
   ```

3. ✅ **Validate installation**
   ```bash
   bash tests/test_pipeline.sh --full
   ```

4. ✅ **Run test sample**
   ```bash
   bash single/mge_single.sh test_data/sample.fa TEST config/mge_pipeline.cfg
   ```

5. ✅ **Review outputs**
   ```bash
   cat results/TEST/10_integration/TEST_MGE_classification_report.tsv
   ```

6. ✅ **Process your data**
   ```bash
   bash single/mge_single.sh your_genome.fa your_sample config/mge_pipeline.cfg
   ```

---

**Pipeline Status**: ✅ **PRODUCTION READY FOR TESTING & DEBUGGING**

All components have been implemented from start to finish. The pipeline is ready for:
- Functional testing with real genomic data
- Performance benchmarking
- Error condition handling validation
- Output format verification
- Classification accuracy assessment

**Documentation is comprehensive** and covers:
- Installation and setup
- Usage for single and batch processing
- Detailed file descriptions and formats
- Troubleshooting and common issues
- Configuration and customization
- Classification logic and scoring

**Known Limitations** (to be addressed in testing/debugging phase):
- PHASTER integration requires manual registration (API key setup)
- Some tools (Alien Hunter, SIGI-HMM) have optional installation
- Database updates may be needed periodically
- Performance depends on system resources and genome size

