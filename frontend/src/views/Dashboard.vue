<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-3xl font-bold text-dark-text">Genomic Database</h2>
      <div class="flex space-x-2">
        <input v-model="jobId" type="text" placeholder="Enter Job ID to load..." class="border border-gray-300 rounded px-3 py-2 text-sm w-64 focus:outline-none focus:border-deep-teal">
        <button @click="fetchResults" class="bg-deep-teal text-white px-4 py-2 rounded shadow hover:bg-teal-800 transition">Fetch</button>
      </div>
    </div>
    
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const jobId = ref('')

const fetchResults = () => {
  if (!jobId.value) return
  router.push(`/results/${jobId.value}`)
}
</script>
