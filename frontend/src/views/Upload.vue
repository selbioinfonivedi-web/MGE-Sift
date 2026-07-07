<template>
  <div class="p-8 max-w-4xl mx-auto">
    <h2 class="text-3xl font-bold mb-6 text-gray-800">Upload Genome</h2>
    <div 
      @click="triggerFileInput"
      @dragover.prevent="dragOver = true"
      @dragleave.prevent="dragOver = false"
      @drop.prevent="handleDrop"
      :class="['border-4 border-dashed rounded-xl p-16 text-center transition-colors cursor-pointer', dragOver ? 'border-teal-500 bg-teal-50' : 'border-gray-400 hover:bg-gray-100']"
    >
      <div v-if="uploading" class="text-xl font-bold text-teal-600 animate-pulse">
        Uploading and queuing file...
      </div>
      <div v-else>
        <p class="text-xl text-gray-600">Drag and drop FASTA/FASTQ files here</p>
        <p class="text-sm text-gray-500 mt-2">or click to browse</p>
      </div>
      <input 
        ref="fileInput" 
        @change="handleFileSelect" 
        type="file" 
        class="hidden" 
        accept=".fasta,.fna,.fastq,.gz,.fa" 
      />
    </div>

    <div v-if="successMsg" class="mt-6 p-4 bg-green-100 border border-green-400 text-green-700 rounded relative">
      <strong class="font-bold">Success!</strong>
      <span class="block sm:inline"> {{ successMsg }}</span>
    </div>
    
    <div v-if="errorMsg" class="mt-6 p-4 bg-red-100 border border-red-400 text-red-700 rounded relative">
      <strong class="font-bold">Error!</strong>
      <span class="block sm:inline"> {{ errorMsg }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const fileInput = ref(null)
const dragOver = ref(false)
const uploading = ref(false)
const successMsg = ref(null)
const errorMsg = ref(null)

const triggerFileInput = () => {
  if (fileInput.value) {
    fileInput.value.click()
  }
}

const handleDrop = (e) => {
  dragOver.value = false
  const files = e.dataTransfer.files
  if (files && files.length > 0) {
    uploadFile(files[0])
  }
}

const handleFileSelect = (e) => {
  const files = e.target.files
  if (files && files.length > 0) {
    uploadFile(files[0])
  }
}

const uploadFile = async (file) => {
  successMsg.value = null
  errorMsg.value = null
  uploading.value = true

  const formData = new FormData()
  formData.append('file', file)

  try {
    const response = await fetch('http://localhost:8000/api/v1/upload/', {
      method: 'POST',
      body: formData
    })

    const result = await response.json()

    if (!response.ok) {
      throw new Error(result.error || result.detail || 'Upload failed')
    }

    successMsg.value = `File uploaded! Job ID: ${result.job_id}. You can now track it in the Dashboard.`
    
    if (fileInput.value) {
      fileInput.value.value = ''
    }
  } catch (error) {
    errorMsg.value = error.message || 'An error occurred during upload.'
  } finally {
    uploading.value = false
  }
}
</script>
