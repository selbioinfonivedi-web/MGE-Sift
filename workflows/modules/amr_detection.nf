process AMR_DETECTION {
    tag "${sample_id}"
    label 'process_medium'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/amr", mode: 'copy'
    conda "bioconda::abricate=1.0.1"
    
    input:
    tuple val(sample_id), path(fasta), path(gff)

    output:
    tuple val(sample_id), path("${sample_id}_abricate.tsv"), emit: results
    path "${sample_id}_abricate_version.txt", emit: version
    
    script:
    """
    touch ${sample_id}_abricate.tsv
    if [ ! -s "${fasta}" ]; then
        echo "Error: Input FASTA is empty" >&2
        exit 1
    fi
    
    abricate --check || true
    abricate --threads ${task.cpus} ${fasta} > ${sample_id}_abricate.tsv || true
    
    # Version capture
    abricate --version > ${sample_id}_abricate_version.txt 2>&1 || true
    """
}
