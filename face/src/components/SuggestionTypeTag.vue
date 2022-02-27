<script setup lang="ts">
import { SchemaSuggestionType } from '../api'
import { SUGGESTION_TYPE_RU } from '../const'

const props = defineProps<{
  value: SchemaSuggestionType
}>()

const ru = computed(() => SUGGESTION_TYPE_RU[props.value])
</script>

<template>
  <span
    :class="[
      'border rounded px-1 text-sm',
      {
        'border-blue-500 text-blue-500': value === 'photo',
        'border-orange-500 text-orange-500': value === 'video',
        'border-purple-500 text-purple-500': value === 'document',
      },
    ]"
  >
    {{ ru }}
  </span>
</template>
