import { defineStore } from 'pinia'

export const useFilesStore = defineStore('files', () => {
  const loaded = reactive<Record<string, undefined | { contentType: string | null; src: string }>>({})

  return { loaded }
})
