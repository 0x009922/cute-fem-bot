<script setup lang="ts">
import ThePreview from './components/ThePreview.vue'
</script>

<template>
  <div class="container mx-auto app p-4">
    <h1 class="text-4xl m-0">
      CuteFemBot Web
    </h1>

    <RouterView />

    <ThePreview />
  </div>
</template>

<style lang="scss" scoped>
.app {
  font-family: 'Roboto Slab', sans-serif;
  max-width: 600px;
}
</style>
