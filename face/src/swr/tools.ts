import { KeyedFetchFn, ResourceFetch, ResourceState } from './types'
import { unref, Ref, computed } from 'vue'

export function normalizeResourceFetch<T>(input: ResourceFetch<T>): Ref<KeyedFetchFn<T> | null> {
  return computed(() => {
    const val = unref(input)

    if (typeof val === 'function') {
      return {
        fn: val,
        key: null,
      }
    }

    if (val) {
      return {
        fn: val.fn,
        key: val.key ?? null,
      }
    }

    return null
  })
}

export interface Logger {
  force: () => Logger
  info: LogFn
  warn: LogFn
}

export type LogFn = (msg: string, ...args: any[]) => void

export function createLogger(params: { scope?: string; silent: boolean }): Logger {
  const prefix = params.scope ? `[swr:${params.scope}]` : '[swr]'

  return {
    force: () => createLogger({ ...params, silent: false }),
    info: (msg, ...args) => !params.silent && console.info(`${prefix} ${msg}`, ...args),
    warn: (msg, ...args) => !params.silent && console.warn(`${prefix} ${msg}`, ...args),
  }
}

export function wrapState<T>(state: Ref<null | ResourceState<T>>): {
  isPending: Ref<boolean>
  error: Ref<null | { val: unknown }>
  data: Ref<null | { val: T }>
} {
  return {
    isPending: computed(() => !!state.value?.isPending),
    error: computed(() => state.value?.error ?? null),
    data: computed(() => state.value?.data ?? null),
  }
}
