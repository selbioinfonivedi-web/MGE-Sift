process AMR_DETECTION {
    tag "amrfinder on ${sample_id}"
    label 'process_medium'
    
    conda 'bioconda::ncbi-amrfinderplus=3.11.18'
    
    publishDir "${params.outdir}/${sample_id}/amr", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta), path(gff)

    output:
    tuple val(sample_id), path("amr_results.tsv"), emit: amr
    path "amr_results.tsv"

    script:
    """
    amrfinder -n ${fasta} -g ${gff} --threads ${task.cpus} > amr_results.tsv
    """
}
