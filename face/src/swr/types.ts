import { Ref } from 'vue'
import { SetOptional } from 'type-fest'

export interface ResourceState<T> {
  data: null | { val: T }
  error: null | { val: unknown }
  isPending: boolean
}

export interface UseResourceReturn<T> {
  state: Ref<null | ResourceState<T>>
  key: Ref<null | { val: ResourceKey }>
  mutate: () => void
  reset: () => void
}

export type ResourceKey = string | number | symbol | null

export interface ResourceStore<T> {
  get: (key: ResourceKey) => ResourceState<T> | null
  set: (key: ResourceKey, state: ResourceState<T> | null) => void
}

export interface UseResourceParamsGeneral {
  /**
   * @default true
   */
  errorRetry?: boolean

  /**
   * @default 3
   */
  errorRetryCount?: number

  /**
   * @default 5_000
   */
  errorRetryInterval?: number

  /**
   * @default false
   */
  logs?: boolean | string

  /**
   * Set to true if you want to prevent auto revalidation in case when SWR hook is just called and it finds
   * already existing data.
   *
   * @default false
   */
  noAutoRevalidation?: boolean
}

export type FetchFn<T> = (onAbort: (hook: () => void) => void) => T | Promise<T>

export interface UseResourceParams<T> extends UseResourceParamsGeneral {
  fetch: ResourceFetch<T>
  store?: ResourceStore<T>
}

export type ResourceFetch<T> =
  | FetchFn<T>
  | MaybeKeyedFetchFn<T>
  | Ref<null | undefined | false | FetchFn<T> | MaybeKeyedFetchFn<T>>

export interface KeyedFetchFn<T> {
  key: ResourceKey
  fn: FetchFn<T>
}

export type MaybeKeyedFetchFn<T> = SetOptional<KeyedFetchFn<T>, 'key'>
