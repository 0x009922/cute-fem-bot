import { ScopeKey, ComposedKey, PromiseStaleState, useTask, wheneverFulfilled, useParamScope } from '@vue-kakuyaku/core'
import { EffectScope, Ref } from 'vue'
import { Opaque } from 'type-fest'
import Debug from 'debug'

const swrDebug = Debug('swr')

type UniKey = ScopeKey | ComposedKey<ScopeKey, any>

type SpreadKey<K extends UniKey> = K extends ComposedKey<infer K, infer P> ? { key: K; payload: P } : { key: K }

type KeyOnly<K extends UniKey> = K extends ComposedKey<infer K, any> ? K : K

function getKeyOnly<K extends UniKey>(key: K): KeyOnly<K> {
  if (typeof key === 'object') return key.key as KeyOnly<K>
  return key as KeyOnly<K>
}

function spreadKey<K extends UniKey>(key: K): SpreadKey<K> {
  if (typeof key === 'object') return key as any
  return { key } as any
}

interface ScopesPool<E, K extends UniKey> {
  useScope: UseScopesPoolScopeFn<E, K>
}

type UseScopesPoolScopeFn<E, K extends UniKey> = <KK extends K | Ref<K | null>>(
  key: KK,
) => KK extends Ref<infer KK> ? Ref<KK extends K ? KeyedScope<E, K> : null> : KeyedScope<E, K>

type KeyedScope<E, K extends UniKey> = { expose: E } & SpreadKey<K>

export function useScopesPool<E, K extends UniKey>(fn: (key: K) => E): ScopesPool<E, K> {
  type Listener = Opaque<{}, 'listener'>

  interface Entry {
    setup: KeyedScope<E, K>
    scope: EffectScope
    listeners: Set<Listener>
  }

  const scopes = new Map<KeyOnly<K>, Entry>()

  function setupOrBind(key: K): KeyedScope<E, K> {
    const keyOnly = getKeyOnly(key)
    const listener = {} as Listener

    let entry: Entry

    if (scopes.has(keyOnly)) {
      entry = scopes.get(keyOnly)!
      entry.listeners.add(listener)
    } else {
      const scope = effectScope(true)
      const setup = scope.run(() => {
        const expose = fn(key)
        const spreadedKey = spreadKey(key)
        return { expose, ...spreadedKey } as KeyedScope<E, K>
      })!

      entry = {
        setup,
        scope,
        listeners: new Set([listener]),
      }
      scopes.set(keyOnly, entry)
    }

    getCurrentScope() &&
      onScopeDispose(() => {
        entry.listeners.delete(listener)

        if (!entry.listeners.size) {
          entry.scope.stop()
        }
      })

    return entry.setup
  }

  const useScope = ((kk) => {
    if (isRef(kk)) {
      const scope = useParamScope(
        computed(() => {
          const key = unref<null | K>(kk)

          return (
            key && {
              key: getKeyOnly(key),
              payload: key,
            }
          )
        }),
        (key) => setupOrBind(key),
      )

      return computed<null | KeyedScope<E, K>>(() => scope.value?.expose ?? null)
    }

    return setupOrBind(kk as unknown as K)
  }) as UseScopesPoolScopeFn<E, K>

  return { useScope }
}

interface UseSwrReturn<T, K extends UniKey> {
  useResource: UseResourceFn<T, K>
  memory: Memory<T, K>
}

type Memory<T, K extends UniKey> = Map<KeyOnly<K>, T>

type UseResourceFn<T, K extends UniKey> = <ResK extends K | Ref<K | null>>(
  key: ResK,
) => ResK extends Ref<infer ResK> ? Ref<ResK extends K ? UseResourceReturn<T, ResK> : null> : UseResourceReturn<T, K>

export type UseResourceReturn<T, K extends UniKey> = {
  state: PromiseStaleState<T>
  mutate: () => void
} & SpreadKey<K>

export function useResourcesPool<T, K extends UniKey>(
  fn: (key: K) => Promise<T>,
  options?: {
    debug?: string
  },
): UseSwrReturn<T, K> {
  const memory = shallowReactive(new Map<KeyOnly<K>, T>())

  const poolDebug = options?.debug ? swrDebug.extend(options.debug) : null

  const { useScope } = useScopesPool<UseResourceReturn<T, K>, K>((key): UseResourceReturn<T, K> => {
    const keyOnly = getKeyOnly(key)
    const resourceDebug = poolDebug?.extend(String(keyOnly))

    const inmemoryValue = eagerComputed(() => (memory.has(keyOnly) ? markRaw({ value: memory.get(keyOnly) }) : null))

    const { state, run } = useTask(() => fn(key))
    const fresh = ref(false)
    const pending = toRef(state, 'pending')

    wheneverFulfilled(state, (value) => {
      resourceDebug?.('fulfilled: %o', value)
      memory.set(keyOnly, value)
      fresh.value = true
    })
    whenever(
      pending,
      () => {
        resourceDebug?.('pending... (marked as stale)')
        fresh.value = false
      },
      { flush: 'sync' },
    )
    whenever(() => !inmemoryValue.value && !state.pending && !state.rejected, run, {
      immediate: true,
      flush: 'post',
    })

    return {
      state: readonly({
        pending,
        rejected: toRef(state, 'rejected'),
        fulfilled: inmemoryValue,
        fresh,
      }) as PromiseStaleState<T>,
      mutate: run,
      ...spreadKey(key),
    } as unknown as UseResourceReturn<T, K>
  })

  const useResource = ((key) => {
    const scope = useScope(key)

    if (isRef(scope)) return computed(() => scope.value?.expose ?? null)
    return scope.expose
  }) as UseResourceFn<T, K>

  return { memory, useResource }
}
