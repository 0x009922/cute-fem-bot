import { defineStore } from 'pinia'
import { fetchSuggestions, SchemaSuggestionType } from '../api'
import { computeSuggestionType } from '../util'
import { useAuthStore } from './auth'

export const useSuggestionsStore = defineStore('suggestions', () => {
  const auth = useAuthStore()

  const page = ref(1)

  const { state, isReady, isLoading, execute, error } = useAsyncState(
    () => fetchSuggestions({ page: page.value }),
    null,
    {
      immediate: false,
      shallow: true,
      resetOnExecute: false,
    },
  )

  whenever(
    () => !state.value && auth.key,
    () => execute(),
    { immediate: true },
  )

  debouncedWatch(page, () => execute(), { debounce: 300 })

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
    page,

    suggestionsMapped,
    usersList,
    usersMap,
    suggestionTypes,
  })
})
