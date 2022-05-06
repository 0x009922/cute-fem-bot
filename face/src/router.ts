import { createRouter, createWebHistory } from 'vue-router'

export default createRouter({
  history: createWebHistory(),
  routes: [
    {
      name: 'main',
      path: '/:key?',
      component: () => import('./components/ViewMain.vue'),
      children: [
        {
          name: 'suggestions',
          path: 'suggestions',
          component: () => import('./components/ViewSuggestions/ViewSuggestions.vue'),
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/',
    },
  ],
})
