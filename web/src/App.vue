<template>
  <div class="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800">
    <!-- Navigation -->
    <nav class="bg-slate-900 border-b border-slate-700 sticky top-0 z-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo -->
          <router-link to="/" class="flex items-center gap-3 hover:opacity-80 transition">
            <div class="w-10 h-10 bg-gradient-to-br from-blue-400 to-cyan-400 rounded-lg flex items-center justify-center">
              <span class="text-sm font-bold text-slate-900">MGE</span>
            </div>
            <div>
              <h1 class="text-xl font-bold text-white">MGE-Sift</h1>
              <p class="text-xs text-slate-400">Mobile Genetic Elements</p>
            </div>
          </router-link>

          <!-- Menu -->
          <div class="flex items-center gap-8">
            <router-link
              v-for="route in routes"
              :key="route.path"
              :to="route.path"
              class="text-slate-300 hover:text-white transition px-3 py-2 rounded-md text-sm font-medium"
              :class="{ 'bg-slate-700 text-white': isActive(route.path) }"
            >
              {{ route.name }}
            </router-link>
          </div>

          <!-- Status -->
          <div class="flex items-center gap-4">
            <div v-if="store.stats" class="text-right">
              <div class="text-2xl font-bold text-white">{{ store.stats.total_samples }}</div>
              <div class="text-xs text-slate-400">Samples</div>
            </div>
            <button
              @click="showSettings = true"
              class="text-slate-400 hover:text-white transition"
            >
              <Settings class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <router-view />
    </main>

    <!-- Settings Modal -->
    <div v-if="showSettings" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-white">Settings</h2>
          <button @click="showSettings = false" class="text-slate-400 hover:text-white">
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">API Key</label>
            <input
              v-model="tempApiKey"
              type="password"
              class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-400 focus:outline-none focus:border-blue-400"
              placeholder="Enter API key"
            />
          </div>

          <div class="flex gap-2">
            <button
              @click="saveSettings"
              class="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 rounded transition"
            >
              Save
            </button>
            <button
              @click="showSettings = false"
              class="flex-1 bg-slate-700 hover:bg-slate-600 text-white font-medium py-2 rounded transition"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStore } from '@/stores/main'
import { Settings, X } from 'lucide-vue-next'

const store = useStore()
const router = useRouter()
const showSettings = ref(false)
const tempApiKey = ref('')

const routes = [
  { path: '/', name: 'Dashboard' },
  { path: '/results', name: 'Results' },
  { path: '/reports', name: 'Reports' },
  { path: '/settings', name: 'Settings' },
]

const isActive = (path: string) => {
  return router.currentRoute.value.path === path
}

const saveSettings = () => {
  if (tempApiKey.value) {
    store.setApiKey(tempApiKey.value)
  }
  showSettings.value = false
}

onMounted(() => {
  tempApiKey.value = store.apiKey
  store.fetchStats()
  store.fetchSamples()
  // Refresh stats periodically
  setInterval(() => store.fetchStats(), 30000)
})
</script>
