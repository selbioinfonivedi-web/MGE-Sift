process INTEGRON_DETECTION {
    tag "${sample_id}"
    label 'process_medium'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/integrons", mode: 'copy'
    conda "bioconda::integron_finder=2.0.2"
    
    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("Results_Integron_Finder_${fasta.baseName}/${fasta.baseName}.integrons"), emit: results
    path "${sample_id}_integronfinder_version.txt", emit: version
    
    script:
    """
    mkdir -p Results_Integron_Finder_${fasta.baseName}
    touch Results_Integron_Finder_${fasta.baseName}/${fasta.baseName}.summary
    if [ ! -s "${fasta}" ]; then
        echo "Error: Input FASTA is empty" >&2
        exit 1
    fi
    
    integron_finder --local-max --cpu ${task.cpus} ${fasta} || true
    
    # Version capture
    integron_finder --version > ${sample_id}_integronfinder_version.txt 2>&1 || true
    """
}
