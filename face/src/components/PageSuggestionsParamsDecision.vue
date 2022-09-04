<script setup lang="ts">
import { SuggestionDecisionParam, SUGGESTION_DECISION_PARAM_VALUES } from '~/api'
import { SUGGESTION_DECISION_PARAM_RU } from '~/const'

const paramsStore = useSuggestionsParamsStore()

function decisionRu(value: SuggestionDecisionParam) {
  return SUGGESTION_DECISION_PARAM_RU[value]
}
</script>

<template>
  <div class="border border-indigo-300 rounded p-1">
    <label for="decision-select"> Решение: </label>
    <select
      id="decision-select"
      v-model="paramsStore.decision"
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
</template>
