process ANNOTATE_GENOME {
    tag "${sample_id}"
    label 'process_medium'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/annotation", mode: 'copy'
    conda "bioconda::prokka=1.14.6"
    
    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("${sample_id}.gff"), path("${sample_id}.gbk"), emit: gff
    path "${sample_id}_prokka_version.txt", emit: version
    
    script:
    """
    mkdir -p ~/.parallel
    touch ~/.parallel/will-cite
    
    # Remove broken conda parallel so it falls back to the system parallel
    rm -f \$(dirname \$(which prokka))/parallel

    if [ ! -s "${fasta}" ]; then
        echo "Error: Input FASTA is empty" >&2
        exit 1
    fi
    
    prokka --outdir . --prefix ${sample_id} --force --cpus 1 --fast ${fasta}
    
    # Version capture
    prokka --version > ${sample_id}_prokka_version.txt 2>&1 || true
    
    if [ ! -s "${sample_id}.gff" ]; then
        echo "Error: Prokka failed to generate valid GFF" >&2
        exit 1
    fi
    """
}