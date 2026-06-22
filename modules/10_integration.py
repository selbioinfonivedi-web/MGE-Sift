#!/usr/bin/env python3
"""
Module 10: MGE Integration and Classification
Combines results from all 9 detection modules and generates unified reports
"""

import os
import sys
import argparse
import pandas as pd
from pathlib import Path
from datetime import datetime
import json

def load_config(config_file):
    """Load configuration from file"""
    config = {}
    if os.path.exists(config_file):
        with open(config_file) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip().strip('"\'')
    return config

def merge_mge_predictions(output_dir):
    """Merge all MGE predictions into unified BED file"""
    
    mge_types = {
        'plasmids': '02_plasmid',
        'is_elements': '03_IS_elements',
        'integrons': '04_integrons',
        'prophages': '05_prophage',
        'islands': '06_genomic_islands',
        'repeats': '07_repeats'
    }
    
    all_mges = []
    
    for mge_type, module_dir in mge_types.items():
        bed_file = os.path.join(output_dir, module_dir, f'*_{mge_type}.bed')
        bed_file = os.path.join(output_dir, module_dir)
        
        # Find all BED files in module directory
        for fname in os.listdir(bed_file) if os.path.isdir(bed_file) else []:
            if fname.endswith('.bed'):
                fpath = os.path.join(bed_file, fname)
                try:
                    df = pd.read_csv(fpath, sep='\t', header=None, comment='#')
                    if len(df.columns) >= 6:
                        df.columns = ['chrom', 'start', 'end', 'name', 'score', 'strand']
                        df['type'] = mge_type
                        all_mges.append(df)
                except:
                    pass
    
    if all_mges:
        mge_df = pd.concat(all_mges, ignore_index=True)
        mge_df = mge_df.sort_values(['chrom', 'start'])
        mge_df = mge_df.drop_duplicates(subset=['chrom', 'start', 'end'])
        return mge_df
    
    return pd.DataFrame()

def classify_mges(output_dir, sample_name):
    """Load individual MGE classifications"""
    
    classifications = {}
    
    modules = {
        'plasmids': '02_plasmid',
        'is_elements': '03_IS_elements',
        'integrons': '04_integrons',
        'prophages': '05_prophage',
        'islands': '06_genomic_islands'
    }
    
    for mge_type, module_dir in modules.items():
        class_file = os.path.join(output_dir, module_dir, 
                                 f'{sample_name}_{mge_type.replace("_", "")}_classification.tsv')
        
        # Try alternative file names
        if not os.path.exists(class_file):
            for fname in os.listdir(os.path.join(output_dir, module_dir) if os.path.isdir(os.path.join(output_dir, module_dir)) else ['.']|):
                if 'classification' in fname.lower() and fname.endswith('.tsv'):
                    class_file = os.path.join(output_dir, module_dir, fname)
                    break
        
        if os.path.exists(class_file):
            try:
                df = pd.read_csv(class_file, sep='\t')
                classifications[mge_type] = df
            except:
                pass
    
    return classifications

def find_amr_in_mges(output_dir, sample_name, mge_bed, amr_bed):
    """Find AMR genes located within MGE regions"""
    
    amr_in_mge = []
    
    amr_file = os.path.join(output_dir, '09_AMR', f'{sample_name}_all_amr.bed')
    if os.path.exists(amr_file):
        try:
            amr_df = pd.read_csv(amr_file, sep='\t', header=None)
            
            for idx, mge_row in mge_bed.iterrows():
                # Check if AMR gene overlaps with MGE
                overlapping = amr_df[
                    (amr_df[0] == mge_row['chrom']) &
                    (amr_df[1] >= mge_row['start']) &
                    (amr_df[2] <= mge_row['end'])
                ]
                
                if len(overlapping) > 0:
                    for _, amr_row in overlapping.iterrows():
                        amr_in_mge.append({
                            'MGE': mge_row['name'],
                            'MGE_type': mge_row['type'],
                            'Chrom': mge_row['chrom'],
                            'MGE_start': mge_row['start'],
                            'MGE_end': mge_row['end'],
                            'AMR_gene': amr_row[3],
                            'AMR_start': amr_row[1],
                            'AMR_end': amr_row[2]
                        })
        except:
            pass
    
    if amr_in_mge:
        return pd.DataFrame(amr_in_mge)
    return pd.DataFrame()

def generate_classification_report(output_dir, sample_name, mge_bed, classifications):
    """Generate final MGE classification report"""
    
    report = []
    
    for idx, mge_row in mge_bed.iterrows():
        mge_id = mge_row['name']
        mge_type = mge_row['type']
        
        classification = "UNKNOWN"
        confidence = 0
        origin = "Unknown"
        
        # Look up classification in results
        for cls_type, cls_df in classifications.items():
            if 'Classification_Result' in cls_df.columns:
                matching = cls_df[cls_df.iloc[:, 0].str.contains(mge_id, na=False)]
                if len(matching) > 0:
                    classification = matching.iloc[0]['Classification_Result']
                    
                    # Extract origin
                    if 'ACQUIRED' in classification:
                        origin = "Acquired (HGT)"
                        confidence = 0.8
                    elif 'INTRINSIC' in classification:
                        origin = "Intrinsic"
                        confidence = 0.7
                    break
        
        report.append({
            'MGE_ID': mge_id,
            'Contig': mge_row['chrom'],
            'Start': mge_row['start'],
            'End': mge_row['end'],
            'Length_bp': mge_row['end'] - mge_row['start'],
            'Type': mge_type,
            'Classification': classification,
            'Origin': origin,
            'Confidence': confidence
        })
    
    return pd.DataFrame(report)

def main():
    parser = argparse.ArgumentParser(description='MGE Integration and Classification Module')
    parser.add_argument('--sample', required=True, help='Sample name')
    parser.add_argument('--output_dir', required=True, help='Output directory')
    parser.add_argument('--config', required=True, help='Configuration file')
    
    args = parser.parse_args()
    
    config = load_config(args.config)
    print(f"[INFO] Module 10: Integration and Classification")
    print(f"[INFO] Sample: {args.sample}")
    print(f"[INFO] Output: {args.output_dir}")
    
    # Step 1: Merge MGE predictions
    print(f"[INFO] Merging MGE predictions...")
    mge_bed = merge_mge_predictions(args.output_dir)
    
    if len(mge_bed) > 0:
        # Save merged BED
        output_bed = os.path.join(args.output_dir, f'{args.sample}_all_MGEs.bed')
        mge_bed[['chrom', 'start', 'end', 'name', 'score', 'strand', 'type']].to_csv(
            output_bed, sep='\t', index=False, header=False)
        print(f"[OK] Merged MGEs: {output_bed} ({len(mge_bed)} elements)")
    else:
        print(f"[WARN] No MGE elements found")
    
    # Step 2: Load classifications
    print(f"[INFO] Loading classifications...")
    classifications = classify_mges(args.output_dir, args.sample)
    print(f"[OK] Loaded {len(classifications)} classification types")
    
    # Step 3: Find AMR in MGEs
    if len(mge_bed) > 0:
        print(f"[INFO] Finding AMR genes in MGEs...")
        amr_in_mge = find_amr_in_mges(args.output_dir, args.sample, mge_bed, None)
        
        if len(amr_in_mge) > 0:
            output_amr = os.path.join(args.output_dir, f'{args.sample}_AMR_in_MGE.tsv')
            amr_in_mge.to_csv(output_amr, sep='\t', index=False)
            print(f"[OK] AMR in MGEs: {output_amr} ({len(amr_in_mge)} genes)")
        else:
            print(f"[INFO] No AMR genes found in MGEs")
    
    # Step 4: Generate classification report
    print(f"[INFO] Generating classification report...")
    if len(mge_bed) > 0:
        report = generate_classification_report(args.output_dir, args.sample, mge_bed, classifications)
        
        output_report = os.path.join(args.output_dir, f'{args.sample}_MGE_classification_report.tsv')
        report.to_csv(output_report, sep='\t', index=False)
        print(f"[OK] Classification report: {output_report} ({len(report)} elements)")
    
    # Step 5: Summary statistics
    print(f"\n[INFO] === MGE Integration Summary ===")
    print(f"Total MGEs: {len(mge_bed)}")
    
    if len(mge_bed) > 0:
        for mge_type in mge_bed['type'].unique():
            count = len(mge_bed[mge_bed['type'] == mge_type])
            print(f"  {mge_type}: {count}")
    
    print(f"[OK] Module 10 complete")

if __name__ == '__main__':
    main()
