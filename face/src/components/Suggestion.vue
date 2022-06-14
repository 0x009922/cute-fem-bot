<script setup lang="ts">
import { isUnavailable, useFileSwr } from '../stores/files'
import SuggestionActions from './SuggestionActions.vue'
import SuggestionPreview from './SuggestionPreview.vue'
import FormatDate from './FormatDate.vue'
import { usePreviewStore } from '../stores/preview'
import { useSuggestionsStore } from '../stores/suggestions'
import Spinner from './Spinner.vue'
import SuggestionCardLine from './SuggestionCardLine.vue'

interface Props {
  fileId: string
}

const props = defineProps<Props>()

const suggestionsStore = useSuggestionsStore()

// different data

const data = $computed(() => suggestionsStore.suggestionsMapped!.get(props.fileId)!)
const typeDefinitely = $computed(() => suggestionsStore.suggestionTypes!.get(props.fileId)!)
const isPreviewable = $computed(() => typeDefinitely !== 'document')

// INTERSECTION

const root = templateRef('root')
let isVisible = $ref(false)

useIntersectionObserver(root, ([{ isIntersecting }]) => {
  isVisible = isIntersecting
})

// LOADING

const shouldLoad = $computed(() => isVisible && isPreviewable)
const { resource: fileResource } = useFileSwr(computed(() => (shouldLoad ? props.fileId : null)))

const isPending = $computed(() => fileResource.value?.state.pending ?? false)
const file = $computed(() => fileResource.value?.state.data?.some)
const error = $computed(() => fileResource.value?.state.error?.some)

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
    ref="root"
    class="min-h-100px shadow rounded relative overflow-hidden flex flex-col"
  >
    <Spinner
      v-if="isPending"
      class="absolute right-0 top-0 m-2 z-50"
    />

    <SuggestionPreview
      class="flex-1"
      :error="!!error"
      :type="typeDefinitely"
      :blob-src="fileBlobSrc"
      :unavailable="fileIsUnavailable"
      @open-preview="openPreview()"
    />

    <div class="grid gap-4 p-4 text-sm">
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

      <span class="text-xs">
        <FormatDate :iso="data.inserted_at" />
        <template v-if="data.updated_at"> / <FormatDate :iso="data.updated_at" /> </template>
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
