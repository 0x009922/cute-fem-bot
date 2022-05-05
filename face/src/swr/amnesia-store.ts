import { Ref } from 'vue'
import { ResourceState, ResourceStore, ResourceKey } from './types'

export interface AmnesiaStore<T> extends ResourceStore<T> {
  storage: Ref<Record<Exclude<ResourceKey, null>, ResourceState<any> | null>>
}

export function createAmnesiaStore<T>(): AmnesiaStore<T> {
  const NullKey = Symbol('null key')

  /**
   * `reactive()` doesn't work properly with Vue 2 :<
   * Vue 3, where are you when you are needed so much...
   */
  const storage = ref<Record<Exclude<ResourceKey, null>, ResourceState<any> | null>>({
    [NullKey]: null,
  })

  return {
    storage,
    get(key) {
      return (
        storage.value[
          key ??
            // https://github.com/Microsoft/TypeScript/issues/24587
            (NullKey as any)
        ] ?? null
      )
    },
    set(key, state) {
      const actualKey: any = key ?? NullKey
      storage.value[actualKey] = state
    },
  }
}
