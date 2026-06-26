<template>
  <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
    <p class="text-slate-400 text-sm font-medium">{{ title }}</p>
    <p class="text-3xl font-bold text-white mt-2">{{ value }}</p>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string
  value: string | number
}>()
</script>
