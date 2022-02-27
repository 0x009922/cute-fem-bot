<script setup lang="ts">
import { setAuth } from '../api'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()

// const isOnMain  = computed(() => route.path === '/')

const routeKey = computed({
  get: () => route.params.key,
  set: (v) => router.replace({ params: { key: v } }),
})

const auth = useAuthStore()
const key = computed({ get: () => auth.key, set: (v) => auth.$patch({ key: v }) })
watch(key, setAuth)

syncRef(routeKey, key)
const keysAreSame = eagerComputed(() => key.value === routeKey.value)

function acceptKey() {
  routeKey.value = key.value
}
</script>

<template>
  <!-- <div v-if="!isOnMain">
    <RouterLink to="" >
  </div> -->

  <div>
    <label for="key"> Ключ: </label>
    <input
      id="key"
      v-model="key"
    >

    <button
      v-show="!keysAreSame"
      @click="acceptKey()"
    >
      Так точно
    </button>
  </div>

  <router-view />
</template>
