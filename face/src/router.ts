import { createRouter, createWebHistory } from 'vue-router'

export default createRouter({
  history: createWebHistory(),
  routes: [
    {
      name: 'main',
      path: '/:key?',
      component: () => import('./pages/main.vue'),
      children: [
        {
          name: 'suggestions',
          path: 'suggestions',
          component: () => import('./pages/suggestions.vue'),
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/',
    },
  ],
})
