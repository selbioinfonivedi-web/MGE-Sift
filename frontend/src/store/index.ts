import { defineStore } from 'pinia'

export const useJobStore = defineStore('jobs', {
  state: () => ({
    jobs: []
  }),
  actions: {
    addJob(jobId: string) {
      this.jobs.push({ id: jobId, status: 'QUEUED' })
    }
  }
})
