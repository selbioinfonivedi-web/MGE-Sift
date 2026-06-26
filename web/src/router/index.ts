import { createRouter, createWebHistory } from 'vue-router'
import Dashboard from '@/pages/Dashboard.vue'
import Results from '@/pages/Results.vue'
import Reports from '@/pages/Reports.vue'
import Settings from '@/pages/Settings.vue'

const routes = [
  {
    path: '/',
    name: 'Dashboard',
    component: Dashboard,
  },
  {
    path: '/results',
    name: 'Results',
    component: Results,
  },
  {
    path: '/reports',
    name: 'Reports',
    component: Reports,
  },
  {
    path: '/settings',
    name: 'Settings',
    component: Settings,
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
