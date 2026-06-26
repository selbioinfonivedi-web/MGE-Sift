/*
 * Horizontal gene transfer signals detection module
 */

process HGT_SIGNALS_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/hgt_signals", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation), emit: annotated
  
  output:
  tuple val(sample), path("${sample}_hgt_signals.*"), emit: hgt_signals
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  bash ${projectDir}/modules/08_hgt_signals.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  """
}
