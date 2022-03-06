<script setup lang="ts">
import { DateTime } from 'luxon'

const props = defineProps<{
  iso: string
}>()

const dt = $computed(() => DateTime.fromISO(props.iso).setLocale('ru-RU'))

const formatted = $computed(() => {
  return dt.toLocaleString(DateTime.DATETIME_SHORT)
})
</script>

<template>
  {{ formatted }}
</template>
