import { defineStore } from 'pinia'

export const FILE_IS_UNAVAILABLE = Symbol('File is unavailable')

export const useFilesStore = defineStore('files', () => {
  const loaded = reactive<
    Record<string, undefined | typeof FILE_IS_UNAVAILABLE | { contentType: string | null; src: string }>
  >({})

  function setAsNotAvailable(fileId: string) {
    loaded[fileId] = FILE_IS_UNAVAILABLE
  }

  return { loaded, setAsNotAvailable }
})
