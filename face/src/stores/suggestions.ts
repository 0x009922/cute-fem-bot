import { defineStore } from 'pinia'
import { fetchSuggestions, SchemaSuggestionType } from '../api'
import { computeSuggestionType } from '../util'
import { useAuthStore } from './auth'

export const useSuggestionsStore = defineStore('suggestions', () => {
  const auth = useAuthStore()

  const { state, isReady, isLoading, execute, error } = useAsyncState(() => fetchSuggestions(), null, {
    immediate: false,
    shallow: true,
    resetOnExecute: false,
  })

  whenever(
    () => !state.value && auth.key,
    () => execute(),
    { immediate: true },
  )

  const suggestionsMapped = $computed(() => {
    const items = state.value?.suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, x]))
  })

  const usersList = computed(() => state.value?.users ?? null)
  const usersMap = computed(() => {
    const list = usersList.value
    if (!list) return null
    return new Map(list.map((x) => [x.id, x]))
  })

  const suggestionTypes = $computed<null | Map<string, SchemaSuggestionType>>(() => {
    const items = state.value?.suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, computeSuggestionType(x.file_type, x.file_mime_type)]))
  })

  return $$({
    state,
    isReady,
    isLoading,
    error,
    execute,

    suggestionsMapped,
    usersList,
    usersMap,
    suggestionTypes,
  })
})
