<script setup lang="ts">
const props = defineProps<{
  src: string
}>()

const expand = ref(false)
</script>

<template>
  <video
    :src="src"
    :controls="expand"
    :class="{ expand }"
    @click="expand = true"
  />
</template>

<style lang="scss" scoped>
video {
  width: 100px;
  max-width: 300px;
}

.expand {
  width: 100%;
}
</style>
