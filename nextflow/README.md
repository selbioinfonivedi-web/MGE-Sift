# Nextflow production entrypoint

Run the workflow with:

```bash
nextflow run nextflow/main.nf --input genomes --outdir results
```

For a single sample:

```bash
nextflow run nextflow/main.nf --input genomes/sample.fa --sample_name sample1 --outdir results
```
