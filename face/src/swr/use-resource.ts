import { computed, watch, markRaw, onScopeDispose } from 'vue'
import { ResourceState, ResourceStore, UseResourceParams, UseResourceReturn, ResourceKey, KeyedFetchFn } from './types'
import { createAmnesiaStore } from './amnesia-store'
import { normalizeResourceFetch, createLogger, Logger } from './tools'
import { setupErrorRetry } from './error-retry'

const RESOURCE_STATE_EMPTY: ResourceState<any> = Object.freeze({
  data: null,
  error: null,
  isPending: false,
})

const FETCH_TASK_ABORTED = Symbol('Aborted')

/**
 * Run fetch and update state accordingly to progress. May be aborted.
 */
function executeFetch<T>({
  fetch: { key, fn: fetchFn },
  store: { set: storeSet, get: storeGet },
  signal,
  logger,
}: {
  fetch: KeyedFetchFn<T>
  store: ResourceStore<T>
  signal: AbortSignal
  logger: Logger
}) {
  function stateUpdate(patch: Partial<ResourceState<T>>) {
    const current = storeGet(key)
    storeSet(key, {
      ...(current ?? RESOURCE_STATE_EMPTY),
      ...patch,
    })
  }

  Promise.resolve()
    .then(() => {
      const state = storeGet(key) ?? RESOURCE_STATE_EMPTY

      storeSet(key, { ...state, isPending: true })
      logger.info('Starting fetch for %o', key)

      return new Promise<T | typeof FETCH_TASK_ABORTED>((resolve, reject) => {
        // collecting hooks
        const hooks: (() => void)[] = []
        function onAbort(hook: () => void): void {
          hooks.push(hook)
        }

        // fire hooks on abort and anyway resolve the promise
        signal.addEventListener('abort', () => {
          logger.info('Abort signal for %o received', key)

          try {
            hooks.forEach((x) => x())
          } catch (err) {
            // This is not fetching error, this is an error of abortation, special case
            logger.force().warn('Abortation hooks error:', err)
          } finally {
            resolve(FETCH_TASK_ABORTED)
          }
        })

        try {
          const result = fetchFn(onAbort)
          if (result instanceof Promise) {
            result.then(resolve).catch(reject)
          } else {
            resolve(result)
          }
        } catch (err) {
          reject(err)
        }
      })
    })
    .then((fetchResult) => {
      if (fetchResult === FETCH_TASK_ABORTED) {
        logger.info('Fetch of %o aborted, ignore result', key)
        return
      }

      logger.info('Updating data for %o: %o', key, fetchResult)

      stateUpdate({
        data: markRaw({ val: fetchResult }),
        error: null,
        isPending: false,
      })
    })
    .catch((err) => {
      logger.info('Fetch failed for %o: %o', key, err)
      stateUpdate({
        error: markRaw({ val: err }),
        isPending: false,
      })
    })
}

export function useSwr<T>(params: UseResourceParams<T>): UseResourceReturn<T> {
  const resourceFetch = normalizeResourceFetch(params.fetch)
  const key = computed<null | { val: ResourceKey }>(() =>
    resourceFetch.value ? { val: resourceFetch.value.key } : null,
  )

  const logger = createLogger({
    silent: !(params.logs ?? false),
    scope: typeof params?.logs === 'string' ? params.logs : undefined,
  })

  const store: ResourceStore<T> = params?.store ?? createAmnesiaStore()
  const stateByKey = computed<null | ResourceState<T>>(() => {
    const keyVal = key.value

    if (keyVal) {
      return store.get(keyVal.val)
    }

    return null
  })

  let latestFetchAbortController: AbortController | null = null
  function abortLatestFetchTask() {
    latestFetchAbortController?.abort()
    latestFetchAbortController = null
  }

  function scheduleFetchTask(fetch: KeyedFetchFn<T>) {
    latestFetchAbortController = new AbortController()
    executeFetch({
      fetch,
      store,
      signal: latestFetchAbortController.signal,
      logger,
    })
  }

  function dispose() {
    abortLatestFetchTask()
  }
  onScopeDispose(dispose)

  // abortation on **key** change
  // and also logs
  watch(
    key,
    (val, oldVal) => {
      const keysEqual = oldVal && val && oldVal.val === val.val

      if (!keysEqual) {
        if (oldVal && latestFetchAbortController) {
          logger.info('Aborting last fetch for %o because key updated to %o', oldVal.val, val?.val)
          abortLatestFetchTask()
        }
      }
    },
    {
      immediate: true,
    },
  )

  // immediate initial revalidation in case when data is already exists
  if (!params.noAutoRevalidation) {
    if (stateByKey.value && !!resourceFetch.value) {
      logger.info('Scheduling auto-revalidation fetch for %o', resourceFetch.value.key)
      scheduleFetchTask(resourceFetch.value)
    }
  }

  // fetch if the id exists but the state is not
  watch(
    () => !!resourceFetch.value && !stateByKey.value,
    (flag) => {
      if (flag) {
        logger.info('Scheduling fetch for %o because state is empty', resourceFetch.value!.key)
        scheduleFetchTask(resourceFetch.value!)
      }
    },
    { immediate: true },
  )

  function reset() {
    key.value && store.set(key.value.val, null)
  }

  function mutate() {
    // EDGE CASE mutating the pending resource - abort or ignore mutation?

    // now just abort
    abortLatestFetchTask()
    if (resourceFetch.value) {
      logger.info('Scheduling fetch for %o because of mutation', resourceFetch.value.key)
      scheduleFetchTask(resourceFetch.value)
    }
  }

  if (params?.errorRetry ?? true) {
    setupErrorRetry(
      { state: stateByKey, mutate },
      {
        count: params?.errorRetryCount ?? 3,
        interval: params?.errorRetryInterval ?? 5_000,
      },
    )
  }

  return {
    state: stateByKey,
    key,
    reset,
    mutate,
  }
}
