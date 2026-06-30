process PLASMID_DETECTION {
    tag "$genome.baseName"
    publishDir "${params.outdir}/plasmids", mode: 'copy'
    
    conda "bioconda::mob_suite=3.1.0"
    
    cpus 4
    memory '8 GB'

    input:
    path genome

    output:
    path "${genome.baseName}_mobtyper.txt", emit: results
    
    script:
    """
    mob_typer --infile $genome --out_file ${genome.baseName}_mobtyper.txt --num_threads ${task.cpus}
    """
}
