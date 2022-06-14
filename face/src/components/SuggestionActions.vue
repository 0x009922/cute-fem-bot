<script setup lang="ts">
import { SchemaSuggestion, SchemaSuggestionDecision, makeDecision } from '../api'
import { useSuggestionsStore } from '../stores/suggestions'
import SuggestionCardLine from './SuggestionCardLine.vue'

const props = defineProps<{
  data: SchemaSuggestion
}>()

const suggestionsStore = useSuggestionsStore()

const OPTIONS: { label: string; value: SchemaSuggestionDecision | null }[] = [
  {
    label: 'SFW',
    value: 'sfw',
  },
  {
    label: 'NSFW',
    value: 'nsfw',
  },
  {
    label: 'Отклонено',
    value: 'reject',
  },
]

const { isLoading: isPending, execute: makeDecisionAndUpdateStore } = useAsyncState(
  async () => {
    await makeDecision(props.data.file_id, decision!)
    suggestionsStore.mutate()
  },
  null,
  { immediate: false },
)

let decision = $ref<SchemaSuggestionDecision | null>(props.data.decision)
whenever<any>(() => decision && decision !== props.data.decision, makeDecisionAndUpdateStore)
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
        :disabled="isPending"
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
