<script setup lang="ts">
import { useSuggestionsStore } from '~/stores/suggestions'
import Suggestion from '../Suggestion.vue'
import User from '../User.vue'

const suggestionsStore = useSuggestionsStore()

const items = $computed(() => suggestionsStore.suggestions)
</script>

<template>
  <div
    v-if="items"
    class="grid sm:grid-cols-2 gap-4 py-4"
  >
    <code>{{ suggestionsStore.data?.pagination }}</code>

    <template v-if="items.length">
      <Suggestion
        v-for="item in items"
        :key="item.file_id"
        :file-id="item.file_id"
      >
        <template
          v-if="suggestionsStore.usersMap"
          #user
        >
          <User :data="suggestionsStore.usersMap!.get(item.made_by)!" />
        </template>
      </Suggestion>
    </template>

    <template v-else>
      Пусто
    </template>
  </div>
</template>
