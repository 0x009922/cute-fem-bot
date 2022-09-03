import { defineStore } from 'pinia'
import {
  fetchSuggestions,
  FetchSuggestionsParams,
  SchemaSuggestionType,
  SuggestionDecisionParam,
  SUGGESTION_DECISION_PARAM_VALUES,
} from '../api'
import { computeSuggestionType } from '../util'
import { useAuthStore } from './auth'
import { useRouteQuery } from '@vueuse/router'
import invariant from 'tiny-invariant'
import { useResourcesPool } from '~/util/swr'
import { ComposedKey } from '@vue-kakuyaku/core'

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

  const { useResource, memory } = useResourcesPool<
    Awaited<ReturnType<typeof fetchSuggestions>>,
    ComposedKey<string, FetchSuggestionsParams>
  >(({ payload: params }) => fetchSuggestions(params), {
    debug: 'suggestions',
  })

  const resource = useResource(
    computed(() => {
      if (!auth.key) return null

      return {
        key: `${params.page}-${params.published}-${params.decision}`,
        payload: params.pureParams,
      }
    }),
  )

  const data = computed(() => resource.value?.state.fulfilled?.value)
  const error = computed(() => resource.value?.state.rejected?.reason)
  const pending = computed(() => resource.value?.state.pending ?? false)

  const pagination = computed(() => data.value?.pagination ?? null)

  function mutateAndResetAllOther() {
    const res = resource.value
    invariant(res)

    const value = memory.get(res.key.key)
    memory.clear()
    value && memory.set(res.key.key, value)

    res.mutate()
  }

  const suggestions = computed(() => data.value?.suggestions)

  const suggestionsMapped = computed(() => {
    const items = suggestions.value
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, x]))
  })

  const suggestionTypes = computed<null | Map<string, SchemaSuggestionType>>(() => {
    const items = suggestions.value
    if (!items) return null
    return new Map(items.map((x) => [x.file_id, computeSuggestionType(x.file_type, x.file_mime_type ?? undefined)]))
  })

  const usersList = computed(() => data.value?.users ?? null)
  const usersMap = computed(() => {
    const list = usersList.value
    if (!list) return null
    return new Map(list.map((x) => [x.id, x]))
  })

  return {
    pagination,
    pending,
    error,
    mutate: mutateAndResetAllOther,

    suggestions,
    suggestionsMapped,
    usersList,
    usersMap,
    suggestionTypes,
  }
})
