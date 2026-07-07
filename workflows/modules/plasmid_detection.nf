process PLASMID_DETECTION {
    tag "${sample_id}"
    label 'process_medium'
    
    cpus 4
    memory '8 GB'
    time '4h'
    errorStrategy 'retry'
    maxRetries 2
    
    publishDir "${params.outdir}/plasmids", mode: 'copy'
    conda "bioconda::mob_suite=3.1.4"
    
    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("${sample_id}_mobtyper.txt"), emit: results
    path "${sample_id}_mobsuite_version.txt", emit: version
    
    script:
    """
    touch ${sample_id}_mobtyper.txt
    if [ ! -s "${fasta}" ]; then
        echo "Error: Input FASTA is empty" >&2
        exit 1
    fi
    
    mob_init || true
    mob_typer --infile ${fasta} --out_file ${sample_id}_mobtyper.txt || true
    
    # Version capture
    mob_typer --version > ${sample_id}_mobsuite_version.txt 2>&1 || true
    """
}
