<script setup lang="ts">
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
  <div class="flex items-center space-x-2 border border-indigo-300 rounded p-2">
    <span>Страница: {{ page }}</span>

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
</template>

<style lang="scss" scoped>
button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  padding: 0;
  @each $i in width, height {
    #{$i}: 20px;
  }
}
</style>
