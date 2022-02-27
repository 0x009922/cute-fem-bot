import { defineStore } from 'pinia'
import { fetchFile } from '../api'

export const useFilesStore = defineStore('files', () => {
  const loaded = reactive<Record<string, undefined | { contentType: string | null; src: string }>>({})

  async function load(fileId: string) {
    const { contentType, blob } = await fetchFile(fileId)

    const src = URL.createObjectURL(blob)

    loaded[fileId] = { src, contentType }
  }

  return { loaded, load }
})
