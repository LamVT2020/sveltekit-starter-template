<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { LayoutData } from './$types.js';
	import { Navbar, Footer } from '$components/index.js';
	import '../app.css';

	let { data, children }: { data: LayoutData; children: Snippet } = $props();
</script>

<div class="min-h-screen flex flex-col bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
	<Navbar user={data.user} />
	<main class="flex-1">
		{@render children()}
	</main>
	<Footer />
</div>
