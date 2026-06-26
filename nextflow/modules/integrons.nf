/*
 * Integron detection module
 */

process INTEGRON_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/integrons", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation), emit: annotated
  
  output:
  tuple val(sample), path("${sample}_integrons.*"), emit: integrons
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  bash ${projectDir}/modules/04_integrons.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  """
}
