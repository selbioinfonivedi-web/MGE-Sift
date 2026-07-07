import os
import glob

base_dir = r"E:\MGE-Sift\MGE-Sift\workflows\modules"

fixes = {
    "plasmid_detection.nf": ["touch ${sample_id}_mobtyper.txt"],
    "is_detection.nf": ["mkdir -p prediction", "touch prediction/${sample_id}.csv"],
    "integron_detection.nf": ["mkdir -p Results_Integron_Finder_${fasta.baseName}", "touch Results_Integron_Finder_${fasta.baseName}/${fasta.baseName}.summary"],
    "prophage_detection.nf": ["mkdir -p ${sample_id}_phispy", "touch ${sample_id}_phispy/prophage_coordinates.tsv"],
    "genomic_island_detection.nf": ["touch ${sample_id}_islandpath.tsv"],
    "repeat_analysis.nf": ["touch ${sample_id}_minced.txt"],
    "amr_detection.nf": ["touch ${sample_id}_abricate.tsv"]
}

for nf_file in glob.glob(os.path.join(base_dir, "*.nf")):
    filename = os.path.basename(nf_file)
    if filename in fixes:
        with open(nf_file, "r") as f:
            content = f.read()
        
        # Remove "optional: true"
        content = content.replace(", optional: true", "")
        
        # Add touch commands to the top of the script block
        script_idx = content.find('script:\n    """\n')
        if script_idx != -1:
            insert_idx = script_idx + len('script:\n    """\n')
            commands = "\n    ".join(fixes[filename]) + "\n"
            content = content[:insert_idx] + "    " + commands + content[insert_idx:]
            
            with open(nf_file, "w") as f:
                f.write(content)
            print(f"Fixed {filename}")
