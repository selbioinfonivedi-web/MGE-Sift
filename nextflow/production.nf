#!/usr/bin/env nextflow
/*
 * MGE-Sift Production Pipeline
 * Detects and classifies mobile genetic elements in bacterial genomes
 * 
 * Author: Bioinformatics Team
 * Version: 2.0.0
 * License: MIT
 */

nextflow.enable.dsl=2

// ============================================================================
// PARAMETERS & CONFIGURATION
// ============================================================================

params {
  // Input/Output
  input          = null
  sample_sheet   = null
  outdir         = "${projectDir}/results"
  
  // Resource allocation
  max_cpus       = 4
  max_memory_gb  = 8
  max_time       = '24h'
  
  // Pipeline configuration
  config         = "${projectDir}/config/mge_pipeline.cfg"
  db_path        = "${projectDir}/databases"
  
  // Execution control
  skip_annotation = false
  skip_plasmid    = false
  skip_prophage   = false
  skip_amr        = false
  
  // Cloud/HPC
  cloud_provider = null  // aws, gcp, azure
  cloud_region   = null
  
  // API integration
  api_server     = null
  api_token      = null
  
  // Logging & reporting
  publish_dir    = "${params.outdir}/published"
  log_dir        = "${params.outdir}/logs"
  report_html    = true
  
  // Testing
  test_mode      = false
  sample_limit   = null
}

// ============================================================================
// SETUP & VALIDATION
// ============================================================================

include { validate_inputs } from './modules/validation.nf'
include { setup_environment } from './modules/setup.nf'

// Validate parameters at startup
if (!params.input && !params.sample_sheet) {
  error """
  ╭─────────────────────────────────────────────────╮
  │ ERROR: No input specified                       │
  │ Provide either:                                 │
  │  --input <genome_path or *.fa files>            │
  │  --sample_sheet <CSV with sample_id,fasta_path> │
  ╰─────────────────────────────────────────────────╯
  """
}

// ============================================================================
// WORKFLOW DEFINITION
// ============================================================================

workflow {
  log.info """
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                     MGE-Sift Production Pipeline v2.0                      ║
  ║                  Mobile Genetic Element Detection                          ║
  ╚════════════════════════════════════════════════════════════════════════════╝
  
  Input directory:       ${params.input ?: params.sample_sheet}
  Output directory:      ${params.outdir}
  Config file:           ${params.config}
  Database path:         ${params.db_path}
  CPU cores:             ${params.max_cpus}
  Memory (GB):           ${params.max_memory_gb}
  Max runtime:           ${params.max_time}
  """.stripIndent()

  // Setup and validation
  setup_environment()
  validate_inputs(params.input, params.sample_sheet)

  // Prepare sample channel
  samples_ch = prepare_samples()

  // Apply sample limit for testing
  if (params.test_mode && params.sample_limit) {
    samples_ch = samples_ch.take(params.sample_limit)
  }

  // Main pipeline stages
  ANNOTATION_STAGE(samples_ch)
  PLASMID_STAGE(ANNOTATION_STAGE.out)
  IS_ELEMENT_STAGE(ANNOTATION_STAGE.out)
  INTEGRON_STAGE(ANNOTATION_STAGE.out)
  PROPHAGE_STAGE(ANNOTATION_STAGE.out)
  GENOMIC_ISLAND_STAGE(ANNOTATION_STAGE.out)
  REPEAT_STAGE(ANNOTATION_STAGE.out)
  HGT_SIGNALS_STAGE(ANNOTATION_STAGE.out)
  AMR_STAGE(ANNOTATION_STAGE.out)

  // Integration and reporting
  INTEGRATION_STAGE(
    ANNOTATION_STAGE.out,
    PLASMID_STAGE.out,
    IS_ELEMENT_STAGE.out,
    INTEGRON_STAGE.out,
    PROPHAGE_STAGE.out,
    GENOMIC_ISLAND_STAGE.out,
    REPEAT_STAGE.out,
    HGT_SIGNALS_STAGE.out,
    AMR_STAGE.out
  )

  // Generate reports
  GENERATE_REPORTS(INTEGRATION_STAGE.out)

  // Optional: Push to API
  if (params.api_server) {
    PUBLISH_RESULTS(GENERATE_REPORTS.out)
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

def prepare_samples() {
  samples = []
  
  if (params.sample_sheet) {
    // Load from sample sheet (CSV format)
    samples_file = file(params.sample_sheet)
    if (!samples_file.exists()) {
      error "Sample sheet not found: ${params.sample_sheet}"
    }
    samples = Channel.fromPath(samples_file)
      .splitCsv(header: true)
      .map { row ->
        [row.sample_id, file(row.fasta_path)]
      }
  } else {
    // Scan input directory for FASTA files
    input_dir = file(params.input)
    if (!input_dir.exists()) {
      error "Input directory not found: ${params.input}"
    }
    
    samples = Channel.fromPath("${input_dir}/*.{fa,fasta,fna,fa.gz,fasta.gz,fna.gz}", checkIfExists: true)
      .map { genome ->
        def sample_id = genome.baseName.replaceAll(/\.(fa|fasta|fna)(\.gz)?$/, '')
        [sample_id, genome]
      }
  }
  
  return samples
}

// ============================================================================
// PIPELINE MODULES (Import from modular files)
// ============================================================================

include { ANNOTATION_STAGE } from './modules/annotation.nf'
include { PLASMID_STAGE } from './modules/plasmid.nf'
include { IS_ELEMENT_STAGE } from './modules/is_elements.nf'
include { INTEGRON_STAGE } from './modules/integrons.nf'
include { PROPHAGE_STAGE } from './modules/prophages.nf'
include { GENOMIC_ISLAND_STAGE } from './modules/genomic_islands.nf'
include { REPEAT_STAGE } from './modules/repeats.nf'
include { HGT_SIGNALS_STAGE } from './modules/hgt_signals.nf'
include { AMR_STAGE } from './modules/amr_detection.nf'
include { INTEGRATION_STAGE } from './modules/integration.nf'
include { GENERATE_REPORTS } from './modules/reporting.nf'
include { PUBLISH_RESULTS } from './modules/api_push.nf'

// ============================================================================
// WORKFLOW COMPLETION HANDLER
// ============================================================================

workflow.onComplete {
  log.info """
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                         Pipeline Execution Complete                        ║
  ║                        Status: ${workflow.success ? 'SUCCESS' : 'FAILED'}
  ║                   Duration: ${workflow.duration}
  ║                   Results:  ${params.outdir}
  ╚════════════════════════════════════════════════════════════════════════════╝
  """.stripIndent()

  if (workflow.success) {
    log.info "✓ All samples processed successfully"
  } else {
    log.error "✗ Pipeline failed. Check logs: ${params.log_dir}"
    exit 1
  }
}

workflow.onError {
  log.error "✗ Workflow execution stopped with the following message:"
  log.error "  ${workflow.errorMessage}"
}
