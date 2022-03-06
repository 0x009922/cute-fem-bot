module.exports = {
  extends: ['plugin:vue/vue3-recommended', 'alloy', './.eslintrc-auto-import.json'],
  parser: 'vue-eslint-parser',
  parserOptions: {
    parser: '@typescript-eslint/parser',
    sourceType: 'module',
  },
  globals: {
    defineProps: true,
    defineEmits: true,
    $ref: true,
    $: true,
    $$: true,
    $computed: true,
  },
  rules: {
    'vue/html-indent': ['error', 2],
    'spaced-comment': [
      'error',
      'always',
      {
        markers: ['/'],
      },
    ],
  },
}
