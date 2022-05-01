<script setup lang="ts">
import { useFilesStore, FILE_IS_UNAVAILABLE } from '../stores/files'
import SuggestionActions from './SuggestionActions.vue'
import SuggestionPreview from './SuggestionPreview.vue'
import FormatDate from './FormatDate.vue'
import { usePreviewStore } from '../stores/preview'
import { useSuggestionsStore } from '../stores/suggestions'
import { fetchFile } from '../api'
import Spinner from './Spinner.vue'

interface Props {
  fileId: string
}

const props = defineProps<Props>()

const filesStore = useFilesStore()
const suggestionsStore = useSuggestionsStore()

const data = $computed(() => suggestionsStore.suggestionsMapped!.get(props.fileId)!)

// INTERSECTION

const root = templateRef('root')
let isVisible = $ref(false)

useIntersectionObserver(root, ([{ isIntersecting }]) => {
  isVisible = isIntersecting
})

// LOADING

const fileInStore = $computed(() => filesStore.loaded[props.fileId])
const {
  isLoading,
  execute: load,
  error,
} = $(
  useAsyncState<undefined>(
    async () => {
      const maybeFile = await fetchFile(props.fileId)
      if (maybeFile) {
        const { blob, contentType } = maybeFile
        const src = URL.createObjectURL(blob)

        filesStore.loaded[props.fileId] = { src, contentType }
      } else {
        filesStore.setAsNotAvailable(props.fileId)
      }
      return undefined
    },
    undefined,
    { immediate: false },
  ),
)

const isFileLoaded = $computed(() => !!fileInStore)

const shouldLoad = $computed(() => !isFileLoaded && isVisible && !isLoading && isPreviewable && !error)

whenever($$(shouldLoad), () => load(), { immediate: true })

// PREVIEW

const previewStore = usePreviewStore()

const typeDefinitely = $computed(() => suggestionsStore.suggestionTypes!.get(props.fileId)!)
const isPreviewable = $computed(() => typeDefinitely !== 'document')
const fileBlobSrc = $computed<undefined | string>(() =>
  fileInStore === FILE_IS_UNAVAILABLE ? undefined : fileInStore?.src,
)
const fileIsUnavailable = $computed(() => fileInStore === FILE_IS_UNAVAILABLE)

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
      v-if="isLoading"
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
      <span class="text-sm"><slot name="user" /></span>

      <span>
        <FormatDate :iso="data.inserted_at" />
      </span>
    </div>

    <SuggestionActions :data="data" />
  </div>
</template>
