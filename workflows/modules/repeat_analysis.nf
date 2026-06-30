process REPEAT_ANALYSIS {
    tag "minced on ${sample_id}"
    label 'process_low'
    
    conda 'bioconda::minced=0.4.2'
    
    publishDir "${params.outdir}/${sample_id}/repeats", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("crispr.out"), emit: crispr
    path "crispr.out"

    script:
    """
    minced ${fasta} crispr.out || echo "No CRISPR arrays found" > crispr.out
    """
}
