<script setup lang="ts">
import { useSuggestionsStore } from '~/stores/suggestions'
import SuggestionsList from './SuggestionsList.vue'
import { useRouteQuery } from '@vueuse/router'
import { SuggestionDecisionParam as Decision, SUGGESTION_DECISION_PARAM_VALUES } from '~/api'
import Params from './Params.vue'
import Spinner from '../Spinner.vue'

const store = useSuggestionsStore()

const { error, isPending } = toRefs(store)

let storePage = $computed({
  get: () => store.params.page,
  set: (v) => {
    store.params.page = v
  },
})
let routePage = $(useRouteQuery<string>('p', '1'))
const routePageNum = $computed({
  get: () => Number(routePage),
  set: (v) => {
    routePage = String(v)
  },
})
syncRef($$(routePageNum), $$(storePage))

let storeDecision = $computed({
  get: () => store.params.decision,
  set: (v) => {
    store.params.decision = v
  },
})
let routeDecision = $(useRouteQuery('decision'))
let routeDecisionFiltered = $computed<Decision>({
  get: () => {
    const value = routeDecision
    if (typeof value === 'string' && SUGGESTION_DECISION_PARAM_VALUES.includes(value as Decision)) {
      return value as Decision
    }
    return 'whatever'
  },
  set: (v) => {
    routeDecision = v
  },
})
syncRef($$(routeDecisionFiltered), $$(storeDecision))

let storePublished = $computed({
  get: () => store.params.published,
  set: (v) => {
    store.params.published = v
  },
})
let routePublished = $(useRouteQuery('published'))
let routePublishedFiltered = $computed<boolean>({
  get: () => {
    const value = routePublished
    if (typeof value === 'string') {
      if (value === 'true') return true
      if (value === 'false') return false
    }
    return false
  },
  set: (v) => {
    routePublished = String(v)
  },
})
syncRef($$(storePublished), $$(routePublishedFiltered))
</script>

<template>
  <h2 class="flex items-center space-x-4">
    <span> Предложка </span>

    <Spinner v-if="isPending" />
  </h2>

  <div class="space-y-4">
    <Params />

    <div
      v-if="error"
      class="border-2 border-red-500 rounded p-4"
    >
      Ошибка: {{ error.val }}
    </div>

    <div>
      <SuggestionsList />
    </div>
  </div>
</template>
