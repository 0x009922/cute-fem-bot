<script setup lang="ts">
import { usePreviewStore } from '../stores/preview'

const store = usePreviewStore()

const file = $computed(() => store.file)
const type = $computed(() => store.type)
</script>

<template>
  <div
    v-if="file"
    class="fixed inset-0 bg-dark-50 bg-opacity-70 flex items-center justify-center"
    @click="store.close()"
  >
    <div>
      <img
        v-if="type === 'photo'"
        :src="file.src"
        class="shadow-xl"
      >

      <video
        v-else-if="type === 'video'"
        :src="file.src"
        controls
        autoplay
        class="shadow-xl"
      />

      <span
        v-else
        class="p-4 text-3xl bg-white rounded shadow-lg"
      > Сказано же - не посмотреть </span>
    </div>
  </div>
</template>

<style lang="scss" scoped>
img,
video {
  max-width: 80vw;
  max-height: 80vh;
}
</style>
