process ANNOTATE_GENOME {
    tag "$genome.baseName"
    publishDir "${params.outdir}/annotation", mode: 'copy'
    
    // Conda or Container directives for reproducibility
    conda "bioconda::prokka=1.14.6"
    
    cpus 4
    memory '8 GB'
    
    errorStrategy 'retry'
    maxRetries 3

    input:
    path genome

    output:
    path "${genome.baseName}/*.gff", emit: gff
    path "${genome.baseName}/*.fna", emit: fna
    
    script:
    """
    prokka --outdir ${genome.baseName} --prefix ${genome.baseName} --cpus ${task.cpus} $genome
    """
}
