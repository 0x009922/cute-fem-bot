<script setup lang="ts">
import { useFilesStore } from '../stores/files'
import SuggestionActions from './SuggestionActions.vue'
import SuggestionPreview from './SuggestionPreview.vue'
import FormatDate from './FormatDate.vue'
import { usePreviewStore } from '../stores/preview'
import { useSuggestionsStore } from '../stores/suggestions'

interface Props {
  fileId: string
}

const props = defineProps<Props>()

const filesStore = useFilesStore()
const suggestionsStore = useSuggestionsStore()

const data = $computed(() => suggestionsStore.suggestionsMapped!.get(props.fileId)!)

// File loading

const file = $computed(() => filesStore.loaded[props.fileId])
const isFileLoaded = $computed(() => !!file)
let isLoading = $ref(false)

async function load() {
  try {
    isLoading = true
    await filesStore.load(props.fileId)
  } finally {
    isLoading = false
  }
}

const typeDefinitely = $computed(() => suggestionsStore.suggestionTypes!.get(props.fileId)!)

const isPreviewable = $computed(() => typeDefinitely !== 'document')

// Loading on intersection

const root = templateRef('root')
let isVisible = $ref(false)

useIntersectionObserver(root, ([{ isIntersecting }]) => {
  isVisible = isIntersecting
})

whenever(
  () => !isFileLoaded && isVisible && !isLoading && isPreviewable,
  () => load(),
  { immediate: true },
)

const previewStore = usePreviewStore()

function openPreview() {
  previewStore.open(props.fileId)
}
</script>

<template>
  <div
    ref="root"
    class="min-h-100px shadow rounded relative overflow-hidden flex flex-col"
  >
    <SuggestionPreview
      class="flex-1"
      :type="typeDefinitely"
      :blob-src="file?.src"
      @open-preview="openPreview()"
    />

    <div class="flex items-center p-4 text-sm">
      <span class="text-sm flex-1"><slot name="user" /></span>

      <span>
        <FormatDate :iso="data.inserted_at" />
      </span>
    </div>

    <SuggestionActions :data="data" />
  </div>
</template>
