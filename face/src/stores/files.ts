import { createAmnesiaStore, UseResourceReturn, useSwr } from '@vue-swr-composable/core'
import { defineStore } from 'pinia'
import { ComputedRef } from 'vue'
import { fetchFile } from '~/api'

export const FILE_IS_UNAVAILABLE = Symbol('File is unavailable')

export interface LoadedFile {
  contentType: string | null
  src: string
}

export type FileInStore = LoadedFile | typeof FILE_IS_UNAVAILABLE

export function isUnavailable(x: unknown): x is typeof FILE_IS_UNAVAILABLE {
  return x === FILE_IS_UNAVAILABLE
}

export const useFilesStore = defineStore('files', () => {
  const inMemory = createAmnesiaStore<FileInStore>()

  return { inMemory }
})

export function useFileSwr(fileId: ComputedRef<null | string>): UseResourceReturn<FileInStore> {
  const store = useFilesStore()

  return useSwr({
    fetch: computed(() => {
      const id = unref(fileId)
      if (!id) return null

      return {
        key: id,
        fn: async () => {
          const maybeFile = await fetchFile(id)

          if (maybeFile) {
            const { blob, contentType } = maybeFile
            const src = URL.createObjectURL(blob)

            return { src, contentType }
          }

          return FILE_IS_UNAVAILABLE
        },
      }
    }),
    store: {
      get: (key) => store.inMemory.get(key),
      set: (key, state) => store.inMemory.set(key, state),
    },
  })
}
