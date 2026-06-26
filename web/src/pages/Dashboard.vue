<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-800 to-slate-700 rounded-lg border border-slate-600 p-8">
      <h2 class="text-3xl font-bold text-white mb-2">Dashboard</h2>
      <p class="text-slate-300">Pipeline Statistics & Overview</p>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <StatCard title="Total Samples" :value="store.stats?.total_samples || 0" icon="samples" />
      <StatCard title="Total Results" :value="store.stats?.total_results || 0" icon="results" />
      <StatCard title="Processing" :value="store.stats?.samples_by_status?.['processing'] || 0" icon="processing" />
      <StatCard title="Completed" :value="store.stats?.samples_by_status?.['completed'] || 0" icon="completed" />
    </div>

    <!-- Sample Upload -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
      <h3 class="text-xl font-bold text-white mb-4">Upload Sample</h3>
      <form @submit.prevent="handleUpload" class="space-y-4">
        <div class="border-2 border-dashed border-slate-600 rounded-lg p-8 text-center hover:border-blue-400 transition cursor-pointer" @click="triggerFileInput">
          <Upload class="w-12 h-12 mx-auto text-slate-400 mb-2" />
          <p class="text-slate-300">Drag and drop your FASTA file or click to browse</p>
          <input
            ref="fileInput"
            type="file"
            accept=".fa,.fasta,.fna,.gz"
            @change="handleFileSelect"
            class="hidden"
          />
        </div>

        <div v-if="selectedFile" class="flex items-center justify-between bg-slate-700 p-3 rounded">
          <div class="flex items-center gap-2">
            <FileIcon class="w-5 h-5 text-blue-400" />
            <span class="text-white">{{ selectedFile.name }}</span>
          </div>
          <button type="button" @click="selectedFile = null" class="text-slate-400 hover:text-white">
            <X class="w-4 h-4" />
          </button>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-300 mb-2">Sample Name</label>
          <input
            v-model="sampleName"
            type="text"
            class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-400 focus:outline-none focus:border-blue-400"
            placeholder="e.g., sample_001"
          />
        </div>

        <button
          type="submit"
          :disabled="!selectedFile || !sampleName"
          class="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-600 disabled:cursor-not-allowed text-white font-medium py-2 rounded transition"
        >
          Upload & Process
        </button>
      </form>
    </div>

    <!-- Recent Samples -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 overflow-hidden">
      <div class="p-6 border-b border-slate-600">
        <h3 class="text-xl font-bold text-white">Recent Samples</h3>
      </div>

      <div v-if="store.loading" class="p-6 text-center text-slate-400">
        Loading samples...
      </div>

      <div v-else-if="store.samples.length === 0" class="p-6 text-center text-slate-400">
        No samples yet. Upload one to get started!
      </div>

      <table v-else class="w-full">
        <thead class="bg-slate-700">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Sample ID</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Status</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Created</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-300 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-700">
          <tr v-for="sample in store.samples.slice(0, 5)" :key="sample.sample_id" class="hover:bg-slate-700 transition">
            <td class="px-6 py-4 text-white font-medium">{{ sample.sample_id }}</td>
            <td class="px-6 py-4">
              <span
                :class="{
                  'bg-yellow-900 text-yellow-200': sample.status === 'processing',
                  'bg-green-900 text-green-200': sample.status === 'completed',
                  'bg-red-900 text-red-200': sample.status === 'failed',
                }"
                class="px-3 py-1 rounded-full text-xs font-medium"
              >
                {{ sample.status }}
              </span>
            </td>
            <td class="px-6 py-4 text-slate-300 text-sm">{{ formatDate(sample.created_at) }}</td>
            <td class="px-6 py-4">
              <button
                @click="store.selectSample(sample.sample_id)"
                class="text-blue-400 hover:text-blue-300 transition font-medium"
              >
                View Results →
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useStore } from '@/stores/main'
import { Upload, FileIcon, X } from 'lucide-vue-next'
import { formatDistance } from 'date-fns'
import StatCard from '@/components/StatCard.vue'

const store = useStore()
const fileInput = ref<HTMLInputElement>()
const selectedFile = ref<File | null>(null)
const sampleName = ref('')

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileSelect = (event: Event) => {
  const input = event.target as HTMLInputElement
  if (input.files?.length) {
    selectedFile.value = input.files[0]
  }
}

const handleUpload = async () => {
  if (!selectedFile.value || !sampleName.value) return

  // TODO: Implement file upload to API or initiate Nextflow pipeline
  console.log('Uploading:', sampleName.value, selectedFile.value.name)
  // For now, just reset the form
  selectedFile.value = null
  sampleName.value = ''
}

const formatDate = (date: string) => {
  return formatDistance(new Date(date), new Date(), { addSuffix: true })
}

onMounted(() => {
  store.fetchSamples()
  store.fetchStats()
})
</script>
