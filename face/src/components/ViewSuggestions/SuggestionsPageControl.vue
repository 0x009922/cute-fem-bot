<script setup lang="ts">
import { useSuggestionsParamsStore } from '~/stores/suggestions'
import IconPlus from '~icons/ic/round-plus'
import IconMinus from '~icons/ic/round-minus'

const params = useSuggestionsParamsStore()
const storePage = toRef(params, 'page')

let page = ref(storePage)
let pageDebounced = refDebounced(page, 300)

syncRef(storePage, page)
syncRef(pageDebounced, storePage)

function inc() {
  page.value++
}

function dec() {
  page.value--
}
</script>

<template>
  <div class="inline-block space-y-2">
    <div>Страница: {{ page }}</div>

    <div class="flex space-x-4">
      <button
        :disabled="page <= 1"
        @click="dec"
      >
        <IconMinus />
      </button>
      <button @click="inc">
        <IconPlus />
      </button>
    </div>
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
