#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Import modules
include { ANNOTATE_GENOME } from './modules/annotation.nf'
include { PLASMID_DETECTION } from './modules/plasmid_detection.nf'
include { IS_DETECTION } from './modules/is_detection.nf'
include { MGE_INTEGRATION } from './modules/integration.nf'

workflow {
    // Input channels
    genomes_ch = Channel.fromPath(params.genomes)

    // 1. Genome Annotation
    ANNOTATE_GENOME(genomes_ch)

    // 2. Plasmid Detection
    PLASMID_DETECTION(genomes_ch)

    // 3. IS Detection
    IS_DETECTION(genomes_ch)

    // Final Integration
    MGE_INTEGRATION(
        ANNOTATE_GENOME.out.gff,
        PLASMID_DETECTION.out.results,
        IS_DETECTION.out.results
    )
}
