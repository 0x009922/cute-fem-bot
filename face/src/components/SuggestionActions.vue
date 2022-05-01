<script setup lang="ts">
import { SchemaSuggestion, SchemaSuggestionDecision, updateSuggestion } from '../api'
import { useSuggestionsStore } from '../stores/suggestions'

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
    await suggestionsStore.execute()
  } finally {
    applying = false
  }
}
</script>

<template>
  <div class="m-4">
    <label class="text-sm"> Решение о постинге: </label>
    <select
      v-model="decision"
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
  </div>
</template>
