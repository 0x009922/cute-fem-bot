import { defineStore } from 'pinia'

export const useAuthStore = defineStore('auth', () => {
  const key = ref('')

  return { key }
})
