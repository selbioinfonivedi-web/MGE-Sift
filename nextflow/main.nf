#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.input = 'genomes'
params.sample_name = null
params.config = "${projectDir}/config/mge_pipeline.cfg"
params.outdir = "${projectDir}/results"
params.max_cpus = 4
params.max_memory_gb = 8

workflow {
  def inputPath = file(params.input)
  if (!inputPath.exists()) {
    error "Input path not found: ${params.input}"
  }

  def genomes = []
  if (inputPath.isDirectory()) {
    genomes = inputPath.listFiles()
      .findAll { it.name =~ /(?i)\.(fa|fasta|fna)(\.gz)?$/ }
      .sort { it.name }
  } else {
    genomes = [inputPath]
  }

  if (!genomes) {
    error "No FASTA genomes found in: ${params.input}"
  }

  Channel.fromList(genomes)
    .map { genome ->
      def sample = params.sample_name ?: genome.baseName.replaceAll(/\.(fa|fasta|fna)(\.gz)?$/, '')
      tuple(sample, genome)
    }
    .set { genome_ch }

  RUN_MGE_PIPELINE(genome_ch)
}

process RUN_MGE_PIPELINE {
  tag { sample }
  cpus params.max_cpus
  memory "${params.max_memory_gb} GB"
  time '24h'

  input:
  tuple val(sample), path(genome)

  script:
  def configPath = file(params.config).toString()
  """
  set -euo pipefail
  mkdir -p "${params.outdir}"
  bash ${projectDir}/single/mge_single.sh "${genome}" "${sample}" "${configPath}"
  """
}
