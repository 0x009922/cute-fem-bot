<script setup lang="ts">
interface Props {
  src: string
}

const props = defineProps<Props>()

const expand = ref(false)
</script>

<template>
  <img
    :src="src"
    :class="{ expand }"
    alt="Скачанное изображение"
    @click="expand = !expand"
  >
</template>

<style lang="scss" scoped>
img {
  width: 100px;
  cursor: pointer;
}

.expand {
  width: auto;
}
</style>
