#!/usr/bin/env python3
"""
Cohort Summary Generation
Merges individual sample reports into cohort-level matrices and comparisons
"""

import os
import sys
import argparse
import pandas as pd
from pathlib import Path
from datetime import datetime

def generate_cohort_report(results_dir, output_prefix):
    """Generate cohort-wide summary reports"""
    
    print(f"[INFO] Generating cohort summary from {results_dir}")
    
    # Find all sample directories
    sample_dirs = [d for d in os.listdir(results_dir) if os.path.isdir(os.path.join(results_dir, d))]
    sample_dirs = [d for d in sample_dirs if '01_annotation' in os.listdir(os.path.join(results_dir, d))]
    
    print(f"[INFO] Found {len(sample_dirs)} samples")
    
    # ========================================================================
    # 1. Cohort MGE Report (all MGEs across all samples)
    # ========================================================================
    print(f"[INFO] Compiling cohort MGE report...")
    
    all_mges = []
    for sample_dir in sample_dirs:
        report_file = os.path.join(results_dir, sample_dir, f'{sample_dir}_MGE_classification_report.tsv')
        
        if os.path.exists(report_file):
            try:
                df = pd.read_csv(report_file, sep='\t')
                df['Sample'] = sample_dir
                all_mges.append(df)
            except:
                pass
    
    if all_mges:
        cohort_df = pd.concat(all_mges, ignore_index=True)
        cohort_file = os.path.join(results_dir, 'cohort', f'{output_prefix}_MGE_report.tsv')
        os.makedirs(os.path.dirname(cohort_file), exist_ok=True)
        cohort_df.to_csv(cohort_file, sep='\t', index=False)
        print(f"[OK] Cohort MGE report: {cohort_file}")
    
    # ========================================================================
    # 2. Cohort Summary (counts per sample)
    # ========================================================================
    print(f"[INFO] Generating cohort summary statistics...")
    
    summary_data = []
    for sample_dir in sample_dirs:
        stats = {
            'Sample': sample_dir,
            'Total_MGEs': 0,
            'Plasmids': 0,
            'IS_Elements': 0,
            'Integrons': 0,
            'Prophages': 0,
            'Islands': 0,
            'Acquired': 0,
            'Intrinsic': 0,
            'AMR_Genes': 0
        }
        
        # Count MGEs by type
        report_file = os.path.join(results_dir, sample_dir, f'{sample_dir}_MGE_classification_report.tsv')
        if os.path.exists(report_file):
            try:
                df = pd.read_csv(report_file, sep='\t')
                stats['Total_MGEs'] = len(df)
                
                for mge_type in ['Plasmids', 'IS_Elements', 'Integrons', 'Prophages', 'Islands']:
                    stats[mge_type] = len(df[df['Type'].str.contains(mge_type, case=False, na=False)])
                
                stats['Acquired'] = len(df[df['Origin'].str.contains('Acquired', na=False)])
                stats['Intrinsic'] = len(df[df['Origin'].str.contains('Intrinsic', na=False)])
            except:
                pass
        
        # Count AMR genes
        amr_file = os.path.join(results_dir, sample_dir, f'{sample_dir}_AMR_in_MGE.tsv')
        if os.path.exists(amr_file):
            try:
                df = pd.read_csv(amr_file, sep='\t')
                stats['AMR_Genes'] = len(df)
            except:
                pass
        
        summary_data.append(stats)
    
    if summary_data:
        summary_df = pd.DataFrame(summary_data)
        summary_file = os.path.join(results_dir, 'cohort', f'{output_prefix}_summary.tsv')
        os.makedirs(os.path.dirname(summary_file), exist_ok=True)
        summary_df.to_csv(summary_file, sep='\t', index=False)
        print(f"[OK] Cohort summary: {summary_file}")
    
    # ========================================================================
    # 3. AMR Matrix (presence/absence across samples)
    # ========================================================================
    print(f"[INFO] Generating cohort AMR matrix...")
    
    amr_genes = {}
    for sample_dir in sample_dirs:
        amr_file = os.path.join(results_dir, sample_dir, f'{sample_dir}_all_amr.bed')
        
        if os.path.exists(amr_file):
            try:
                df = pd.read_csv(amr_file, sep='\t', header=None)
                for _, row in df.iterrows():
                    gene = row[3]
                    if gene not in amr_genes:
                        amr_genes[gene] = {}
                    amr_genes[gene][sample_dir] = 1
            except:
                pass
    
    if amr_genes:
        # Create matrix
        matrix_data = []
        for gene in sorted(amr_genes.keys()):
            row = {'AMR_Gene': gene}
            for sample_dir in sample_dirs:
                row[sample_dir] = amr_genes[gene].get(sample_dir, 0)
            matrix_data.append(row)
        
        matrix_df = pd.DataFrame(matrix_data)
        matrix_file = os.path.join(results_dir, 'cohort', f'{output_prefix}_AMR_matrix.tsv')
        os.makedirs(os.path.dirname(matrix_file), exist_ok=True)
        matrix_df.to_csv(matrix_file, sep='\t', index=False)
        print(f"[OK] AMR matrix: {matrix_file}")
    
    # ========================================================================
    # 4. Shared MGEs Across Samples
    # ========================================================================
    print(f"[INFO] Identifying shared MGEs...")
    
    all_mge_ids = {}
    for sample_dir in sample_dirs:
        bed_file = os.path.join(results_dir, sample_dir, f'{sample_dir}_all_MGEs.bed')
        
        if os.path.exists(bed_file):
            try:
                df = pd.read_csv(bed_file, sep='\t', header=None)
                for _, row in df.iterrows():
                    mge_type = row[6] if len(row) > 6 else 'unknown'
                    key = f"{row[0]}:{row[1]}-{row[2]}"
                    
                    if key not in all_mge_ids:
                        all_mge_ids[key] = {'Type': mge_type, 'Samples': []}
                    all_mge_ids[key]['Samples'].append(sample_dir)
            except:
                pass
    
    # Find shared MGEs (present in >1 sample)
    shared_mges = []
    for mge_id, data in all_mge_ids.items():
        if len(data['Samples']) > 1:
            shared_mges.append({
                'MGE_ID': mge_id,
                'Type': data['Type'],
                'Number_of_Samples': len(data['Samples']),
                'Samples': '; '.join(data['Samples'])
            })
    
    if shared_mges:
        shared_df = pd.DataFrame(shared_mges)
        shared_file = os.path.join(results_dir, 'cohort', f'{output_prefix}_shared_MGEs.tsv')
        os.makedirs(os.path.dirname(shared_file), exist_ok=True)
        shared_df.to_csv(shared_file, sep='\t', index=False)
        print(f"[OK] Shared MGEs: {shared_file} ({len(shared_mges)} elements)")
    
    # ========================================================================
    # Summary
    # ========================================================================
    print(f"\n[INFO] === Cohort Summary ===")
    print(f"Samples processed: {len(sample_dirs)}")
    if all_mges:
        print(f"Total MGEs: {len(all_mges)}")
    if shared_mges:
        print(f"Shared MGEs: {len(shared_mges)}")
    if amr_genes:
        print(f"Unique AMR genes: {len(amr_genes)}")
    
    print(f"[OK] Cohort analysis complete")

def main():
    parser = argparse.ArgumentParser(description='Generate cohort-level summaries')
    parser.add_argument('--results_dir', required=True, help='Results directory containing sample folders')
    parser.add_argument('--output_prefix', required=True, help='Prefix for output files')
    
    args = parser.parse_args()
    
    generate_cohort_report(args.results_dir, args.output_prefix)

if __name__ == '__main__':
    main()
