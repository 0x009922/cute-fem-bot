<script setup lang="ts">
import { useSuggestionsStore, useParamsRouterSync } from '~/stores/suggestions'
import SuggestionsList from './SuggestionsList.vue'
import Params from './Params.vue'
import Spinner from '../Spinner.vue'

const store = useSuggestionsStore()
useParamsRouterSync()
</script>

<template>
  <h2 class="flex items-center space-x-4">
    <span> Предложка </span>

    <Spinner v-if="store.pending" />
  </h2>

  <div class="space-y-4">
    <Params />

    <div
      v-if="store.error"
      class="border-2 border-red-500 rounded p-4"
    >
      Ошибка: {{ store.error }}
    </div>

    <SuggestionsList />
  </div>
</template>
