<template>
  <div class="blog-post-entry">
    <a href="#" @click="">{{ title }}</a>
  </div>
</template>

<script setup>

  const props = defineProps({
    title: {
      type: Object,
      required: true
    }
  });
</script>