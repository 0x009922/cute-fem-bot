import { reactive } from 'vue'
import { ResourceState, ResourceStore, ResourceKey } from './types'

export interface AmnesiaStore<T> extends ResourceStore<T> {
  reset: () => void
}

export function createAmnesiaStore<T>(): AmnesiaStore<T> {
  const NullKey = Symbol('null key')

  /**
   * `reactive()` doesn't work properly with Vue 2 :<
   * Vue 3, where are you when you are needed so much...
   */
  const storage = reactive<Record<Exclude<ResourceKey, null>, ResourceState<any> | null>>({
    [NullKey]: null,
  })

  return {
    reset: () => {},
    get(key) {
      return (
        storage[
          key ??
            // https://github.com/Microsoft/TypeScript/issues/24587
            (NullKey as any)
        ] ?? null
      )
    },
    set(key, state) {
      const actualKey: any = key ?? NullKey
      storage[actualKey] = state
    },
  }
}
