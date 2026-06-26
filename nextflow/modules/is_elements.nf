/*
 * IS element detection module
 */

process IS_ELEMENT_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/is_elements", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation), emit: annotated
  
  output:
  tuple val(sample), path("${sample}_is_elements.*"), emit: is_elements
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  bash ${projectDir}/modules/03_is_elements.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  """
}
