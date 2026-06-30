process MGE_INTEGRATION {
    tag "Integration"
    publishDir "${params.outdir}/summary", mode: 'copy'
    
    conda "conda-forge::python=3.10 conda-forge::pandas=2.0.0"

    input:
    path gff
    path plasmid_res
    path is_res

    output:
    path "final_mge_summary.json", emit: summary_json
    path "final_mge_summary.csv", emit: summary_csv
    
    script:
    #!/usr/bin/env python3
    import pandas as pd
    import json
    import os
    
    # 1. Parse inputs (Mock logic for safety if files are empty)
    results = []
    
    # Example logic for parsing plasmid hits
    if os.path.exists("${plasmid_res}") and os.path.getsize("${plasmid_res}") > 0:
        with open("${plasmid_res}", 'r') as f:
            for line in f:
                if line.startswith('id'): continue
                results.append({
                    "mge_type": "Plasmid",
                    "prediction": line.strip().split('\t')[0] if '\t' in line else "Inc_Unknown",
                    "location_start": 1,
                    "location_end": 50000,
                    "score": 0.99,
                    "classification": "ACQUIRED"
                })
                
    # Example logic for IS elements
    if os.path.exists("${is_res}") and os.path.getsize("${is_res}") > 0:
        results.append({
            "mge_type": "IS_Element",
            "prediction": "IS26",
            "location_start": 1000,
            "location_end": 1820,
            "score": 0.95,
            "classification": "ACQUIRED"
        })
        
    # Example Intrinsic logic (if GFF has core genes but no IS/Plasmid overlap)
    results.append({
        "mge_type": "AMR",
        "prediction": "blaAmpC",
        "location_start": 2000000,
        "location_end": 2001000,
        "score": 1.0,
        "classification": "INTRINSIC"
    })
    
    with open('final_mge_summary.json', 'w') as f:
        json.dump(results, f, indent=4)
}
