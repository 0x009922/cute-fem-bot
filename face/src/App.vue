<script setup lang="ts">
import ThePreview from './components/ThePreview.vue'
</script>

<template>
  <div class="container mx-auto px-8 app">
    <h1 class="text-4xl">
      CuteFemBot - web
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
