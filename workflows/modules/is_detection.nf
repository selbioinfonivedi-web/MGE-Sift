process IS_DETECTION {
    tag "${sample_id}"
    label 'process_high'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/is_elements", mode: 'copy'
    conda "bioconda::isescan=1.7.2.3"
    
    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("prediction/${fasta.baseName}.fa.csv"), emit: results
    path "${sample_id}_isescan_version.txt", emit: version
    
    script:
    """
    mkdir -p prediction
    touch prediction/${fasta.baseName}.fa.csv
    if [ ! -s "${fasta}" ]; then
        echo "Error: Input FASTA is empty" >&2
        exit 1
    fi
    
    isescan.py --seqfile ${fasta} --output prediction --nthread ${task.cpus} || true
    
    # Version capture
    isescan.py --version > ${sample_id}_isescan_version.txt 2>&1 || true
    """
}
