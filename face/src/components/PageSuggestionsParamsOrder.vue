<script setup lang="ts">
const store = useSuggestionsParamsStore()
</script>

<template>
  <div class="border border-indigo-300 rounded p-1">
    <label for="order-by-decision-date">Сортировка по дате решения:</label>

    <select
      id="order-by-decision-date"
      v-model="store.orderByDecisionDate"
    >
      <option value="none">
        Нет
      </option>
      <option value="asc">
        От старых к новым
      </option>
      <option value="desc">
        От новых к старым
      </option>
    </select>
  </div>
</template>
