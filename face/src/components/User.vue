<script setup lang="ts">
import { SchemaUser } from '../api'

const props = defineProps<{
  data: SchemaUser
}>()

const meta = computed(() => props.data.meta)

const displayName = computed<string>(() => {
  const { first_name, last_name } = meta.value
  if (last_name) return `${first_name} ${last_name}`
  return first_name
})

const username = computed<string | null>(() => meta.value.username ?? null)

// const href = computed(() => `tg://user?id=${props.data.id}`)
</script>

<template>
  <span
    :class="[
      'text-green-600',
      {
        'text-red-600': data.banned,
      },
    ]"
  >
    {{ displayName }} <span v-if="username">@{{ username }}</span>
  </span>
</template>
