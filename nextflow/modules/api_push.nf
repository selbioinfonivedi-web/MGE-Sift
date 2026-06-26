/*
 * API publication module
 */

process PUBLISH_RESULTS {
  tag { sample }
  cpus 1
  memory "2 GB"
  time '10m'
  
  when:
  params.api_server && params.api_token
  
  input:
  path report_html
  path report_json
  
  script:
  """
  set -euo pipefail
  
  python3 - <<'PYTHON'
import json
import requests
from pathlib import Path

api_server = '${params.api_server}'
api_token = '${params.api_token}'

# Read JSON report
with open('${report_json}') as f:
    report_data = json.load(f)

# Push to API
headers = {'Authorization': f'Bearer {api_token}'}
response = requests.post(
    f'{api_server}/api/v1/results',
    json=report_data,
    headers=headers
)

if response.status_code == 201:
    print(f"✓ Results published to {api_server}")
else:
    print(f"✗ Failed to publish: {response.status_code}")
    print(response.text)
    exit(1)
PYTHON
  """
}
