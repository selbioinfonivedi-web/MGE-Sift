process IS_DETECTION {
    tag "$genome.baseName"
    publishDir "${params.outdir}/is_elements", mode: 'copy'
    
    conda "bioconda::isescan=1.7.2.3"
    
    cpus 4
    memory '8 GB'

    input:
    path genome

    output:
    path "${genome.baseName}.csv", emit: results
    
    script:
    """
    isescan.py --seqfile $genome --output ${genome.baseName} --nthread ${task.cpus}
    # Assuming ISEScan outputs a CSV, we move it to a predictable name
    mv ${genome.baseName}/*.csv ${genome.baseName}.csv
    """
}
