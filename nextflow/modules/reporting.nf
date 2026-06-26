/*
 * Report generation module
 */

process GENERATE_REPORTS {
  tag { sample }
  cpus 2
  memory "4 GB"
  time params.max_time
  
  publishDir "${params.publish_dir}/reports", mode: 'copy'
  
  input:
  tuple val(sample), path(integration_results)
  
  output:
  path "${sample}_report.html", emit: html_report
  path "${sample}_report.json", emit: json_report
  
  script:
  """
  set -euo pipefail
  
  python3 - <<'PYTHON'
import json
import sys
from pathlib import Path
from datetime import datetime

# Collect analysis results
results = {
    'sample': '${sample}',
    'timestamp': datetime.now().isoformat(),
    'analyses': {}
}

# Parse integration results
integration_file = Path('${integration_results}').glob('*.tsv').__next__()
with open(integration_file) as f:
    for line in f:
        if not line.startswith('#'):
            results['analyses'][line.split()[0]] = {
                'status': 'detected',
                'confidence': float(line.split()[1]) if len(line.split()) > 1 else 0.0
            }

# Write JSON report
with open('${sample}_report.json', 'w') as f:
    json.dump(results, f, indent=2)

# Generate HTML report
html_content = f"""
<!DOCTYPE html>
<html>
<head>
  <title>MGE-Sift Report - {results['sample']}</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 20px; }}
    h1 {{ color: #333; }}
    .section {{ margin: 20px 0; padding: 10px; border-left: 4px solid #007bff; }}
    table {{ width: 100%; border-collapse: collapse; }}
    th, td {{ padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }}
    th {{ background-color: #f2f2f2; }}
  </style>
</head>
<body>
  <h1>Mobile Genetic Element Analysis Report</h1>
  <div class="section">
    <h2>Sample Information</h2>
    <p><strong>Sample ID:</strong> {results['sample']}</p>
    <p><strong>Analysis Date:</strong> {results['timestamp']}</p>
  </div>
  <div class="section">
    <h2>Detection Results</h2>
    <table>
      <tr><th>Element Type</th><th>Status</th><th>Confidence</th></tr>
"""

for element, data in results['analyses'].items():
    html_content += f"""
      <tr>
        <td>{element}</td>
        <td>{data['status']}</td>
        <td>{data['confidence']:.2%}</td>
      </tr>
"""

html_content += """
    </table>
  </div>
</body>
</html>
"""

with open('${sample}_report.html', 'w') as f:
    f.write(html_content)

print(f"Generated reports for {results['sample']}")
PYTHON
  """
}
