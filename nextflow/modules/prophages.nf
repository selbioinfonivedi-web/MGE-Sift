/*
 * Prophage detection module
 */

process PROPHAGE_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/prophages", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation), emit: annotated
  
  output:
  tuple val(sample), path("${sample}_prophages.*"), emit: prophages
  
  when:
  !params.skip_prophage
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  bash ${projectDir}/modules/05_prophages.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  """
}
