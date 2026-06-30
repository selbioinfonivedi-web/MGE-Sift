#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Import modules
include { ANNOTATION } from './modules/annotation.nf'
include { PLASMID_DETECTION } from './modules/plasmid_detection.nf'
include { IS_DETECTION } from './modules/is_detection.nf'
include { INTEGRON_DETECTION } from './modules/integron_detection.nf'
include { PROPHAGE_DETECTION } from './modules/prophage_detection.nf'
include { AMR_DETECTION } from './modules/amr_detection.nf'
include { GENOMIC_ISLAND_DETECTION } from './modules/genomic_island_detection.nf'
include { REPEAT_ANALYSIS } from './modules/repeat_analysis.nf'
include { INTEGRATION } from './modules/integration.nf'

workflow {
    fasta_ch = Channel.fromPath(params.input).map { file -> tuple(file.baseName, file) }

    // 1. Core Annotation
    annotated_ch = ANNOTATION(fasta_ch)

    // 2. Parallel MGE & AMR Detection
    plasmids_ch = PLASMID_DETECTION(fasta_ch)
    is_ch = IS_DETECTION(fasta_ch)
    integrons_ch = INTEGRON_DETECTION(fasta_ch)
    repeats_ch = REPEAT_ANALYSIS(fasta_ch)
    
    // Tools requiring Annotation outputs (GFF/GBK)
    prophages_ch = PROPHAGE_DETECTION(annotated_ch.gbk)
    islands_ch = GENOMIC_ISLAND_DETECTION(annotated_ch.gbk)
    
    // Combine fasta and gff for AMRFinder
    amr_input_ch = fasta_ch.join(annotated_ch.gff)
    amr_ch = AMR_DETECTION(amr_input_ch)

    // 3. Aggregate all results based on sample_id
    gathered_ch = annotated_ch.gff
        .join(plasmids_ch)
        .join(is_ch)
        .join(integrons_ch)
        .join(prophages_ch)
        .join(islands_ch)
        .join(repeats_ch)
        .join(amr_ch)

    INTEGRATION(gathered_ch)
}
