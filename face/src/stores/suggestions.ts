import { defineStore } from 'pinia'
import { fetchSuggestions } from '../api'
import { useAuthStore } from './auth'

export const useSuggestionsStore = defineStore('suggestions', () => {
  const auth = useAuthStore()

  const { state, isReady, isLoading, execute, error } = useAsyncState(() => fetchSuggestions(), null, {
    immediate: false,
    shallow: true,
  })

  whenever(
    () => !state.value && auth.key,
    () => execute(),
    { immediate: true },
  )

  return {
    state,
    isReady,
    isLoading,
    error,
    execute,
  }
})
