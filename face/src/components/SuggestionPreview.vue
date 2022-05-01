<script setup lang="ts">
import IconNoImage from '~icons/mdi/image-remove'
import IconEyeSlash from '~icons/ph/eye-slash'
import SuggestionTypeTag from './SuggestionTypeTag.vue'

defineProps<{
  loading?: boolean
  type: 'photo' | 'video' | 'document'
  blobSrc?: string
  error?: boolean
  unavailable?: boolean
}>()

const emit = defineEmits(['open-preview'])
</script>

<template>
  <div
    class="min-h-200px flex items-center justify-center relative select-none"
    :class="{
      'bg-light-700 hover:bg-light-900 cursor-pointer': !!blobSrc && type !== 'document',
      'bg-red-100': error,
    }"
    @click="type !== 'document' && emit('open-preview')"
  >
    <div v-if="error">
      Загрузить не удалось
    </div>

    <div
      v-else-if="unavailable"
      class="grid gap-4 place-items-center text-gray-500"
    >
      <IconEyeSlash class="text-6xl" />

      <span> Недоступно </span>
    </div>

    <div
      v-else-if="type === 'document'"
      class="flex flex-col items-center space-y-4 p-4 text-gray-500"
    >
      <IconNoImage class="text-6xl" />

      <span>Не посмотреть</span>
    </div>

    <template v-else-if="blobSrc">
      <img
        v-if="type === 'photo'"
        :src="blobSrc"
        alt="Изображение из предложки"
      >

      <video
        v-else
        :src="blobSrc"
        alt="Видео из предложки"
      />
    </template>

    <div class="absolute top-0 left-0 p-4">
      <SuggestionTypeTag :value="type" />
    </div>
  </div>
</template>

<style lang="scss" scoped>
img,
video {
  max-width: 100%;
  max-height: 200px;
}
</style>
