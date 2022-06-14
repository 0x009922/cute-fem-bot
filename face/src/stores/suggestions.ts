import { defineStore } from 'pinia'
import {
  fetchSuggestions,
  FetchSuggestionsParams,
  FetchSuggestionsResponse,
  SchemaSuggestionType,
  SuggestionDecisionParam,
  SUGGESTION_DECISION_PARAM_VALUES,
} from '../api'
import { computeSuggestionType } from '../util'
import { useAuthStore } from './auth'
import { useSwr, createAmnesiaStore } from '@vue-swr-composable/core'
import { useRouteQuery } from '@vueuse/router'

export const useSuggestionsParamsStore = defineStore('suggestions-params', () => {
  const page = ref(1)
  const published = ref(true)
  const decision = ref<SuggestionDecisionParam>('whatever')

  /**
   * Pure data
   */
  const pureParams: FetchSuggestionsParams = reactive({
    page,
    published,
    decision,
  })

  return { page, published, decision, pureParams }
})

export function useParamsRouterSync() {
  const storeParams = toRefs(useSuggestionsParamsStore())

  let routePage = useRouteQuery<string>('p', '1')
  const routePageNum = computed({
    get: () => parseInt(routePage.value, 10),
    set: (v) => {
      routePage.value = String(v)
    },
  })
  syncRef(routePageNum, storeParams.page)

  let routeDecision = useRouteQuery('decision')
  let routeDecisionFiltered = computed<SuggestionDecisionParam>({
    get: () => {
      const value = routeDecision
      if (typeof value === 'string' && SUGGESTION_DECISION_PARAM_VALUES.includes(value as SuggestionDecisionParam)) {
        return value as SuggestionDecisionParam
      }
      return 'whatever'
    },
    set: (v) => {
      routeDecision.value = v
    },
  })
  syncRef(routeDecisionFiltered, storeParams.decision)

  let routePublished = useRouteQuery('published')
  let routePublishedFiltered = computed<boolean>({
    get: () => {
      const value = routePublished
      if (typeof value === 'string') {
        if (value === 'true') return true
        if (value === 'false') return false
      }
      return false
    },
    set: (v) => {
      routePublished.value = String(v)
    },
  })
  syncRef(routePublishedFiltered, storeParams.published)
}

export const useSuggestionsStore = defineStore('suggestions', () => {
  const auth = useAuthStore()

  const params = useSuggestionsParamsStore()

  const swrStore = createAmnesiaStore<FetchSuggestionsResponse>()
  const { resource } = useSwr({
    fetch: computed(() => {
      if (!auth.key) return null

      return {
        key: `${params.page}-${params.published}-${params.decision}`,
        fn: () => fetchSuggestions(params.pureParams),
      }
    }),
    store: swrStore,
  })

  const swrKey = $computed(() => resource.value?.key)
  const data = $computed(() => resource.value?.state.data?.some)
  const error = $computed(() => resource.value?.state.error?.some)
  const pending = $computed(() => resource.value?.state.pending ?? false)

  function mutateAndResetAllOther() {
    const key = swrKey
    if (!key) throw new Error('No current key')

    const currentState = swrStore.get(key)
    swrStore.storage.clear()
    swrStore.set(key, currentState)

    resource.value!.refresh()
  }

  const suggestions = $computed(() => data?.suggestions)

  const suggestionsMapped = $computed(() => {
    const items = suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, x]))
  })

  const usersList = computed(() => data?.users ?? null)
  const usersMap = computed(() => {
    const list = usersList.value
    if (!list) return null
    return new Map(list.map((x) => [x.id, x]))
  })

  const suggestionTypes = $computed<null | Map<string, SchemaSuggestionType>>(() => {
    const items = suggestions
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, computeSuggestionType(x.file_type, x.file_mime_type ?? undefined)]))
  })

  return $$({
    data,
    pending,
    error,
    mutate: mutateAndResetAllOther,

    suggestions,
    suggestionsMapped,
    usersList,
    usersMap,
    suggestionTypes,
  })
})
