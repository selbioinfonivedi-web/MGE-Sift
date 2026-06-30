<template>
  <div class="p-8">
    <h2 class="text-3xl font-bold mb-6">Analysis Queue</h2>
    <div class="bg-gray-800 rounded-lg border border-gray-700 overflow-hidden">
      <table class="w-full text-left">
        <thead class="bg-gray-900 border-b border-gray-700">
          <tr>
            <th class="p-4 font-semibold">Job ID</th>
            <th class="p-4 font-semibold">Sample Name</th>
            <th class="p-4 font-semibold">Status</th>
            <th class="p-4 font-semibold">Submitted</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-700">
          <tr class="hover:bg-gray-750 transition-colors">
            <td class="p-4 font-mono text-sm text-blue-400">c8a2-411a</td>
            <td class="p-4">E_coli_O157</td>
            <td class="p-4"><span class="px-2 py-1 bg-yellow-900 text-yellow-300 rounded text-xs font-bold">RUNNING</span></td>
            <td class="p-4 text-gray-400">10 mins ago</td>
          </tr>
          <tr class="hover:bg-gray-750 transition-colors">
            <td class="p-4 font-mono text-sm text-blue-400">f9b1-229c</td>
            <td class="p-4">K_pneumoniae_ST258</td>
            <td class="p-4"><span class="px-2 py-1 bg-green-900 text-green-300 rounded text-xs font-bold">COMPLETED</span></td>
            <td class="p-4 text-gray-400">1 hour ago</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
