/*
 * Plasmid detection module
 */

process PLASMID_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/plasmids", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation), emit: annotated
  
  output:
  tuple val(sample), path("${sample}_plasmids.*"), emit: plasmids
  
  when:
  !params.skip_plasmid
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  bash ${projectDir}/modules/02_plasmid.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  """
}
