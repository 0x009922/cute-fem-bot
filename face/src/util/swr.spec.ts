import { ComposedKey } from '@vue-kakuyaku/core'
import { test, describe, expect, vi } from 'vitest'
import { useResourcesPool, useScopesPool } from './swr'

describe('useScopesPool()', () => {
  test('when key is static, just scope is returned', () => {
    const { useScope } = useScopesPool((key: number) => 42)

    const scope = useScope(15)

    expect(scope).toEqual({
      expose: 42,
      key: 15,
    })
  })

  test('when key is static and composed, just scope is returned', () => {
    const { useScope } = useScopesPool((key: ComposedKey<string, { foo: 'bar' }>) => 42)

    const scope = useScope({ key: 'foo', payload: { foo: 'bar' } })

    expect(scope).toEqual({
      expose: 42,
      key: 'foo',
      payload: { foo: 'bar' },
    })
  })

  test('when key is reactive and null, scope is null', () => {
    const { useScope } = useScopesPool((k: string) => 54)

    const scope = useScope(ref(null))

    expect(scope.value).toBeNull()
  })

  test('when key is reactive and not null, scope is not null too', () => {
    const { useScope } = useScopesPool((k: string) => 54)

    const scope = useScope(ref('412'))

    expect(scope.value).toEqual({
      expose: 54,
      key: '412',
    })
  })

  test('when scope with the same key is used twice, it is initialized only once', () => {
    const init = vi.fn()
    const { useScope } = useScopesPool(() => init())

    useScope('1')
    useScope('1')

    expect(init).toBeCalledTimes(1)
  })

  test('when scope with the same key is used again, it returns the same data from within the scope', () => {
    const { useScope } = useScopesPool(() => {
      return {}
    })

    const first = useScope('1')
    const second = useScope('1')

    expect(first.expose).toBe(second.expose)
  })

  test('when scope is used twice, and one of usages is disposed, the scope is not disposed', () => {
    const disposed = vi.fn()
    const childDisposed = vi.fn()
    const { useScope } = useScopesPool(() => {
      onScopeDispose(disposed)
    })

    const child = effectScope()
    child.run(() => {
      useScope(42)
      onScopeDispose(childDisposed)
    })
    useScope(42)
    child.stop()

    expect(childDisposed).toBeCalledTimes(1)
    expect(disposed).not.toBeCalled()
  })

  test('when all scopes referencing the key are disposed, the scope is disposed as well', () => {
    const disposed = vi.fn()
    const { useScope } = useScopesPool(() => {
      onScopeDispose(disposed)
    })

    const child1 = effectScope()
    child1.run(() => {
      useScope(42)
    })

    const child2 = effectScope()
    child2.run(() => {
      useScope(42)
    })

    child1.stop()
    child2.stop()

    expect(disposed).toBeCalledTimes(1)
  })
})

describe('SWR', () => {
  test('happy path', async () => {
    const { useResource } = useResourcesPool(async (key: string) => ({ result: key }))

    const { state, mutate } = useResource('24')
    expect(state).toMatchInlineSnapshot(`
      {
        "fresh": false,
        "fulfilled": null,
        "pending": true,
        "rejected": null,
      }
    `)

    await until(() => state.pending).toBe(false)
    expect(state).toMatchInlineSnapshot(`
      {
        "fresh": true,
        "fulfilled": {
          "value": {
            "result": "24",
          },
        },
        "pending": false,
        "rejected": null,
      }
    `)

    mutate()
    expect(state).toMatchInlineSnapshot(`
      {
        "fresh": false,
        "fulfilled": {
          "value": {
            "result": "24",
          },
        },
        "pending": true,
        "rejected": null,
      }
    `)

    await until(() => state.pending).toBe(false)
    expect(state).toMatchInlineSnapshot(`
      {
        "fresh": true,
        "fulfilled": {
          "value": {
            "result": "24",
          },
        },
        "pending": false,
        "rejected": null,
      }
    `)
  })

  test('when promise is rejected, the fetch is not called again immediately', async () => {
    const fetch = vi.fn().mockRejectedValue(new Error('expected'))
    const { useResource } = useResourcesPool(fetch)

    const { state } = useResource(42)

    await until(() => state.pending).toBe(false)
    expect(state.rejected).not.toBeNull()

    await nextTick()
    expect(fetch).toBeCalledTimes(1)
  })
})
