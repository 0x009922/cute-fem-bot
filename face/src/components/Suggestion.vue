<script setup lang="ts">
import { SchemaSuggestion } from '../api'
import { useFilesStore } from '../stores/files'
import SuggestionPreviewImg from './SuggestionPreviewImg.vue'
import SuggestionPreviewVideo from './SuggestionPreviewVideo.vue'
import SuggestionTypeTag from './SuggestionTypeTag.vue'

interface Props {
  data: SchemaSuggestion
  num: number
}

const props = defineProps<Props>()

const filesStore = useFilesStore()

const type = computed(() => props.data.file_type)

// File loading

const file = computed(() => filesStore.loaded[props.data.file_id])

const isFileLoaded = computed(() => !!file.value)

const isLoading = ref(false)

async function load() {
  try {
    isLoading.value = true
    await filesStore.load(props.data.file_id)
  } finally {
    isLoading.value = false
  }
}

const typeDefinitely = computed<'photo' | 'video' | 'document'>(() => {
  if (type.value === 'photo' || type.value === 'video') return type.value

  const mime = file.value?.contentType
  if (mime) {
    if (mime.startsWith('image/')) return 'photo'
    if (mime.startsWith('video/')) return 'video'
  }

  return 'document'
})

// Loading on intersection

const root = templateRef('root')

const isVisible = ref(false)

useIntersectionObserver(root, ([{ isIntersecting }]) => {
  isVisible.value = isIntersecting
})

whenever(
  () => !isFileLoaded.value && isVisible.value && !isLoading.value,
  () => load(),
  { immediate: true },
)
</script>

<template>
  <div
    ref="root"
    class="min-h-300px border border-gray-200 rounded p-4 relative"
  >
    <header class="p-2 flex items-center">
      <div class="flex-1 text-xl">
        #{{ num }}
      </div>

      <SuggestionTypeTag :value="typeDefinitely" />
    </header>

    <button
      v-if="!isFileLoaded"
      @click="load"
    >
      Посмотреть
    </button>

    <template v-else>
      <SuggestionPreviewImg
        v-if="typeDefinitely === 'photo'"
        :src="file!.src"
      />

      <SuggestionPreviewVideo
        v-else-if="typeDefinitely === 'video'"
        :src="file!.src"
      />

      <span v-else>Нема {{ typeDefinitely }}</span>
    </template>
  </div>
</template>
