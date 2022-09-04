<script setup lang="ts">
import ThePreview from './components/ThePreview.vue'
import basil from './assets/basil-cut.avif'
</script>

<template>
  <div class="container mx-auto app p-4">
    <div class="flex items-center">
      <h1 class="text-4xl m-0 flex-1">
        CuteFemBot Web
      </h1>

      <img
        alt="basil"
        :src="basil"
        height="120"
      >
    </div>

    <hr class="mt-0">

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
