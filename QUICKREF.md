# MGE Pipeline - Quick Reference

## Installation & Setup

```bash
# 1. Create conda environment
conda env create -f environment.yml
conda activate mge_pipeline

# 2. Install and configure databases
bash scripts/install_dbs.sh ./databases

# 3. Update config file with database paths
nano config/mge_pipeline.cfg
```

## Running the Pipeline

### Single Sample
```bash
bash single/mge_single.sh genomes/sample.fa sample_name config/mge_pipeline.cfg
```

### Multiple Samples (Batch)
```bash
# Sequential (one at a time)
bash batch/mge_batch.sh ./genomes config/mge_pipeline.cfg

# Parallel (8 CPUs)
bash batch/mge_batch.sh ./genomes config/mge_pipeline.cfg --parallel 8
```

## Output Files

Located in `results/sample_name/10_integration/`:

| File | Description |
|------|-------------|
| `*_all_MGEs.bed` | All detected MGEs in BED format |
| `*_MGE_classification_report.tsv` | Main results with classification |
| `*_AMR_in_MGE.tsv` | Antimicrobial resistance genes in MGEs |

## Configuration

**Key parameters in `config/mge_pipeline.cfg`:**

```bash
ANNOTATION_TOOL=prokka              # Annotation method
ANNOTATION_CPUS=4                   # CPU threads
MOB_DB=/path/to/mob_db              # Plasmid database
CARD_DB=/path/to/card.json          # AMR database
GC_THRESHOLD_ACQUIRED=5             # GC deviation threshold
IS_THRESHOLD_ACQUIRED=3             # IS element scoring threshold
DEBUG_MODE=0                        # Verbose output
CLEANUP_INTERMEDIATE=0              # Keep temp files
```

## Classification Results

**MGE_classification_report.tsv columns:**

- **MGE_ID**: Unique element identifier
- **Type**: Element type (plasmid, IS, integron, prophage, island)
- **Classification**: ACQUIRED, INTRINSIC, or AMBIGUOUS
- **Origin**: "Acquired (HGT)" or "Intrinsic"
- **Confidence**: Score 0-1 (higher = more confident)

**Classification rules:**

| Element | ACQUIRED | INTRINSIC |
|---------|----------|-----------|
| IS | Score ≥3, intact transposase, TSDs | Truncated, no TSDs, single copy |
| Integron | Complete, cassettes present, intI+ | CALIN class, no intI |
| Prophage | GC deviation >5%, lytic genes | GC near host, remnants only |
| Island | GC >5% deviation, tRNA flanked | GC <2% deviation |
| Plasmid | Replicon type known (IncF, IncI) | Mobilizable only |

## Common Commands

```bash
# Validate pipeline setup
bash tests/test_pipeline.sh --full

# View results
cat results/sample_name/10_integration/sample_name_MGE_classification_report.tsv

# Quick summary (batch)
cat results/integration/cohort_*_summary.tsv

# Check specific module output
ls -la results/sample_name/03_IS_elements/

# View logs
tail -50 logs/sample_name_*.log

# Re-run specific module
bash modules/06_genomic_islands.sh genome.fa sample results/sample config/mge_pipeline.cfg

# Enable debug mode
DEBUG_MODE=1 bash single/mge_single.sh genome.fa sample config/mge_pipeline.cfg
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tool not found | `conda install -c bioconda <tool_name>` |
| Database error | `bash scripts/install_dbs.sh ./databases` |
| Slow performance | Reduce `ANNOTATION_CPUS` or `--parallel` workers |
| Empty outputs | Check `logs/` for errors; enable `DEBUG_MODE=1` |
| Memory error | Reduce CPU threads: `ANNOTATION_CPUS=2` |

## Performance Tips

- Use `--parallel 4-8` for batch processing (depends on CPU count)
- Set `CLEANUP_INTERMEDIATE=1` to save disk space
- Increase `ANNOTATION_CPUS` only if system has >8 cores
- For large batches, split into groups of 10-20 samples

## Module Summary

| # | Module | Input | Output | Time |
|---|--------|-------|--------|------|
| 01 | Annotation | Genome FASTA | GFF, proteins | 5-10 min |
| 02 | Plasmids | Genome FASTA | BED, classification | 3-5 min |
| 03 | IS Elements | Genome FASTA | BED, scoring | 5-10 min |
| 04 | Integrons | Genome FASTA | BED, cassettes | 2-5 min |
| 05 | Prophages | Genome + GFF | BED, proteins | 10-15 min |
| 06 | Islands | Genome FASTA | BED, GC analysis | 5-10 min |
| 07 | Repeats | Genome FASTA | BED | 3-5 min |
| 08 | HGT Signals | Genome + GFF | Integrated scores | 5 min |
| 09 | AMR | Genome | BED, classification | 10-20 min |
| 10 | Integration | All results | Unified report | <1 min |

## Important Files

```
MGE_Bio/
├── config/mge_pipeline.cfg     ← Customize this
├── README.md                    ← Full documentation
├── QUICKREF.md                  ← This file
├── environment.yml              ← Conda spec
├── scripts/install_dbs.sh       ← Run once after conda setup
├── single/mge_single.sh         ← Main entry point (single sample)
├── batch/mge_batch.sh           ← Main entry point (multiple samples)
└── modules/                     ← 10 detection modules
```

## Citation

If using this pipeline, cite:
- **Pipeline**: MGE Detection Pipeline v1.0
- **Prokka**: Seemann T (2014)
- **MOB-suite**: Robertson et al (2020)
- **ISEScan**: Xie & Tang (2017)
- **IntegronFinder**: Cury et al (2016)
- **PhiSpy**: Akhter et al (2013)
- **RGI**: Alcock et al (2020)
- **ABRicate**: Seemann T

## Getting Help

1. **Check logs**: `tail -100 logs/*.log`
2. **Validate setup**: `bash tests/test_pipeline.sh --full`
3. **Enable debug**: `DEBUG_MODE=1` in config
4. **Check config**: `cat config/mge_pipeline.cfg | grep -E "^[A-Z].*="`
5. **Test single module**: `bash modules/01_annotation.sh test.fa TEST results config/mge_pipeline.cfg`

---

**Version**: 1.0  
**Status**: Production-Ready  
**Last Updated**: 2026-06-22
