<script setup lang="ts">
import SuggestionActions from './SuggestionActions.vue'
import SuggestionPreview from './SuggestionPreview.vue'
import SuggestionCardLine from './SuggestionCardLine.vue'
import VFormatDate from './VFormatDate.vue'
import VSpinner from './VSpinner.vue'

interface Props {
  fileId: string
}

const props = defineProps<Props>()

const suggestionsStore = useSuggestionsStore()

// different data

const data = $computed(() => suggestionsStore.suggestionsMapped?.get(props.fileId))
const suggestionType = $computed(() => suggestionsStore.suggestionTypes?.get(props.fileId))
const isPreviewable = $computed(() => suggestionType !== 'document')

// INTERSECTION

const root = templateRef('root')
let isVisible = $ref(false)

useIntersectionObserver(root, ([{ isIntersecting }]) => {
  isVisible = isIntersecting
})

// LOADING

const shouldLoad = $computed(() => isVisible && isPreviewable)
const fileResource = useFileSwr(computed(() => (shouldLoad ? props.fileId : null)))

const isPending = $computed(() => fileResource.value?.state.pending ?? false)
const file = $computed(() => fileResource.value?.state.fulfilled?.value)
const error = $computed(() => fileResource.value?.state.rejected?.reason)

// PREVIEW

const previewStore = usePreviewStore()

const fileBlobSrc = $computed<undefined | string>(() => (isUnavailable(file) ? undefined : file?.src))
const fileIsUnavailable = $computed(() => isUnavailable(file))

function openPreview() {
  previewStore.open(props.fileId)
}
</script>

<template>
  <div
    v-if="suggestionType && data"
    ref="root"
    class="min-h-100px shadow rounded relative overflow-hidden flex flex-col"
  >
    <VSpinner
      v-if="isPending"
      class="absolute right-0 top-0 m-2 z-50"
    />

    <SuggestionPreview
      class="flex-1"
      :error="!!error"
      :type="suggestionType"
      :blob-src="fileBlobSrc"
      :unavailable="fileIsUnavailable"
      @open-preview="openPreview()"
    />

    <div class="grid gap-3 p-4 text-sm">
      <SuggestionCardLine>
        <template #title>
          Опубликовано?
        </template>
        <template #content>
          {{ data.published ? 'Да' : 'Нет' }}
        </template>
      </SuggestionCardLine>

      <SuggestionActions :data="data" />

      <SuggestionCardLine>
        <template #title>
          Юзер
        </template>
        <template #content>
          <slot name="user" />
        </template>
      </SuggestionCardLine>

      <span class="text-xs text-gray-400">
        Создано: <VFormatDate :iso="data.inserted_at" />
        <template v-if="data.updated_at"> / Обновлено: <VFormatDate :iso="data.updated_at" /> </template>
      </span>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.tags-list {
  & > span {
    border-radius: 99px;
    padding: 0 4px;
    margin: 4px;
    // border: 1px solid black;
  }
}
</style>
