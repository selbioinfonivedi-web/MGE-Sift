process MGE_INTEGRATION {
    tag "${sample_id}"
    publishDir "${params.outdir}/summary", mode: 'copy'
    
    conda "conda-forge::python=3.10 conda-forge::pandas=2.0.0"

    input:
    tuple val(sample_id), path(gff), path(plasmid_res), path(is_res), path(integrons_res), path(prophages_res), path(islands_res), path(repeats_res), path(amr_res)

    output:
    tuple val(sample_id), path("final_mge_summary.json"), emit: summary_json
    tuple val(sample_id), path("final_mge_summary.csv"), emit: summary_csv
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import json
    import os
    
    mges = []
    amrs = []
    
    def check_overlap(start1, end1, start2, end2):
        return max(0, min(end1, end2) - max(start1, start2)) > 0
    
    # 1. Parse Plasmid (MOB-suite)
    if os.path.exists("${plasmid_res}") and os.path.getsize("${plasmid_res}") > 0:
        try:
            df_plasmid = pd.read_csv("${plasmid_res}", sep='\\t')
            for _, row in df_plasmid.iterrows():
                mges.append({
                    "mge_type": "Plasmid",
                    "prediction": row.get('rep_type(s)', 'Plasmid_Unknown'),
                    "location_start": 1,
                    "location_end": int(row.get('size', 10000)),
                    "score": 0.99,
                    "classification": "ACQUIRED"
                })
        except Exception as e:
            print(f"Error parsing plasmid: {e}")
            
    # 2. Parse IS Elements (ISEScan)
    if os.path.exists("${is_res}") and os.path.getsize("${is_res}") > 0:
        try:
            df_is = pd.read_csv("${is_res}", sep=',')
            for _, row in df_is.iterrows():
                mges.append({
                    "mge_type": "IS_Element",
                    "prediction": row.get('family', 'IS_Unknown'),
                    "location_start": int(row.get('isBegin', 0)),
                    "location_end": int(row.get('isEnd', 0)),
                    "score": 0.90,
                    "classification": "ACQUIRED"
                })
        except Exception as e:
            print(f"Error parsing IS: {e}")

    # 3. Parse AMR (ABRicate)
    if os.path.exists("${amr_res}") and os.path.getsize("${amr_res}") > 0:
        try:
            df_amr = pd.read_csv("${amr_res}", sep='\\t')
            for _, row in df_amr.iterrows():
                amr_start = int(row.get('START', 0))
                amr_end = int(row.get('END', 0))
                
                # Check overlap with ANY MGE
                is_acquired = False
                for mge in mges:
                    if check_overlap(amr_start, amr_end, mge["location_start"], mge["location_end"]):
                        is_acquired = True
                        break
                
                amrs.append({
                    "mge_type": "AMR",
                    "prediction": row.get('GENE', 'AMR_Unknown'),
                    "location_start": amr_start,
                    "location_end": amr_end,
                    "score": float(row.get('%COVERAGE', 100.0)) / 100.0,
                    "classification": "ACQUIRED" if is_acquired else "INTRINSIC"
                })
        except Exception as e:
            print(f"Error parsing AMR: {e}")

    # 4. Parse Genomic Islands (IslandPath)
    if os.path.exists("${islands_res}") and os.path.getsize("${islands_res}") > 0:
        try:
            df_islands = pd.read_csv("${islands_res}", sep='\\t')
            for _, row in df_islands.iterrows():
                mges.append({
                    "mge_type": "Genomic_Island",
                    "prediction": str(row.get('type', 'Island_Unknown')),
                    "location_start": int(row.get('start', 0)),
                    "location_end": int(row.get('end', 0)),
                    "score": 0.90,
                    "classification": "ACQUIRED"
                })
        except Exception as e:
            print(f"Error parsing Islands: {e}")

    # 5. Parse Integrons (IntegronFinder)
    if os.path.exists("${integrons_res}") and os.path.getsize("${integrons_res}") > 0:
        try:
            df_integrons = pd.read_csv("${integrons_res}", sep='\\t', comment='#', skip_blank_lines=True)
            df_integrons.dropna(how='all', inplace=True)
            if not df_integrons.empty and len(df_integrons.columns) >= 3:
                for _, row in df_integrons.iterrows():
                    # Check if row has enough valid columns to be a real integron
                    if pd.notna(row.iloc[1]) and pd.notna(row.iloc[2]):
                        mges.append({
                            "mge_type": "Integron",
                            "prediction": "Integron",
                            "location_start": int(row.iloc[1]),
                            "location_end": int(row.iloc[2]),
                            "score": 0.90,
                            "classification": "ACQUIRED"
                        })
        except Exception as e:
            print(f"Error parsing Integrons: {e}")

    # 6. Parse Prophages (PhiSpy)
    if os.path.exists("${prophages_res}") and os.path.getsize("${prophages_res}") > 0:
        try:
            df_prophages = pd.read_csv("${prophages_res}", sep='\\t', comment='#', skip_blank_lines=True)
            df_prophages.dropna(how='all', inplace=True)
            if not df_prophages.empty and len(df_prophages.columns) >= 4:
                for _, row in df_prophages.iterrows():
                    if pd.notna(row.iloc[2]) and pd.notna(row.iloc[3]):
                        mges.append({
                            "mge_type": "Prophage",
                            "prediction": "Prophage",
                            "location_start": int(row.iloc[2]),
                            "location_end": int(row.iloc[3]),
                            "score": 0.90,
                            "classification": "ACQUIRED"
                        })
        except Exception as e:
            print(f"Error parsing Prophages: {e}")

    results = mges + amrs

    if not results:
        results.append({
            "mge_type": "None",
            "prediction": "No Elements Detected",
            "location_start": 0,
            "location_end": 0,
            "score": 0.0,
            "classification": "INTRINSIC"
        })

    with open('final_mge_summary.json', 'w') as f:
        json.dump(results, f, indent=4)
        
    df_final = pd.DataFrame(results)
    df_final.to_csv('final_mge_summary.csv', index=False)
    """
}
