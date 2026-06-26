/*
 * Setup and initialization module
 */

process setup_environment {
  executor 'local'
  
  output:
  path 'setup.complete'
  
  script:
  """
  #!/bin/bash
  set -euo pipefail
  
  # Create output directories
  mkdir -p ${params.outdir}
  mkdir -p ${params.log_dir}
  mkdir -p ${params.publish_dir}
  
  # Verify database path exists
  if [ ! -d "${params.db_path}" ]; then
    echo "WARNING: Database path not found: ${params.db_path}"
    echo "Initialize databases with: bash scripts/install_dbs.sh ${params.db_path}"
  fi
  
  # Check for required tools
  required_tools=("bash" "python3" "conda")
  for tool in "\${required_tools[@]}"; do
    if ! command -v \$tool &> /dev/null; then
      echo "ERROR: Required tool not found: \$tool"
      exit 1
    fi
  done
  
  echo "Environment setup complete" > setup.complete
  """
}

process validate_inputs {
  input:
  val(input_path)
  val(sample_sheet)
  
  output:
  path 'validation.report'
  
  script:
  """
  #!/bin/bash
  set -euo pipefail
  
  python3 - <<'PYTHON'
import os
import sys
import json
from pathlib import Path

validation_report = {
    'input_path': '${input_path}',
    'sample_sheet': '${sample_sheet}',
    'status': 'PASS',
    'errors': [],
    'warnings': []
}

# Validate input path
if '${input_path}' and '${input_path}' != 'null':
    input_dir = Path('${input_path}')
    if not input_dir.exists():
        validation_report['status'] = 'FAIL'
        validation_report['errors'].append(f"Input directory not found: {input_dir}")
    elif input_dir.is_file():
        if not any(input_dir.suffix in ext for ext in ['.fa', '.fasta', '.fna']):
            validation_report['errors'].append(f"Invalid file extension: {input_dir.suffix}")
    elif input_dir.is_dir():
        fasta_files = list(input_dir.glob('*.[fa|fasta|fna]')) + list(input_dir.glob('*.gz'))
        if not fasta_files:
            validation_report['status'] = 'FAIL'
            validation_report['errors'].append(f"No FASTA files found in: {input_dir}")

# Write report
with open('validation.report', 'w') as f:
    f.write(json.dumps(validation_report, indent=2))

if validation_report['status'] == 'FAIL':
    for error in validation_report['errors']:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

for warning in validation_report['warnings']:
    print(f"WARNING: {warning}")
PYTHON
  """
}
