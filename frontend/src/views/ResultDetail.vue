<template>
  <div class="max-w-6xl mx-auto p-6 space-y-6">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-sm p-6 border border-gray-100 flex justify-between items-start">
      <div>
        <h1 class="text-2xl font-bold text-gray-900 mb-2">Detailed Results</h1>
        <div v-if="job" class="space-y-1 text-sm text-gray-600">
          <p><span class="font-semibold">Sample Name:</span> {{ job.sample_name }}</p>
          <p><span class="font-semibold">Job ID:</span> <span class="font-mono text-xs bg-gray-100 px-1 rounded">{{ job.job_id }}</span></p>
          <p>
            <span class="font-semibold">Status:</span> 
            <span class="px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 ml-2">
              {{ job.status }}
            </span>
          </p>
        </div>
        <div v-else class="text-gray-500">Loading job details...</div>
      </div>
      <div>
        <a 
          v-if="job" 
          :href="`http://localhost:8000/api/v1/results/${job.job_id}/download?format=pdf`" 
          target="_blank"
          class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-md shadow-sm transition-colors"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
          </svg>
          Download Report
        </a>
      </div>
    </div>

    <!-- IGV Browser -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100 bg-gray-50">
        <h2 class="text-lg font-semibold text-gray-900">Interactive Genome Browser</h2>
      </div>
      <div class="p-6">
        <div ref="igvContainer" class="w-full min-h-[400px] border border-gray-200 rounded-md"></div>
      </div>
    </div>

    <!-- Tabular Results -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100 bg-gray-50">
        <h2 class="text-lg font-semibold text-gray-900">Detected Mobile Genetic Elements</h2>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">MGE Type</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Classification</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Prediction</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Score</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="(result, index) in job?.results || []" :key="index" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-medium" :class="getTypeColor(result.mge_type)">
                  {{ result.mge_type }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ result.classification }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                {{ result.prediction }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ result.location_start }} - {{ result.location_end }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ (result.score * 100).toFixed(1) }}%
              </td>
            </tr>
            <tr v-if="!job?.results?.length && job">
              <td colspan="5" class="px-6 py-8 text-center text-gray-500 text-sm">
                No mobile genetic elements detected in this sample.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import igv from 'igv'

const route = useRoute()
const job = ref(null)
const igvContainer = ref(null)
const browserInstance = ref(null)

const getTypeColor = (type) => {
  const colors = {
    'AMR': 'bg-red-100 text-red-800',
    'Integron': 'bg-blue-100 text-blue-800',
    'Prophage': 'bg-purple-100 text-purple-800',
    'Plasmid': 'bg-green-100 text-green-800',
    'IS_Element': 'bg-yellow-100 text-yellow-800',
    'Genomic_Island': 'bg-teal-100 text-teal-800'
  }
  return colors[type] || 'bg-gray-100 text-gray-800'
}

onMounted(async () => {
  const jobId = route.params.id
  
  try {
    const res = await fetch(`http://localhost:8000/api/v1/results/${jobId}`)
    if (res.ok) {
      job.value = await res.json()
      
      // Initialize IGV
      if (igvContainer.value) {
        const options = {
          genomeList: false, // Don't show public genome selector
          reference: {
            id: job.value.sample_name,
            fastaURL: `http://localhost:8000/api/v1/results/${jobId}/fasta`
          },
          tracks: [
            {
              name: "Detected MGEs",
              type: "annotation",
              format: "bed",
              url: `http://localhost:8000/api/v1/results/${jobId}/bed`,
              displayMode: "EXPANDED",
              color: (feature) => {
                // Feature color should be derived from the RGB in BED, but fallback here
                return feature.color || "#6b7280"
              }
            }
          ]
        }
        browserInstance.value = await igv.createBrowser(igvContainer.value, options)
      }
    } else {
      console.error("Failed to load results")
    }
  } catch (error) {
    console.error("Error fetching results or initializing IGV:", error)
  }
})

onBeforeUnmount(() => {
  if (browserInstance.value) {
    igv.removeBrowser(browserInstance.value)
  }
})
</script>
