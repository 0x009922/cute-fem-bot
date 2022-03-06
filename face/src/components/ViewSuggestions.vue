<script setup lang="ts">
import { useSuggestionsStore } from '../stores/suggestions'
import SuggestionsList from './SuggestionsList.vue'

const store = useSuggestionsStore()

const { state, error } = toRefs(store)
</script>

<template>
  <h2>Предложка</h2>

  <div v-if="error">
    Ошибка: {{ error }}
  </div>

  <div v-if="state">
    <SuggestionsList :items="state.suggestions" />
  </div>
</template>
