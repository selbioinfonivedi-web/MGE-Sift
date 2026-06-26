<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-800 to-slate-700 rounded-lg border border-slate-600 p-8">
      <div class="flex justify-between items-center">
        <div>
          <h2 class="text-3xl font-bold text-white mb-2">Analysis Results</h2>
          <p class="text-slate-300">View and filter detection results</p>
        </div>
        <button
          @click="exportResults('csv')"
          class="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded transition"
        >
          <Download class="w-4 h-4" />
          Export CSV
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6 space-y-4">
      <h3 class="text-lg font-bold text-white">Filters</h3>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-slate-300 mb-2">Sample</label>
          <select
            v-model="selectedSample"
            @change="handleSampleChange"
            class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
          >
            <option value="">All Samples</option>
            <option v-for="sample in store.samples" :key="sample.sample_id" :value="sample.sample_id">
              {{ sample.sample_id }}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-300 mb-2">Element Type</label>
          <select
            v-model="filterElementType"
            class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
          >
            <option value="">All Types</option>
            <option value="plasmid">Plasmid</option>
            <option value="prophage">Prophage</option>
            <option value="is_element">IS Element</option>
            <option value="integron">Integron</option>
            <option value="genomic_island">Genomic Island</option>
            <option value="repeat">Repeat</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-300 mb-2">Min Confidence</label>
          <input
            v-model.number="minConfidence"
            type="range"
            min="0"
            max="1"
            step="0.1"
            class="w-full"
          />
          <div class="text-xs text-slate-400">{{ (minConfidence * 100).toFixed(0) }}%</div>
        </div>
      </div>
    </div>

    <!-- Results Table -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 overflow-hidden">
      <div class="p-6 border-b border-slate-600">
        <h3 class="text-lg font-bold text-white">Detected Elements</h3>
      </div>

      <div v-if="store.loading" class="p-6 text-center text-slate-400">
        <div class="inline-block animate-spin">
          <Activity class="w-6 h-6" />
        </div>
        <p class="mt-2">Loading results...</p>
      </div>

      <div v-else-if="filteredResults.length === 0" class="p-6 text-center text-slate-400">
        No results found with the selected filters
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-slate-700">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Sample</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Element Type</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Element ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Location</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Confidence</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Classification</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-700">
            <tr v-for="result in filteredResults" :key="`${result.sample_id}-${result.element_id}`" class="hover:bg-slate-700 transition">
              <td class="px-6 py-4 text-white font-medium text-sm">{{ result.sample_id }}</td>
              <td class="px-6 py-4">
                <span class="px-2 py-1 bg-slate-700 text-slate-200 rounded text-xs font-medium">
                  {{ result.element_type }}
                </span>
              </td>
              <td class="px-6 py-4 text-white text-sm">{{ result.element_id }}</td>
              <td class="px-6 py-4 text-slate-300 text-sm">{{ result.location }}</td>
              <td class="px-6 py-4">
                <div class="flex items-center gap-2">
                  <div class="w-16 bg-slate-700 rounded-full h-2">
                    <div
                      class="bg-blue-500 h-2 rounded-full"
                      :style="{ width: `${result.confidence * 100}%` }"
                    ></div>
                  </div>
                  <span class="text-white font-medium text-sm">{{ (result.confidence * 100).toFixed(1) }}%</span>
                </div>
              </td>
              <td class="px-6 py-4">
                <span
                  :class="{
                    'bg-green-900 text-green-200': result.classification === 'acquired',
                    'bg-blue-900 text-blue-200': result.classification === 'intrinsic',
                  }"
                  class="px-2 py-1 rounded text-xs font-medium"
                >
                  {{ result.classification }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div class="px-6 py-4 border-t border-slate-600 flex justify-between items-center">
        <div class="text-sm text-slate-400">
          Showing {{ filteredResults.length }} of {{ store.results.length }} results
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useStore } from '@/stores/main'
import { Download, Activity } from 'lucide-vue-next'
import type { AnalysisResult } from '@/api'

const store = useStore()
const selectedSample = ref('')
const filterElementType = ref('')
const minConfidence = ref(0)

const filteredResults = computed(() => {
  return store.results.filter((result) => {
    if (filterElementType.value && result.element_type !== filterElementType.value) {
      return false
    }
    if (result.confidence < minConfidence.value) {
      return false
    }
    return true
  })
})

const handleSampleChange = async () => {
  if (selectedSample.value) {
    await store.selectSample(selectedSample.value)
  } else {
    await store.fetchResults()
  }
}

const exportResults = async (format: 'json' | 'csv') => {
  const data = await store.exportResults(format, selectedSample.value || undefined)
  if (data) {
    // Trigger download
    const blob = new Blob([JSON.stringify(data)], { type: 'application/json' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `results_${new Date().toISOString()}.${format}`
    a.click()
  }
}

onMounted(() => {
  store.fetchResults()
})
</script>
