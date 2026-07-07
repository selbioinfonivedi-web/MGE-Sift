#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Import modules
include { ANNOTATE_GENOME as ANNOTATION } from './modules/annotation.nf'
include { PLASMID_DETECTION } from './modules/plasmid_detection.nf'
include { IS_DETECTION } from './modules/is_detection.nf'
include { INTEGRON_DETECTION } from './modules/integron_detection.nf'
include { PROPHAGE_DETECTION } from './modules/prophage_detection.nf'
include { GENOMIC_ISLAND_DETECTION } from './modules/genomic_island_detection.nf'
include { REPEAT_ANALYSIS } from './modules/repeat_analysis.nf'
include { AMR_DETECTION } from './modules/amr_detection.nf'
include { MGE_INTEGRATION as INTEGRATION } from './modules/integration.nf'

workflow {
    fasta_ch = Channel.fromPath(params.input).map { file -> tuple(file.baseName, file) }

    // 1. Core Annotation
    annotated_ch = ANNOTATION(fasta_ch)
    
    // Create specific channels for tools needing GFF/GBK
    gff_ch = annotated_ch.gff.map { sample, gff, gbk -> tuple(sample, gff) }
    gbk_ch = annotated_ch.gff.map { sample, gff, gbk -> tuple(sample, gbk) }

    // 2. Parallel MGE & AMR Detection
    plasmids_ch = PLASMID_DETECTION(fasta_ch)
    is_ch = IS_DETECTION(fasta_ch)
    integrons_ch = INTEGRON_DETECTION(fasta_ch)
    repeats_ch = REPEAT_ANALYSIS(fasta_ch)
    
    prophages_ch = PROPHAGE_DETECTION(gbk_ch)
    islands_ch = GENOMIC_ISLAND_DETECTION(gbk_ch)
    
    amr_input_ch = fasta_ch.join(gff_ch)
    amr_ch = AMR_DETECTION(amr_input_ch)

    // 3. Aggregate all results based on sample_id
    gathered_ch = gff_ch
        .join(plasmids_ch.results)
        .join(is_ch.results)
        .join(integrons_ch.results)
        .join(prophages_ch.results)
        .join(islands_ch.results)
        .join(repeats_ch.results)
        .join(amr_ch.results)

    INTEGRATION(gathered_ch)
}
