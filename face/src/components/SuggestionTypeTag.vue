<script setup lang="ts">
import { SchemaSuggestionType } from '~/api'
import IconVideo from '~icons/ic/round-video-camera-back'
import IconPhoto from '~icons/ic/round-photo'
import IconDoc from '~icons/mdi/file-document'

const props = defineProps<{
  value: SchemaSuggestionType
}>()

const icon = computed(() => {
  switch (props.value) {
    case 'document':
      return IconDoc
    case 'photo':
      return IconPhoto
    case 'video':
      return IconVideo
  }
})
</script>

<template>
  <span
    :class="[
      'bg-white inline-block flex items-center justify-center p-1 rounded border text-sm shadow-xl',
      {
        'text-blue-500': value === 'photo',
        'text-orange-500': value === 'video',
        'text-purple-500': value === 'document',
      },
    ]"
  >
    <component :is="icon" />
  </span>
</template>
