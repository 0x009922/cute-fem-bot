<script setup lang="ts">
import PageSuggestionsParamsPage from './PageSuggestionsParamsPage.vue'
import PageSuggestionsParamsDecision from './PageSuggestionsParamsDecision.vue'
import PageSuggestionsParamsOrder from './PageSuggestionsParamsOrder.vue'

const paramsStore = useSuggestionsParamsStore()
const suggestionsStore = useSuggestionsStore()
</script>

<template>
  <div class="rounded border-2 border-indigo-600 p-4 space-y-4">
    <div class="flex items-center">
      <h3 class="m-0 flex-1 font-normal">
        Параметры
      </h3>

      <button @click="suggestionsStore.mutate()">
        Обновить
      </button>
    </div>

    <div class="grid gap-2 grid-cols-2">
      <PageSuggestionsParamsDecision />

      <div class="border border-indigo-300 rounded p-1">
        <input
          id="published-checkbox"
          v-model="paramsStore.published"
          type="checkbox"
        >
        <label for="published-checkbox"> Опубликовано </label>
      </div>

      <PageSuggestionsParamsPage />

      <PageSuggestionsParamsOrder />
    </div>
  </div>
</template>
