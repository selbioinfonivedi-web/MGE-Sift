import os
import re
from pathlib import Path

# Paths
base_dir = Path("e:/MGE-Sift/MGE-Sift")
modules_dir = base_dir / "modules"
workflows_dir = base_dir / "workflows"
nf_modules_dir = workflows_dir / "modules"

# Create directories
nf_modules_dir.mkdir(parents=True, exist_ok=True)

# List of modules
sh_files = [
    "01_annotation.sh",
    "02_plasmid.sh",
    "03_is_elements.sh",
    "04_integrons.sh",
    "05_prophages.sh",
    "06_genomic_islands.sh",
    "07_repeats.sh",
    "08_hgt_signals.sh",
    "09_amr_detection.sh"
]

python_files = [
    "10_integration.py",
    "cohort_summary.py"
]

nf_names = [
    "annotation",
    "plasmid_detection",
    "is_detection",
    "integron_detection",
    "prophage_detection",
    "genomic_island_detection",
    "repeat_analysis",
    "hgt_detection",
    "amr_detection",
    "mge_classification",
    "report_generation"
]

def generate_nf_module(script_file, nf_name, is_python=False):
    script_path = modules_dir / script_file
    
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Process inputs/outputs
    # We will wrap the script execution.
    # To avoid rewriting the entire bash script which is complex, we will copy the script into the Nextflow script block
    # and adjust the inputs.
    
    # We remove the parameter parsing part:
    # GENOME_FA=$1
    # SAMPLE_NAME=$2
    # OUTPUT_DIR=$3
    # CONFIG_FILE=$4
    
    modified_content = content
    modified_content = re.sub(r'GENOME_FA=\$1\n', '', modified_content)
    modified_content = re.sub(r'SAMPLE_NAME=\$2\n', '', modified_content)
    modified_content = re.sub(r'OUTPUT_DIR=\$3\n', '', modified_content)
    modified_content = re.sub(r'CONFIG_FILE=\$4\n', '', modified_content)
    
    modified_content = re.sub(r'source "\$CONFIG_FILE"\n', '', modified_content)
    modified_content = re.sub(r'source "\$\(dirname "\$0"\)/../lib/common_functions.sh"\n', '', modified_content)
    modified_content = re.sub(r'source "\$\(dirname "\$0"\)/../lib/error_handling.sh"\n', '', modified_content)
    
    modified_content = re.sub(r'MODULE_DIR="\$OUTPUT_DIR/.*?"\n', 'MODULE_DIR="."\n', modified_content)
    modified_content = re.sub(r'mkdir -p "\$MODULE_DIR"\n', '', modified_content)
    
    if not is_python:
        # Bash script
        script_block = f"""
    GENOME_FA=\${genome}
    SAMPLE_NAME=\${meta.id}
    OUTPUT_DIR="."
    MODULE_DIR="."
    
    # Add dummy functions for missing libs
    log_info() {{ echo "[INFO] \$1"; }}
    log_warn() {{ echo "[WARN] \$1" >&2; }}
    log_success() {{ echo "[SUCCESS] \$1"; }}
    die() {{ echo "[ERROR] \$1" >&2; exit 1; }}
    check_output() {{ if [ ! -f "\$1" ] && [ "\$2" -eq 1 ]; then return 1; fi; return 0; }}
    calculate_gc_content() {{ awk '/^>/{{next}} {{s+=length(\$0); gsub(/[cCgG]/,"",\$0); gc+=length(\$0)}} END{{if(s>0) printf "%.2f", 100*(1-gc/s); else print "0.00"}}' "\$1"; }}
    
    {modified_content}
    """
    else:
        if "integration" in script_file:
            script_block = f"""
    # Assuming bed files are passed as inputs and placed in the current directory
    # The python script expects output_dir to have subdirectories, but we can just patch it to read from current dir.
    
    # Run the original python script but passed as an inline script or executed from path
    python3 {modules_dir / script_file} --sample \${meta.id} --output_dir . --config dummy.cfg
    """
        else:
            script_block = f"""
    python3 {modules_dir / script_file} --input . --output \${meta.id}_cohort_summary.html
    """
            
    # Escape Nextflow variables inside the bash script by replacing $ with \$ except for Nextflow variables.
    # Actually, if we use ''' for script, we can just let $ mean bash variables, but we need to inject ${genome} and ${meta.id}.
    # Wait, in Nextflow, inside triple quotes, $VAR is evaluated by Nextflow unless escaped as \$VAR.
    # So we MUST escape all bash variables.
    def escape_bash_vars(text):
        # We need to escape all $ EXCEPT ${genome}, ${meta.id}
        # A simple way is to escape all $ to \$, then unescape \${genome} and \${meta.id}
        t = text.replace("$", "\\$")
        t = t.replace("\\${genome}", "${genome}")
        t = t.replace("\\${meta.id}", "${meta.id}")
        t = t.replace("\\${config_file}", "${config_file}")
        t = t.replace("\\${annotation_gff}", "${annotation_gff}")
        t = t.replace("\\${annotation_faa}", "${annotation_faa}")
        # Nextflow inputs for module 10
        for m in nf_names:
            t = t.replace(f"\\${{{m}_bed}}", f"${{{m}_bed}}")
        return t

    script_block_escaped = escape_bash_vars(script_block)

    # Determine outputs based on the module
    outputs_directive = 'path "*"'
    if "annotation" in nf_name:
        outputs_directive = 'path "*.gff3", emit: gff\n    path "*.faa", emit: faa\n    path "*.bed", emit: bed\n    path "*_annotation_stats.txt", emit: stats'
    elif "plasmid" in nf_name:
        outputs_directive = 'path "*.bed", emit: bed\n    path "*_classification.tsv", emit: classification\n    path "*_stats.txt", emit: stats'
    elif nf_name == "mge_classification":
        outputs_directive = 'path "*_all_MGEs.bed", emit: all_mges\n    path "*_AMR_in_MGE.tsv", emit: amr_in_mge, optional: true\n    path "*_MGE_classification_report.tsv", emit: report'
    elif nf_name == "report_generation":
        outputs_directive = 'path "*.html", emit: html\n    path "*.tsv", emit: tsv, optional: true'
    else:
        outputs_directive = 'path "*.bed", emit: bed\n    path "*_classification.tsv", emit: classification, optional: true\n    path "*_stats.txt", emit: stats, optional: true\n    path "*_matrix.tsv", emit: matrix, optional: true'
    
    nf_content = f"""// {nf_name} module

process {nf_name.upper()} {{
    tag "{{meta.id}}"
    label 'process_medium'
    
    publishDir "${{params.outdir}}/{nf_name}", mode: 'copy'
    
    // Resources
    cpus 4
    memory '8 GB'
    time '4h'
    
    // Error handling
    errorStrategy 'retry'
    maxRetries 3
    
    // Conda/Container
    conda "bioconda::biopython bioconda::bedtools"
    container 'quay.io/biocontainers/bedtools:2.30.0--hc088bd4_0'

    input:
"""
    if "annotation" in nf_name:
        nf_content += "    tuple val(meta), path(genome)\n"
    elif nf_name == "mge_classification":
        nf_content += "    tuple val(meta), path(genome)\n"
        nf_content += "    path mge_beds\n"
        nf_content += "    path classifications\n"
        nf_content += "    path amr_bed\n"
    elif nf_name == "report_generation":
        nf_content += "    path reports\n"
    elif "amr" in nf_name or nf_name in ["hgt_detection"]:
        nf_content += "    tuple val(meta), path(genome)\n"
        nf_content += "    path annotation_faa\n"
        nf_content += "    path annotation_gff\n"
    else:
        nf_content += "    tuple val(meta), path(genome)\n"

    nf_content += f"""
    output:
    {outputs_directive}

    script:
    \"\"\"
{script_block_escaped}
    \"\"\"
}}
"""
    
    with open(nf_modules_dir / f"{nf_name}.nf", "w", encoding="utf-8") as f:
        f.write(nf_content)

for i, sh_file in enumerate(sh_files):
    generate_nf_module(sh_file, nf_names[i])

generate_nf_module(python_files[0], nf_names[9], is_python=True)
generate_nf_module(python_files[1], nf_names[10], is_python=True)

# Generate main.nf
main_nf_content = """#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Include modules
"""

for nf_name in nf_names:
    main_nf_content += f"include {{ {nf_name.upper()} }} from './modules/{nf_name}.nf'\n"

main_nf_content += """
workflow {
    // Inputs
    Channel
        .fromPath(params.input)
        .map { file -> tuple([id: file.baseName], file) }
        .set { ch_genomes }

    // Run Annotation
    ANNOTATION(ch_genomes)
    
    // Modules taking genome only
    PLASMID_DETECTION(ch_genomes)
    IS_DETECTION(ch_genomes)
    INTEGRON_DETECTION(ch_genomes)
    PROPHAGE_DETECTION(ch_genomes)
    GENOMIC_ISLAND_DETECTION(ch_genomes)
    REPEAT_ANALYSIS(ch_genomes)
    
    // Modules taking genome and annotation
    HGT_DETECTION(ch_genomes, ANNOTATION.out.faa, ANNOTATION.out.gff)
    AMR_DETECTION(ch_genomes, ANNOTATION.out.faa, ANNOTATION.out.gff)
    
    // Classification (Module 10)
    ch_mge_beds = PLASMID_DETECTION.out.bed.mix(IS_DETECTION.out.bed, INTEGRON_DETECTION.out.bed, PROPHAGE_DETECTION.out.bed, GENOMIC_ISLAND_DETECTION.out.bed, REPEAT_ANALYSIS.out.bed).collect()
    ch_classifications = PLASMID_DETECTION.out.classification.mix(IS_DETECTION.out.classification, INTEGRON_DETECTION.out.classification, PROPHAGE_DETECTION.out.classification, GENOMIC_ISLAND_DETECTION.out.classification).collect()
    
    MGE_CLASSIFICATION(ch_genomes, ch_mge_beds, ch_classifications, AMR_DETECTION.out.bed)
    
    // Final Report
    REPORT_GENERATION(MGE_CLASSIFICATION.out.report.collect())
}
"""

with open(workflows_dir / "main.nf", "w", encoding="utf-8") as f:
    f.write(main_nf_content)
    
print("Successfully generated Nextflow modules and main.nf")
