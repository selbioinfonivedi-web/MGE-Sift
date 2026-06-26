/*
 * Integration and unified analysis module
 */

process INTEGRATION_STAGE {
  tag "integration"
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/integration", mode: 'copy'
  
  input:
  tuple val(sample), path(genome), path(annotation)
  tuple val(sample), path(plasmids)
  tuple val(sample), path(is_elements)
  tuple val(sample), path(integrons)
  tuple val(sample), path(prophages)
  tuple val(sample), path(islands)
  tuple val(sample), path(repeats)
  tuple val(sample), path(hgt)
  tuple val(sample), path(amr)
  
  output:
  tuple val(sample), path("${sample}_mge_*"), emit: integrated
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  python3 ${projectDir}/modules/10_integration.py \
    --sample ${sample} \
    --config ${config_path} \
    --outdir ${params.outdir} \
    --genome ${genome} \
    --annotation ${annotation} \
    --plasmids ${plasmids} \
    --is_elements ${is_elements} \
    --integrons ${integrons} \
    --prophages ${prophages} \
    --islands ${islands} \
    --repeats ${repeats} \
    --hgt_signals ${hgt} \
    --amr ${amr}
  """
}
