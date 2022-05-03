import { defineStore } from 'pinia'
import { fetchSuggestions, FetchSuggestionsParams, FetchSuggestionsResponse, SchemaSuggestionType } from '../api'
import { computeSuggestionType } from '../util'
import { useAuthStore } from './auth'
import { useSwr, wrapState } from '~/swr/lib'
import { SetRequired } from 'type-fest'
import { createAmnesiaStore } from '~/swr/amnesia-store'

export const useSuggestionsStore = defineStore('suggestions', () => {
  const auth = useAuthStore()

  const params = reactive<SetRequired<FetchSuggestionsParams, 'page' | 'published' | 'decision'>>({
    page: 1,
    published: true,
    decision: 'whatever',
  })

  const swrStore = createAmnesiaStore<FetchSuggestionsResponse>()
  const { state } = useSwr({
    fetch: computed(() => {
      if (!auth.key) return null

      return {
        key: `${params.page}-${params.published}-${params.decision}`,
        fn: () => fetchSuggestions(params),
      }
    }),
    store: swrStore,
  })
  const { data, error, isPending } = wrapState(state)
  function mutateViaReset() {
    swrStore.reset()
  }

  const suggestionsMapped = $computed(() => {
    const items = data.value?.val.suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, x]))
  })

  const usersList = computed(() => data.value?.val.users ?? null)
  const usersMap = computed(() => {
    const list = usersList.value
    if (!list) return null
    return new Map(list.map((x) => [x.id, x]))
  })

  const suggestionTypes = $computed<null | Map<string, SchemaSuggestionType>>(() => {
    const items = data.value?.val.suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, computeSuggestionType(x.file_type, x.file_mime_type)]))
  })

  return $$({
    params,
    data,
    isPending,
    error,
    mutate: mutateViaReset,

    suggestionsMapped,
    usersList,
    usersMap,
    suggestionTypes,
  })
})
