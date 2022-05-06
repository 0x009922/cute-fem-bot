<script lang="ts">
export default defineComponent({
  setup() {
    const count = useInterval(100)

    return () => `.`.repeat(count.value % 4)
  },
})
</script>
