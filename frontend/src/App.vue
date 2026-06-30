<template>
  <div class="min-h-screen bg-warm-white text-dark-text flex">
    <!-- Sidebar -->
    <aside class="w-64 bg-white border-r border-gray-200 flex flex-col shadow-sm">
      <div class="p-6 border-b border-gray-100">
        <h1 class="text-2xl font-extrabold text-deep-teal tracking-tight">
          VetGenome Hub
        </h1>
        <p class="text-xs text-gray-500 mt-1 uppercase tracking-wider font-semibold">MGE-Sift Module</p>
      </div>
      <nav class="flex-1 p-4 space-y-2">
        <router-link to="/upload" class="block px-4 py-2 rounded-md hover:bg-teal-50 hover:text-deep-teal transition-colors font-medium">Pipeline</router-link>
        <router-link to="/queue" class="block px-4 py-2 rounded-md hover:bg-teal-50 hover:text-deep-teal transition-colors font-medium">Logs</router-link>
        <router-link to="/" class="block px-4 py-2 rounded-md hover:bg-teal-50 hover:text-deep-teal transition-colors font-medium text-deep-teal bg-teal-50">Database</router-link>
        <a href="#" class="block px-4 py-2 rounded-md hover:bg-teal-50 hover:text-deep-teal transition-colors font-medium text-gray-500">Resistome</a>
      </nav>
    </aside>

    <!-- Main Content -->
    <main class="flex-1 p-8">
      <router-view></router-view>
    </main>
  </div>
</template>

<style>
body { margin: 0; font-family: 'Inter', sans-serif; background-color: #FDFBF7; }
</style>
