<script setup lang="ts">
import { SchemaSuggestion } from '../api'
import Suggestion from './Suggestion.vue'

interface Props {
  items: SchemaSuggestion[]
}

const props = defineProps<Props>()
</script>

<template>
  <div class="space-y-4">
    <Suggestion
      v-for="(item, i) in props.items"
      :key="item.file_id"
      :data="item"
      :num="i + 1"
    />
  </div>
</template>
