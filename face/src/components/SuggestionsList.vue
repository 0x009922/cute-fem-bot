<script setup lang="ts">
import { useSuggestionsStore } from '../stores/suggestions'
import Suggestion from './Suggestion.vue'
import User from './User.vue'

const suggestionsStore = useSuggestionsStore()
</script>

<template>
  <div
    v-if="suggestionsStore.state"
    class="grid sm:grid-cols-2 gap-4 py-4"
  >
    <Suggestion
      v-for="item in suggestionsStore.state.suggestions"
      :key="item.file_id"
      :file-id="item.file_id"
    >
      <template
        v-if="suggestionsStore.usersMap"
        #user
      >
        <User :data="suggestionsStore.usersMap!.get(item.suggestor_id)!" />
      </template>
    </Suggestion>
  </div>
</template>
