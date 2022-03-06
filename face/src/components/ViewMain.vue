<script setup lang="ts">
import { setAuth } from '../api'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()

const routeKey = computed<string>({
  get: () => route.params.key as string,
  set: (v) => router.replace({ params: { key: v } }),
})

const auth = useAuthStore()
const storeKey = computed({
  get: () => auth.key,
  set: (key) => auth.$patch({ key }),
})

const key = ref('')
const keyIsSynced = eagerComputed(() => key.value === routeKey.value)

watch(
  routeKey,
  (val) => {
    storeKey.value = key.value = val
    setAuth(val)
  },
  { immediate: true },
)

function acceptKey() {
  routeKey.value = key.value
}
</script>

<template>
  <div>
    <label for="key"> Ключ: </label>
    <input
      id="key"
      v-model="key"
    >

    <button
      v-show="!keyIsSynced"
      @click="acceptKey()"
    >
      Так точно
    </button>
  </div>

  <router-view />
</template>
