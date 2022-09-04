import { defineStore } from 'pinia'
import { ComputedRef, Ref } from 'vue'
import { fetchFile } from '~/api'
import { UseResourceReturn, useResourcesPool } from '~/util/swr'

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
  const { useResource, memory } = useResourcesPool(
    async (id: string) => {
      const maybeFile = await fetchFile(id)

      if (maybeFile) {
        const { blob, contentType } = maybeFile
        const src = URL.createObjectURL(blob)

        return { src, contentType }
      }

      return FILE_IS_UNAVAILABLE
    },
    { debug: 'files' },
  )

  function getFile(id: string): null | FileInStore {
    return memory.get(id) ?? null
  }

  return { useResource, getFile }
})

export function useFileSwr(fileId: ComputedRef<null | string>): Ref<null | UseResourceReturn<FileInStore, string>> {
  const store = useFilesStore()
  return store.useResource(fileId)
}
