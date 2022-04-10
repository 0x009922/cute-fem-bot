<script setup lang="ts">
import { useFilesStore } from '../stores/files'
import SuggestionActions from './SuggestionActions.vue'
import SuggestionPreview from './SuggestionPreview.vue'
import FormatDate from './FormatDate.vue'
import { usePreviewStore } from '../stores/preview'
import { useSuggestionsStore } from '../stores/suggestions'
import { fetchFile } from '../api'

interface Props {
  fileId: string
}

const props = defineProps<Props>()

const filesStore = useFilesStore()
const suggestionsStore = useSuggestionsStore()

const data = $computed(() => suggestionsStore.suggestionsMapped!.get(props.fileId)!)

// File loading

const fileInStore = $computed(() => filesStore.loaded[props.fileId])
const {} = useAsyncState(() => fileInStore ?? fetchFile(props.fileId), null)

const isFileLoaded = $computed(() => !!fileInStore)
// const isLoadError = $computed<boolean>(() => )
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
      :blob-src="fileInStore?.src"
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
