<template>
  <div class="bg-slate-800 rounded-lg border border-slate-600 p-6">
    <div class="flex justify-between items-start">
      <div>
        <p class="text-slate-400 text-sm font-medium">{{ title }}</p>
        <p class="text-3xl font-bold text-white mt-2">{{ value }}</p>
      </div>
      <div class="text-slate-600">
        <component :is="iconComponent" class="w-8 h-8" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { BarChart3, Activity, CheckCircle, Zap } from 'lucide-vue-next'

const props = defineProps<{
  title: string
  value: string | number
  icon?: 'samples' | 'results' | 'processing' | 'completed'
}>()

const iconComponent = computed(() => {
  switch (props.icon) {
    case 'samples':
      return BarChart3
    case 'results':
      return Activity
    case 'completed':
      return CheckCircle
    case 'processing':
      return Zap
    default:
      return BarChart3
  }
})
</script>
