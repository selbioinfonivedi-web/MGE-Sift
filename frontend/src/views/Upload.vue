<template>
  <div class="p-8 max-w-4xl mx-auto">
    <h2 class="text-3xl font-bold mb-6">Upload Genome</h2>
    <div class="border-4 border-dashed border-gray-600 rounded-xl p-16 text-center hover:bg-gray-800 transition-colors cursor-pointer">
      <p class="text-xl text-gray-300">Drag and drop FASTA/FASTQ files here</p>
      <p class="text-sm text-gray-500 mt-2">or click to browse</p>
      <input type="file" class="hidden" multiple accept=".fasta,.fna,.fastq,.gz" />
    </div>
  </div>
</template>
