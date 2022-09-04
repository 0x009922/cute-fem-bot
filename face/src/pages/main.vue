<script setup lang="ts">
import { setAuth } from '~/api'

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

watch(
  routeKey,
  (val) => {
    storeKey.value = val
    setAuth(val)
  },
  { immediate: true },
)

whenever(
  () => route.name === 'main',
  () => {
    router.replace({ name: 'suggestions', params: route.params })
  },
  { immediate: true },
)

const authKeyFromInput = $ref('')
function acceptAuthKey() {
  routeKey.value = authKeyFromInput
}
</script>

<template>
  <RouterView v-if="storeKey" />

  <template v-else>
    <h2>Ошибка</h2>
    <p>
      Чтобы пользоваться вебом, нужно сюда зайти с ключом. Ключ не вижу. Просто так ключ не достать. Видимо, что-то
      пошло не так. <br><br>
      Сообщи хозяину моему, пожалуйста.
    </p>

    <hr>

    <p>Или... у тебя есть ключ?</p>

    <div class="flex items-center space-x-4">
      <label for="auth-key">Ключ:</label>
      <input
        id="auth-key"
        v-model="authKeyFromInput"
        class="flex-1"
      >
      <button @click="acceptAuthKey">
        OK
      </button>
    </div>
  </template>
</template>
