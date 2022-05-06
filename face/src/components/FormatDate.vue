<script setup lang="ts">
import { DateTime } from 'luxon'

const props = defineProps<{
  iso: string | null
}>()

const dt = $computed(() => props.iso && DateTime.fromISO(props.iso).setLocale('ru-RU'))

const formatted = $computed(() => {
  return dt && dt.toLocaleString(DateTime.DATETIME_SHORT)
})
</script>

<template>
  <template v-if="formatted">
    {{ formatted }}
  </template>
</template>
