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
      'bg-white p-1 rounded border text-sm shadow-xl',
      {
        'text-blue-500': value === 'photo',
        'text-orange-500': value === 'video',
        'text-purple-500': value === 'document',
      },
    ]"
  >
    {{ ru }}
  </span>
</template>
