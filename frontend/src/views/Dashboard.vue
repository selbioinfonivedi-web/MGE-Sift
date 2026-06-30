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
      
      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="bg-gray-50 border-b border-gray-200 text-xs uppercase text-gray-500 tracking-wider">
            <th class="p-4 font-semibold">Category</th>
            <th class="p-4 font-semibold">Feature / Gene</th>
            <th class="p-4 font-semibold">Start BP</th>
            <th class="p-4 font-semibold">End BP</th>
            <th class="p-4 font-semibold">Classification</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 text-sm">
          <tr v-for="(res, idx) in data.results" :key="idx" class="hover:bg-teal-50 transition-colors">
            <td class="p-4 font-medium text-gray-800">{{ res.mge_type }}</td>
            <td class="p-4 font-mono text-deep-teal">{{ res.prediction }}</td>
            <td class="p-4 text-gray-600">{{ res.location_start }}</td>
            <td class="p-4 text-gray-600">{{ res.location_end }}</td>
            <td class="p-4">
              <span :class="{'bg-red-100 text-red-800': res.classification === 'ACQUIRED', 'bg-blue-100 text-blue-800': res.classification === 'INTRINSIC'}" class="px-2 py-1 rounded text-xs font-bold tracking-wide">
                {{ res.classification || 'ACQUIRED' }}
              </span>
            </td>
          </tr>
          <tr v-if="data.results.length === 0">
            <td colspan="5" class="p-8 text-center text-gray-400">No MGEs detected for this sample.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const jobId = ref('d3b07384-d113-41a4-9279-8d19024f22f7') // default mock ID for testing
const data = ref(null)
const loading = ref(false)
const error = ref(null)

const fetchResults = async () => {
  if (!jobId.value) return
  loading.value = true
  error.value = null
  data.value = null
  
  try {
    const res = await fetch(`http://localhost:8000/api/v1/results/${jobId.value}`)
    if (!res.ok) throw new Error('Failed to fetch results from database (Job ID may not exist yet)')
    data.value = await res.json()
  } catch (err) {
    error.value = err.message
  } finally {
    loading.value = false
  }
}
</script>
