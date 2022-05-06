<script setup lang="ts">
import { SuggestionDecisionParam, SUGGESTION_DECISION_PARAM_VALUES } from '~/api'
import { SUGGESTION_DECISION_PARAM_RU } from '~/const'
import { useSuggestionsStore } from '~/stores/suggestions'
import SuggestionsPageControl from './SuggestionsPageControl.vue'

const suggestionsStore = useSuggestionsStore()

function decisionRu(value: SuggestionDecisionParam) {
  return SUGGESTION_DECISION_PARAM_RU[value]
}
</script>

<template>
  <div class="rounded border-2 border-indigo-600 p-4 space-y-4">
    <div class="flex items-center">
      <h3 class="m-0 flex-1">
        Параметры
      </h3>

      <button @click="suggestionsStore.mutate()">
        Обновить
      </button>
    </div>
    <div class="grid gap-2 grid-cols-2">
      <div class="grid gap-2">
        <div class="">
          <label for="decision-select"> Решение: </label>
          <select
            id="decision-select"
            v-model="suggestionsStore.params.decision"
          >
            <option
              v-for="x in SUGGESTION_DECISION_PARAM_VALUES"
              :key="x"
              :value="x"
            >
              {{ decisionRu(x) }}
            </option>
          </select>
        </div>

        <div>
          <input
            id="published-checkbox"
            v-model="suggestionsStore.params.published"
            type="checkbox"
          >
          <label for="published-checkbox"> Опубликовано </label>
        </div>
      </div>

      <SuggestionsPageControl />
    </div>
  </div>
</template>
