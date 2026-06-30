process GENOMIC_ISLAND_DETECTION {
    tag "islandpath on ${sample_id}"
    label 'process_low'
    
    conda 'bioconda::islandpath=1.0.6'
    
    publishDir "${params.outdir}/${sample_id}/genomic_islands", mode: 'copy'

    input:
    tuple val(sample_id), path(gbk)

    output:
    tuple val(sample_id), path("islands.out"), emit: islands
    path "islands.out"

    script:
    """
    Dimob.pl ${gbk} islands.out || echo "No islands found" > islands.out
    """
}
