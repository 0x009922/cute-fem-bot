<script setup lang="ts">
import VSpinner from '~/components/VSpinner.vue'
import PageSuggestionsParams from '~/components/PageSuggestionsParams.vue'
import PageSuggestionsList from '~/components/PageSuggestionsList.vue'

const store = useSuggestionsStore()
useParamsRouterSync()
</script>

<template>
  <h2 class="flex items-center space-x-4">
    <span> Предложка </span>

    <VSpinner v-if="store.pending" />
  </h2>

  <div class="space-y-4">
    <PageSuggestionsParams />

    <div
      v-if="store.error"
      class="border-2 border-red-500 rounded p-4"
    >
      Ошибка: {{ store.error }}
    </div>

    <PageSuggestionsList />
  </div>
</template>
