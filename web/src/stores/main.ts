import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Sample, AnalysisResult, SampleReport, PipelineStats } from '@/api'
import { api } from '@/api'

export const useStore = defineStore('main', () => {
  // State
  const samples = ref<Sample[]>([])
  const results = ref<AnalysisResult[]>([])
  const reports = ref<Map<string, SampleReport>>(new Map())
  const stats = ref<PipelineStats | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const selectedSample = ref<string | null>(null)
  const apiKey = ref(localStorage.getItem('api_key') || '')

  // Computed
  const selectedSampleData = computed(() => {
    if (!selectedSample.value) return null
    return samples.value.find((s) => s.sample_id === selectedSample.value)
  })

  const selectedSampleReport = computed(() => {
    if (!selectedSample.value) return null
    return reports.value.get(selectedSample.value)
  })

  // Actions
  const setApiKey = (key: string) => {
    apiKey.value = key
    localStorage.setItem('api_key', key)
  }

  const fetchSamples = async () => {
    loading.value = true
    error.value = null
    try {
      const response = await api.listSamples()
      samples.value = response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to fetch samples'
    } finally {
      loading.value = false
    }
  }

  const fetchResults = async (sampleId?: string) => {
    loading.value = true
    error.value = null
    try {
      const response = await api.getResults(sampleId)
      results.value = response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to fetch results'
    } finally {
      loading.value = false
    }
  }

  const fetchSampleReport = async (sampleId: string) => {
    try {
      const response = await api.getSampleReport(sampleId)
      reports.value.set(sampleId, response.data)
    } catch (err: any) {
      error.value = err.message || 'Failed to fetch report'
    }
  }

  const fetchStats = async () => {
    try {
      const response = await api.stats()
      stats.value = response.data
    } catch (err: any) {
      console.error('Failed to fetch stats:', err)
    }
  }

  const selectSample = async (sampleId: string) => {
    selectedSample.value = sampleId
    await fetchResults(sampleId)
    await fetchSampleReport(sampleId)
  }

  const exportResults = async (format: 'json' | 'csv', sampleId?: string) => {
    try {
      const response = await api.exportResults(format, sampleId)
      return response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to export results'
      return null
    }
  }

  return {
    // State
    samples,
    results,
    reports,
    stats,
    loading,
    error,
    selectedSample,
    apiKey,

    // Computed
    selectedSampleData,
    selectedSampleReport,

    // Actions
    setApiKey,
    fetchSamples,
    fetchResults,
    fetchSampleReport,
    fetchStats,
    selectSample,
    exportResults,
  }
})
