process PROPHAGE_DETECTION {
    tag "${sample_id}"
    label 'process_high'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/prophages", mode: 'copy'
    conda "bioconda::phispy=4.2.21"
    
    input:
    tuple val(sample_id), path(gbk)

    output:
    tuple val(sample_id), path("${sample_id}_phispy/prophage_coordinates.tsv"), emit: results
    path "${sample_id}_phispy_version.txt", emit: version
    
    script:
    """
    mkdir -p ${sample_id}_phispy
    touch ${sample_id}_phispy/prophage_coordinates.tsv
    if [ ! -s "${gbk}" ]; then
        echo "Error: Input GenBank file is empty" >&2
        exit 1
    fi
    
    PhiSpy.py ${gbk} -o ${sample_id}_phispy --threads ${task.cpus} || true
    
    # Version capture
    PhiSpy.py --version > ${sample_id}_phispy_version.txt 2>&1 || true
    """
}
