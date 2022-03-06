<script setup lang="ts">
import ThePreview from './components/ThePreview.vue'
</script>

<template>
  <div class="container mx-auto px-8">
    <h1>Cute Fem Bot Фейс</h1>

    <RouterView />

    <ThePreview />
  </div>
</template>

<style lang="scss">
#app {
  font-family: sans-serif;
}
</style>
