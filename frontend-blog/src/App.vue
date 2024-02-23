<template>
  <h1 class="text-center">
    My blog
  </h1>

  <div class="container-md">
    <BlogPostEntry title="Titre 1" />
    <BlogPostEntry title="Titre 2" />
  </div>

  
</template>

<script setup>
  import BlogPostEntry from './components/BlogPostEntry.vue'
  import { onMounted }  from 'vue'

  onMounted(() => {

    const blogPostEntries = fetch('https://example.com/api/blogPosts')
      .then(response => response.json())
      .then(data => {
        // Store the fetched data into the blogPostEntries variable
        return data;
      })
      .catch(error => {
        console.error('Error fetching blog posts:', error);
      });
  })

  
</script>

<style scoped>

</style>
