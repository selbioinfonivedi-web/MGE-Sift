// Hide sections initially so it acts like a real app
const runView = document.querySelector('.run-wrap');
const resView = document.querySelectorAll('section')[1]; // the results view
if(runView) runView.style.display = 'none';
if(resView) resView.style.display = 'none';

// Transform Organism select into text input
const orgFg = document.querySelectorAll('.opt-grid .fg')[0];
if(orgFg) {
    orgFg.innerHTML = '<label>Organism / SRA ID</label><input type="text" id="organismInput" class="txin" placeholder="e.g. E. coli or SRR...">';
}

// Make the dropzone functional for real file selection
const dropZone = document.querySelector('.drop');
const fileInput = document.createElement('input');
fileInput.type = 'file';
fileInput.style.display = 'none';
document.body.appendChild(fileInput);

let selectedFile = null;

if(dropZone) {
    dropZone.addEventListener('click', () => fileInput.click());
}

fileInput.addEventListener('change', (e) => {
  if(e.target.files.length > 0) {
    selectedFile = e.target.files[0];
    const t1 = dropZone.querySelector('.t1');
    const t2 = dropZone.querySelector('.t2');
    if(t1) t1.textContent = selectedFile.name;
    if(t2) t2.textContent = (selectedFile.size / 1024 / 1024).toFixed(2) + ' MB';
  }
});

// Handle Run Analysis Button
const startBtn = document.getElementById('startBtn');
if(startBtn) {
    startBtn.addEventListener('click', async () => {
      if(!selectedFile) {
          alert("Please select a FASTA file in the dropzone first!");
          return;
      }
      startBtn.disabled = true;
      startBtn.innerHTML = '<span class="spin"></span> Uploading...';
      
      if(runView) {
          runView.style.display = 'block';
          runView.scrollIntoView({behavior:"smooth",block:"start"});
      }
      if(resView) resView.style.display = 'none';
      
      try {
          const formData = new FormData();
          formData.append("file", selectedFile);
          
          // 1. Send file to backend
          const uploadRes = await fetch("http://localhost:8000/api/v1/upload/", { method: "POST", body: formData });
          if (!uploadRes.ok) throw new Error("Upload failed.");
          const jobData = await uploadRes.json();
          const jobId = jobData.job_id;
          
          const runStatus = document.querySelector('.run-status');
          if(runStatus) runStatus.textContent = `Job ${jobId} · status: RUNNING`;
          startBtn.innerHTML = '<span class="spin"></span> Analyzing...';
          
          // 2. Poll for results
          let resultsData = null;
          while (true) {
              await new Promise(r => setTimeout(r, 3000));
              const res = await fetch(`http://localhost:8000/api/v1/results/${jobId}`);
              if (res.ok) {
                  const data = await res.json();
                  if (data.status === "COMPLETED") { resultsData = data; break; }
                  if (data.status === "FAILED") { throw new Error("Pipeline failed on backend."); }
              }
          }
          
          // 3. Hide run view, show results
          if(runView) runView.style.display = 'none';
          if(resView) {
              resView.style.display = 'block';
              resView.scrollIntoView({behavior:"smooth",block:"start"});
          }
          
          // 4. Update Results UI with Real Data
          const headH2 = document.querySelector('.res-head h2');
          const headSub = document.querySelector('.res-head .sub');
          
          let orgName = selectedFile.name;
          const orgInput = document.getElementById('organismInput');
          if(orgInput && orgInput.value.trim() !== '') {
              orgName = orgInput.value.trim();
          }

          if(headH2) headH2.textContent = `${orgName} — results`;
          if(headSub) headSub.innerHTML = `<span class="ok">✓ Analysis complete</span> · Job ${jobId} · GET /api/v1/results/${jobId}`;
          
          // Populate the main table
          const tbody = document.querySelector('.rtable tbody');
          if(tbody) {
              const rows = resultsData.results.map(r => 
                `<tr>
                  <td class="mono">${r.prediction}</td>
                  <td>-</td>
                  <td class="mono">${r.mge_type}</td>
                  <td><span class="badge ${r.classification === 'INTRINSIC' ? 'intrinsic' : 'hgt'}">${r.classification}</span></td>
                  <td><span class="badge high">Score: ${r.evidence_score || 100}</span></td>
                </tr>`
              ).join("");
              
              tbody.innerHTML = rows || '<tr><td colspan="5" style="text-align:center">No MGEs detected</td></tr>';
          }
          
          // Populate the top summary cards
          const amrCount = resultsData.results.filter(r => r.mge_type === 'AMR').length;
          const plasmidCount = resultsData.results.filter(r => r.mge_type === 'Plasmid').length;
          const isCount = resultsData.results.filter(r => r.mge_type === 'IS_Element').length;
          const intCount = resultsData.results.filter(r => r.mge_type === 'Integron').length;
          
          const cards = document.querySelectorAll('.mcard .mv');
          if(cards.length >= 4) {
              cards[0].textContent = amrCount;
              cards[1].textContent = plasmidCount;
              cards[2].textContent = isCount;
              cards[3].textContent = intCount;
          }

      } catch (err) {
          alert("Error: " + err.message);
      }
      
      startBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg> Run MGE-Sift analysis';
      startBtn.disabled = false;
    });
}
