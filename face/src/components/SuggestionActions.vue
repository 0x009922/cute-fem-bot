<script setup lang="ts">
import { useParamScope, useTask, wheneverFulfilled, wheneverRejected } from '@vue-kakuyaku/core'
import { SchemaSuggestion, SchemaSuggestionDecision, makeDecision } from '~/api'
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

const decision = ref<SchemaSuggestionDecision | null>(props.data.decision)

const scope = useParamScope(
  computed(() => {
    const valueInput = decision.value
    const { decision: valueCurrent, file_id } = props.data

    return (
      valueInput &&
      valueInput !== valueCurrent && {
        key: `${file_id} ${valueInput}`,
        payload: { file_id, decision: valueInput },
      }
    )
  }),
  ({ file_id, decision }) => {
    const { state } = useTask(
      async () => {
        await makeDecision(file_id, decision)
      },
      { immediate: true },
    )

    wheneverFulfilled(state, () => {
      suggestionsStore.mutate()
    })

    wheneverRejected(state, (reason) => {
      console.error(reason)
    })

    return state
  },
)

const isPending = computed(() => scope.value?.expose.pending ?? false)
</script>

<template>
  <SuggestionCardLine>
    <template #title>
      Решение о постинге
    </template>
    <template #content>
      <select
        v-model="decision"
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
