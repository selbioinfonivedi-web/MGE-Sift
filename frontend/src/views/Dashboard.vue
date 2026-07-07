<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-3xl font-bold text-dark-text">Genomic Database</h2>
      <div class="flex space-x-2">
        <input v-model="jobId" type="text" placeholder="Enter Job ID to load..." class="border border-gray-300 rounded px-3 py-2 text-sm w-64 focus:outline-none focus:border-deep-teal">
        <button @click="fetchResults" class="bg-deep-teal text-white px-4 py-2 rounded shadow hover:bg-teal-800 transition">Fetch</button>
      </div>
    </div>
    
    <div v-if="loading" class="text-gray-500">Loading biological data from SQL...</div>
    <div v-if="error" class="text-red-500 bg-red-50 p-4 rounded">{{ error }}</div>

    <div v-if="data" class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
      <div class="p-6 border-b border-gray-100 bg-gray-50 flex justify-between">
        <div>
          <h3 class="font-bold text-lg text-deep-teal">Sample: {{ data.sample_name || 'consensu' }}</h3>
          <p class="text-sm text-gray-500">Status: <span class="font-semibold text-green-600">{{ data.status || 'COMPLETED' }}</span></p>
        </div>
        <div class="text-right">
          <p class="text-sm text-gray-500">Job ID: <span class="font-mono text-xs">{{ data.job_id }}</span></p>
          <p class="text-sm text-gray-500 font-semibold mt-1">Total MGEs: {{ data.results.length }}</p>
        </div>
      </div>
      <!-- Scientific Genomic Feature Viewer (IGV.js) -->
      <div v-if="data.results.length > 0" class="p-6 border-b border-gray-100 bg-white">
        <div class="flex justify-between items-end mb-4">
          <h4 class="text-sm font-bold text-gray-800 uppercase tracking-widest flex items-center">
            <svg class="w-5 h-5 mr-2 text-deep-teal" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"></path></svg>
            Genomic Track Viewer (IGV.js)
          </h4>
        </div>
        
        <!-- IGV Container -->
        <div ref="igvContainer" class="relative w-full border border-gray-300 bg-white rounded shadow-inner overflow-hidden" style="min-height: 500px;">
          <div class="flex items-center justify-center h-full text-gray-400">Loading Genome Browser...</div>
        </div>
      </div>

      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="bg-gray-50 border-b border-gray-200 text-xs uppercase text-gray-500 tracking-wider">
            <th class="p-4 font-semibold">Category</th>
            <th class="p-4 font-semibold">Feature / Gene</th>
            <th class="p-4 font-semibold">Start BP</th>
            <th class="p-4 font-semibold">End BP</th>
            <th class="p-4 font-semibold">Score</th>
            <th class="p-4 font-semibold">Classification</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          <tr v-for="(res, idx) in paginatedResults" :key="idx" class="hover:bg-teal-50 transition-colors">
            <td class="p-4 font-medium text-gray-800">
              <span class="inline-block w-2 h-2 rounded-full mr-2" :class="getColor(res.mge_type).replace('bg-', 'bg-')"></span>
              {{ res.mge_type }}
            </td>
            <td class="p-4 font-mono text-deep-teal">{{ res.prediction }}</td>
            <td class="p-4 text-gray-600">{{ res.location_start }}</td>
            <td class="p-4 text-gray-600">{{ res.location_end }}</td>
            <td class="p-4 text-gray-600">{{ res.score !== null ? res.score : 'N/A' }}</td>
            <td class="p-4">
              <span :class="{'bg-red-100 text-red-800': res.classification === 'ACQUIRED', 'bg-blue-100 text-blue-800': res.classification === 'INTRINSIC'}" class="px-2 py-1 rounded text-xs font-bold tracking-wide">
                {{ res.classification || 'ACQUIRED' }}
              </span>
            </td>
          </tr>
          <tr v-if="data.results.length === 0">
            <td colspan="6" class="p-8 text-center text-gray-400">No MGEs detected for this sample.</td>
          </tr>
        </tbody>
      </table>
      
      <!-- Pagination Controls -->
      <div v-if="data.results.length > 0" class="p-4 border-t border-gray-100 bg-gray-50 flex justify-between items-center text-sm text-gray-600">
        <div>
          Showing {{ (currentPage - 1) * pageSize + 1 }} to {{ Math.min(currentPage * pageSize, data.results.length) }} of {{ data.results.length }} entries
        </div>
        <div class="flex space-x-2">
          <button @click="prevPage" :disabled="currentPage === 1" class="px-3 py-1 rounded border border-gray-300 disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100">Previous</button>
          <span class="px-3 py-1 font-semibold text-deep-teal">Page {{ currentPage }} of {{ totalPages }}</span>
          <button @click="nextPage" :disabled="currentPage === totalPages" class="px-3 py-1 rounded border border-gray-300 disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100">Next</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue'
import igv from 'igv'

const jobId = ref('d3b07384-d113-41a4-9279-8d19024f22f7') // default mock ID for testing
const data = ref(null)
const loading = ref(false)
const error = ref(null)
const igvContainer = ref(null)

const initIGV = () => {
  if (igvContainer.value) {
    igvContainer.value.innerHTML = '' // Clear existing content
    const options = {
      reference: {
        id: jobId.value,
        name: data.value.sample_name || 'Genome',
        fastaURL: `http://localhost:8000/api/v1/results/${jobId.value}/fasta`,
        indexed: false
      },
      tracks: [
        {
          name: "MGEs & AMR Features",
          url: `http://localhost:8000/api/v1/results/${jobId.value}/bed`,
          format: "bed",
          type: "annotation",
          displayMode: "EXPANDED",
          colorBy: "itemRgb"
        }
      ]
    }
    igv.createBrowser(igvContainer.value, options).catch(err => {
      console.error("Error creating IGV browser:", err)
    })
  }
}



// Pagination State
const currentPage = ref(1)
const pageSize = ref(15)

const totalPages = computed(() => {
  if (!data.value || !data.value.results) return 1
  return Math.ceil(data.value.results.length / pageSize.value)
})

const paginatedResults = computed(() => {
  if (!data.value || !data.value.results) return []
  const start = (currentPage.value - 1) * pageSize.value
  const end = start + pageSize.value
  return data.value.results.slice(start, end)
})

const prevPage = () => {
  if (currentPage.value > 1) currentPage.value--
}

const nextPage = () => {
  if (currentPage.value < totalPages.value) currentPage.value++
}

const fetchResults = async () => {
  if (!jobId.value) return
  loading.value = true
  error.value = null
  data.value = null
  currentPage.value = 1 // Reset on new fetch
  
  try {
    const res = await fetch(`http://localhost:8000/api/v1/results/${jobId.value}`)
    if (!res.ok) throw new Error('Failed to fetch results from database (Job ID may not exist yet)')
    data.value = await res.json()
    
    // Initialize IGV on next tick so container is mounted
    nextTick(() => {
      initIGV()
    })
  } catch (err) {
    error.value = err.message
  } finally {
    loading.value = false
  }
}
</script>
