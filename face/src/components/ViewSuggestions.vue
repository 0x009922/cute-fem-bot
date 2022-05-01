<script setup lang="ts">
import { useSuggestionsStore } from '../stores/suggestions'
import SuggestionsList from './SuggestionsList.vue'
import SuggestionsPageControl from './SuggestionsPageControl.vue'

const store = useSuggestionsStore()

const { state, error, isLoading } = toRefs(store)
</script>

<template>
  <h2>Предложка</h2>

  <div v-if="error">
    Ошибка: {{ error }}
  </div>

  <div v-if="state">
    <SuggestionsPageControl />

    <div :class="{ 'pointer-events-none opacity-50': isLoading }">
      <SuggestionsList />
    </div>

    <SuggestionsPageControl />
  </div>
</template>
