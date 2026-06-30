process INTEGRON_DETECTION {
    tag "integron_finder on ${sample_id}"
    label 'process_medium'
    
    // Use an exact Bioconda environment container for reproducibility
    conda 'bioconda::integron_finder=2.0.2'
    
    publishDir "${params.outdir}/${sample_id}/integrons", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("integrons.out"), emit: integrons
    path "integrons.out"

    script:
    """
    integron_finder --local-max --mute --func-annot --outdir . ${fasta}
    # IntegronFinder creates a folder named after the fasta file
    # We copy the main summary file to a standard name
    cp *.summary integrons.out || echo "No integrons found" > integrons.out
    """
}
