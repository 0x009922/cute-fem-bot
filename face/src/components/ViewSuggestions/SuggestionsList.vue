<script setup lang="ts">
import { useSuggestionsStore } from '~/stores/suggestions'
import Suggestion from '../Suggestion.vue'
import User from '../User.vue'
import DontWatch from '~/assets/dont-watch.avif'
import { storeToRefs } from 'pinia'

const suggestionsStore = useSuggestionsStore()

const { pagination, suggestions: items } = storeToRefs(suggestionsStore)
</script>

<template>
  <div
    v-if="items"
    class="space-y-4"
  >
    <div
      v-if="pagination"
      class="text-gray-400 text-sm"
    >
      Результаты: {{ (pagination.page - 1) * pagination.page_size + 1 }}...{{
        pagination.page * pagination.page_size
      }}
      (всего {{ pagination.total }})
    </div>

    <div
      v-if="items.length"
      class="grid sm:grid-cols-2 gap-4 py-4"
    >
      <Suggestion
        v-for="item in items"
        :key="item.file_id"
        :file-id="item.file_id"
      >
        <template
          v-if="suggestionsStore.usersMap"
          #user
        >
          <User :data="suggestionsStore.usersMap!.get(item.made_by)!" />
        </template>
      </Suggestion>
    </div>

    <div
      v-else
      class="px-16 pt-4 text-center space-y-4"
    >
      <img
        :src="DontWatch"
        class="w-full"
      >

      <p class="text-xl italic text-gray-500">
        Здесь ничего неть!
      </p>
    </div>
  </div>
</template>
