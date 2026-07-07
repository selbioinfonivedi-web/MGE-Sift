<template>
  <div class="p-8">
    <h2 class="text-3xl font-bold mb-6">Analysis Queue</h2>
    <div class="bg-gray-800 rounded-lg border border-gray-700 overflow-hidden">
      <table class="w-full text-left">
        <thead class="bg-gray-900 border-b border-gray-700 text-gray-300">
          <tr>
            <th class="p-4 font-semibold">Job ID</th>
            <th class="p-4 font-semibold">Sample Name</th>
            <th class="p-4 font-semibold">Status</th>
            <th class="p-4 font-semibold">Submitted</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-700 text-gray-300">
          <tr v-for="job in jobs" :key="job.id" class="hover:bg-gray-750 transition-colors">
            <td class="p-4 font-mono text-sm text-blue-400">{{ job.id }}</td>
            <td class="p-4 font-semibold">{{ job.sample_name }}</td>
            <td class="p-4">
              <span 
                :class="{
                  'bg-yellow-900 text-yellow-300': job.status === 'RUNNING',
                  'bg-green-900 text-green-300': job.status === 'COMPLETED',
                  'bg-gray-600 text-gray-300': job.status === 'QUEUED',
                  'bg-red-900 text-red-300': job.status === 'FAILED'
                }"
                class="px-2 py-1 rounded text-xs font-bold"
              >
                {{ job.status }}
              </span>
            </td>
            <td class="p-4 text-gray-400 text-sm">{{ formatDate(job.created_at) }}</td>
          </tr>
          <tr v-if="jobs.length === 0">
            <td colspan="4" class="p-8 text-center text-gray-500">No jobs in the queue yet.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const jobs = ref([])
let pollInterval = null

const fetchJobs = async () => {
  try {
    const res = await fetch('http://localhost:8000/api/v1/analysis/')
    if (res.ok) {
      jobs.value = await res.json()
    }
  } catch (error) {
    console.error("Failed to fetch queue", error)
  }
}

const formatDate = (dateString) => {
  if (!dateString) return 'Unknown'
  const date = new Date(dateString)
  return date.toLocaleString()
}

onMounted(() => {
  fetchJobs()
  // Poll every 5 seconds to update the queue status
  pollInterval = setInterval(fetchJobs, 5000)
})

onUnmounted(() => {
  if (pollInterval) clearInterval(pollInterval)
})
</script>
