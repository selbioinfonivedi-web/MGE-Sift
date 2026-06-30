process PROPHAGE_DETECTION {
    tag "phispy on ${sample_id}"
    label 'process_high'
    
    // Prophage detection often requires significant memory
    cpus 4
    memory '8 GB'
    errorStrategy 'retry'
    maxRetries 2

    conda 'bioconda::phispy=4.2.21'
    
    publishDir "${params.outdir}/${sample_id}/prophages", mode: 'copy'

    input:
    tuple val(sample_id), path(gbk) // PhiSpy takes GenBank format (from Prokka)

    output:
    tuple val(sample_id), path("prophages.tsv"), emit: prophages
    path "prophages.tsv"

    script:
    """
    PhiSpy.py -o phispy_out -i ${gbk} --threads ${task.cpus}
    cp phispy_out/prophage_coordinates.tsv prophages.tsv || echo "No prophages found" > prophages.tsv
    """
}
