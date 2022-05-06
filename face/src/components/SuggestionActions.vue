<script setup lang="ts">
import { SchemaSuggestion, SchemaSuggestionDecision, updateSuggestion } from '../api'
import { useSuggestionsStore } from '../stores/suggestions'
import SuggestionCardLine from './SuggestionCardLine.vue'

const props = defineProps<{
  data: SchemaSuggestion
}>()

const suggestionsStore = useSuggestionsStore()

const OPTIONS: { label: string; value: SchemaSuggestionDecision }[] = [
  {
    label: 'Нет',
    value: null,
  },
  {
    label: 'SFW',
    value: 'sfw',
  },
  {
    label: 'NSFW',
    value: 'nsfw',
  },
]

let decision = $ref<SchemaSuggestionDecision>(props.data.decision)

const changes = $computed<boolean>(() => decision !== props.data.decision)

whenever($$(changes), submit)

let applying = $ref(false)

async function submit() {
  if (applying) return

  try {
    applying = true

    await updateSuggestion(props.data.file_id, { decision })
    suggestionsStore.mutate()
  } finally {
    applying = false
  }
}
</script>

<template>
  <SuggestionCardLine>
    <template #title>
      Решение о постинге
    </template>
    <template #content>
      <select
        v-model="decision"
        class="mt-2"
        :disabled="applying"
      >
        <option
          v-for="opt in OPTIONS"
          :key="opt.value || 'none'"
          :value="opt.value"
        >
          {{ opt.label }}
        </option>
      </select>
    </template>
  </SuggestionCardLine>
</template>
