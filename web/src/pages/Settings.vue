<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="bg-gradient-to-r from-slate-800 to-slate-700 rounded-lg border border-slate-600 p-8">
      <h2 class="text-3xl font-bold text-white mb-2">Settings</h2>
      <p class="text-slate-300">Configure API and application preferences</p>
    </div>

    <!-- API Configuration -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6 space-y-6">
      <div>
        <h3 class="text-lg font-bold text-white mb-4">API Configuration</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">API Endpoint</label>
            <input
              v-model="apiEndpoint"
              type="text"
              class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-400 focus:outline-none focus:border-blue-400"
              placeholder="http://localhost:8000"
            />
            <p class="text-xs text-slate-400 mt-1">Base URL for API requests</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">API Key</label>
            <div class="flex gap-2">
              <input
                v-model="apiKey"
                :type="showApiKey ? 'text' : 'password'"
                class="flex-1 px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-400 focus:outline-none focus:border-blue-400"
                placeholder="Enter your API key"
              />
              <button
                type="button"
                @click="showApiKey = !showApiKey"
                class="px-3 py-2 bg-slate-700 hover:bg-slate-600 text-slate-300 rounded transition"
              >
                {{ showApiKey ? 'Hide' : 'Show' }}
              </button>
            </div>
            <p class="text-xs text-slate-400 mt-1">Secure token for API authentication</p>
          </div>

          <button
            @click="testConnection"
            :disabled="testing"
            class="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-600 text-white font-medium py-2 rounded transition"
          >
            {{ testing ? 'Testing...' : 'Test Connection' }}
          </button>

          <div v-if="connectionStatus" :class="{ 'bg-green-900 text-green-200': connectionStatus.success, 'bg-red-900 text-red-200': !connectionStatus.success }" class="p-3 rounded">
            {{ connectionStatus.message }}
          </div>
        </div>
      </div>
    </div>

    <!-- Appearance -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6 space-y-6">
      <div>
        <h3 class="text-lg font-bold text-white mb-4">Appearance</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">Theme</label>
            <select class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400">
              <option selected>Dark</option>
              <option>Light</option>
              <option>Auto</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">Results Per Page</label>
            <input
              type="number"
              min="10"
              max="100"
              value="25"
              class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Pipeline Settings -->
    <div class="bg-slate-800 rounded-lg border border-slate-600 p-6 space-y-6">
      <div>
        <h3 class="text-lg font-bold text-white mb-4">Pipeline Defaults</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">Max CPUs</label>
            <input
              type="number"
              min="1"
              max="32"
              value="4"
              class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-300 mb-2">Max Memory (GB)</label>
            <input
              type="number"
              min="2"
              max="256"
              value="8"
              class="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:outline-none focus:border-blue-400"
            />
          </div>

          <div>
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" class="w-4 h-4" />
              <span class="text-sm font-medium text-slate-300">Auto-refresh results</span>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- Save Button -->
    <div class="flex gap-3">
      <button @click="saveSettings" class="flex-1 bg-green-600 hover:bg-green-700 text-white font-medium py-2 rounded transition">
        Save Settings
      </button>
      <button @click="resetSettings" class="flex-1 bg-slate-700 hover:bg-slate-600 text-white font-medium py-2 rounded transition">
        Reset to Defaults
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useStore } from '@/stores/main'
import { api } from '@/api'

const store = useStore()
const apiEndpoint = ref(localStorage.getItem('api_endpoint') || 'http://localhost:8000')
const apiKey = ref(store.apiKey)
const showApiKey = ref(false)
const testing = ref(false)
const connectionStatus = ref<{ success: boolean; message: string } | null>(null)

const testConnection = async () => {
  testing.value = true
  try {
    await api.health()
    connectionStatus.value = {
      success: true,
      message: '✓ Connection successful!',
    }
  } catch (error: any) {
    connectionStatus.value = {
      success: false,
      message: `✗ Connection failed: ${error.message}`,
    }
  } finally {
    testing.value = false
  }
}

const saveSettings = () => {
  if (apiKey.value) {
    store.setApiKey(apiKey.value)
  }
  localStorage.setItem('api_endpoint', apiEndpoint.value)
  connectionStatus.value = { success: true, message: '✓ Settings saved!' }
}

const resetSettings = () => {
  apiEndpoint.value = 'http://localhost:8000'
  apiKey.value = 'dev-key-change-in-production'
}
</script>
