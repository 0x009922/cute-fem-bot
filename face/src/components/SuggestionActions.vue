<script setup lang="ts">
import { SchemaSuggestion, SchemaSuggestionDecision, updateSuggestion } from '../api'
import { useSuggestionsStore } from '../stores/suggestions'
import LoadingDots from './LoadingDots.vue'

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

let applying = $ref(false)

async function submit() {
  try {
    applying = true

    await updateSuggestion(props.data.file_id, { decision })
    suggestionsStore.execute()
  } finally {
    applying = false
  }
}
</script>

<template>
  <div class="m-4">
    <label class="text-sm"> Решение о постинге: </label>
    <select v-model="decision">
      <option
        v-for="opt in OPTIONS"
        :key="opt.value || 'none'"
        :value="opt.value"
      >
        {{ opt.label }}
      </option>
    </select>

    <button
      v-if="changes"
      :disabled="applying"
      class="float-right"
      @click="submit"
    >
      Применить<LoadingDots v-if="applying" />
    </button>
  </div>
</template>
