import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/', component: () => import('../views/Dashboard.vue') },
  { path: '/upload', component: () => import('../views/Upload.vue') },
  { path: '/queue', component: () => import('../views/Queue.vue') }
]

export const router = createRouter({
  history: createWebHistory(),
  routes
})
