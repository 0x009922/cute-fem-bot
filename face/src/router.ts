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
          path: '',
          component: () => import('./components/ViewSuggestions.vue'),
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/',
    },
  ],
})
