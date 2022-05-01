<script setup lang="ts">
import { useSuggestionsStore } from '../stores/suggestions'
import IconPlus from '~icons/ic/round-plus'
import IconMinus from '~icons/ic/round-minus'

const suggestionsStore = useSuggestionsStore()

let page = $computed({
  get: () => suggestionsStore.page,
  set(v) {
    suggestionsStore.$patch({ page: v })
  },
})

function inc() {
  page++
}

function dec() {
  page--
}
</script>

<template>
  <div class="flex items-center space-x-4 p-4 rounded border border-indigo-500">
    <button
      :disabled="page <= 1"
      @click="dec"
    >
      <IconMinus />
    </button>
    <span>Страница: <span class="w-8 text-right inline-block">{{ page }}</span></span>
    <button @click="inc">
      <IconPlus />
    </button>
  </div>
</template>

<style lang="scss" scoped>
button {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  padding: 0;
  @each $i in width, height {
    #{$i}: 24px;
  }
}
</style>
