/*
 * Genome annotation module
 */

process ANNOTATION_STAGE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/annotation", mode: 'copy'
  
  input:
  tuple val(sample), path(genome)
  
  output:
  tuple val(sample), path(genome), path("${sample}_annotation.*"), emit: annotated
  path "${sample}_annotation.gff", emit: gff
  
  script:
  def config_path = file(params.config).toString()
  """
  set -euo pipefail
  
  # Run annotation using existing pipeline
  bash ${projectDir}/modules/01_annotation.sh \
    "${genome}" \
    "${sample}" \
    "${config_path}" \
    "${params.outdir}"
  
  # Validate output
  if [ ! -f "${sample}_annotation.gff" ]; then
    echo "ERROR: Annotation failed for ${sample}"
    exit 1
  fi
  """
}
