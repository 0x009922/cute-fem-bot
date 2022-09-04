import { defineStore } from 'pinia'
import { useFilesStore, isUnavailable } from './files'
import { useSuggestionsStore } from './suggestions'

export const usePreviewStore = defineStore('preview', () => {
  const filesStore = useFilesStore()
  const suggestionsStore = useSuggestionsStore()

  let fileId = $ref<null | string>(null)

  const file = $computed(() => {
    const file = (fileId && filesStore.getFile(fileId)) || null
    if (!file || isUnavailable(file)) return null
    return file
  })
  const type = $computed(() => fileId && suggestionsStore.suggestionTypes?.get(fileId))

  function open(id: string) {
    fileId = id
  }

  function close() {
    fileId = null
  }

  return $$({
    fileId,
    file,
    open,
    close,
    type,
  })
})
