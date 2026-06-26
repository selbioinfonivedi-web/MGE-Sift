<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-800 to-slate-700 rounded-lg border border-slate-600 p-8">
      <h2 class="text-3xl font-bold text-white mb-2">Sample Reports</h2>
      <p class="text-slate-300">Comprehensive analysis summaries</p>
    </div>

    <!-- Sample Selection -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
      <label class="block text-sm font-medium text-slate-300 mb-2">Select Sample</label>
      <select
        v-model="selectedSample"
        @change="loadReport"
        class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
      >
        <option value="">-- Choose a sample --</option>
        <option v-for="sample in store.samples" :key="sample.sample_id" :value="sample.sample_id">
          {{ sample.sample_id }}
        </option>
      </select>
    </div>

    <!-- Report -->
    <div v-if="report" class="space-y-6">
      <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <ReportCard title="Total Elements" :value="report.total_elements" />
        <ReportCard title="Avg Confidence" :value="`${(report.avg_confidence * 100).toFixed(1)}%`" />
        <ReportCard title="Acquired" :value="report.classifications.acquired" />
        <ReportCard title="Intrinsic" :value="report.classifications.intrinsic" />
      </div>

      <!-- Element Type Distribution -->
      <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
        <h3 class="text-lg font-bold text-white mb-4">Element Type Distribution</h3>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <div
            v-for="(count, type) in report.element_types"
            :key="type"
            class="bg-slate-700 p-4 rounded border border-slate-600"
          >
            <div class="text-2xl font-bold text-blue-400">{{ count }}</div>
            <div class="text-sm text-slate-300 capitalize">{{ type.replace(/_/g, ' ') }}</div>
          </div>
        </div>
      </div>

      <!-- Pie Chart -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
          <h3 class="text-lg font-bold text-white mb-4">Classifications</h3>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-slate-300">Acquired</span>
              <div class="w-32 bg-slate-700 rounded-full h-2">
                <div
                  class="bg-green-500 h-2 rounded-full"
                  :style="{ width: classificationPercentage('acquired') + '%' }"
                ></div>
              </div>
              <span class="text-white font-medium">{{ report.classifications.acquired }}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-slate-300">Intrinsic</span>
              <div class="w-32 bg-slate-700 rounded-full h-2">
                <div
                  class="bg-blue-500 h-2 rounded-full"
                  :style="{ width: classificationPercentage('intrinsic') + '%' }"
                ></div>
              </div>
              <span class="text-white font-medium">{{ report.classifications.intrinsic }}</span>
            </div>
          </div>
        </div>

        <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
          <h3 class="text-lg font-bold text-white mb-4">Report Info</h3>
          <div class="space-y-2">
            <div>
              <span class="text-slate-400">Sample ID:</span>
              <span class="text-white font-medium ml-2">{{ report.sample_id }}</span>
            </div>
            <div>
              <span class="text-slate-400">Analysis Date:</span>
              <span class="text-white font-medium ml-2">{{ formatDate(report.timestamp) }}</span>
            </div>
            <div>
              <span class="text-slate-400">Total Detections:</span>
              <span class="text-white font-medium ml-2">{{ report.total_elements }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Export -->
      <div class="flex gap-3">
        <button
          @click="downloadReport('json')"
          class="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 rounded transition"
        >
          Download JSON
        </button>
        <button
          @click="downloadReport('pdf')"
          class="flex-1 bg-red-600 hover:bg-red-700 text-white font-medium py-2 rounded transition"
        >
          Download PDF
        </button>
      </div>
    </div>

    <div v-else class="bg-slate-800 rounded-lg border border-slate-600 p-12 text-center text-slate-400">
      Select a sample to view its analysis report
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useStore } from '@/stores/main'
import { formatDistanceToNow } from 'date-fns'
import ReportCard from '@/components/ReportCard.vue'

const store = useStore()
const selectedSample = ref('')

const report = computed(() => {
  if (!selectedSample.value) return null
  return store.reports.get(selectedSample.value) || null
})

const classificationPercentage = (type: string) => {
  if (!report.value) return 0
  const total = report.value.total_elements
  if (total === 0) return 0
  return (report.value.classifications[type] / total) * 100
}

const formatDate = (date: string) => {
  return formatDistanceToNow(new Date(date), { addSuffix: true })
}

const loadReport = async () => {
  if (selectedSample.value) {
    await store.fetchSampleReport(selectedSample.value)
  }
}

const downloadReport = (format: string) => {
  if (!report.value) return
  const data = JSON.stringify(report.value, null, 2)
  const blob = new Blob([data], { type: 'application/json' })
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `report_${report.value.sample_id}.${format === 'json' ? 'json' : 'txt'}`
  a.click()
}
</script>
