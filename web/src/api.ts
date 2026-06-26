import axios, { AxiosInstance } from 'axios'

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000'
const API_KEY = localStorage.getItem('api_key') || 'dev-key-change-in-production'

const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
    'x-token': API_KEY,
  },
})

// Add response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Handle unauthorized
      localStorage.removeItem('api_key')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default apiClient

export interface Sample {
  sample_id: string
  fasta_path: string
  created_at: string
  status: string
}

export interface AnalysisResult {
  sample_id: string
  element_type: string
  element_id: string
  location: string
  confidence: number
  classification: string
  metadata: Record<string, unknown>
  timestamp: string
}

export interface SampleReport {
  sample_id: string
  total_elements: number
  element_types: Record<string, number>
  avg_confidence: number
  classifications: Record<string, number>
  timestamp: string
}

export interface PipelineStats {
  total_samples: number
  total_results: number
  samples_by_status: Record<string, number>
  timestamp: string
}

// API Methods
export const api = {
  // Health & Stats
  health: () => apiClient.get('/health'),
  stats: () => apiClient.get<PipelineStats>('/stats'),

  // Samples
  listSamples: (skip = 0, limit = 100) =>
    apiClient.get<Sample[]>('/samples', { params: { skip, limit } }),
  getSample: (sampleId: string) => apiClient.get<Sample>(`/samples/${sampleId}`),

  // Results
  getResults: (sampleId?: string, elementType?: string, skip = 0, limit = 100) =>
    apiClient.get<AnalysisResult[]>('/results', {
      params: { sample_id: sampleId, element_type: elementType, skip, limit },
    }),
  submitResult: (result: Omit<AnalysisResult, 'timestamp'>) =>
    apiClient.post('/results', result),

  // Reports
  getSampleReport: (sampleId: string) =>
    apiClient.get<SampleReport>(`/samples/${sampleId}/report`),

  // Export
  exportResults: (format: 'json' | 'csv', sampleId?: string) =>
    apiClient.get('/results/export', {
      params: { format, sample_id: sampleId },
      responseType: format === 'csv' ? 'text' : 'json',
    }),
}
