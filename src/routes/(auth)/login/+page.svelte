<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import type { ActionData } from './$types.js';
	import { Button, Card } from '$components/index.js';
	import { authModal } from '$lib/state/auth-modal.svelte.js';
	import { Sparkles, LogIn, ArrowRight } from 'lucide-svelte';

	let { form }: { form: ActionData } = $props();

	onMount(() => {
		const redirectTarget = page.url.searchParams.get('redirect');
		const errorParam = page.url.searchParams.get('error') || (form?.error ? String(form.error) : null);
		authModal.open({
			redirectUrl: redirectTarget || '/dashboard',
			error: errorParam
		});
	});

	function openModal() {
		const redirectTarget = page.url.searchParams.get('redirect');
		authModal.open({
			redirectUrl: redirectTarget || '/dashboard'
		});
	}
</script>

<div class="mx-auto max-w-md px-4 py-16 text-center">
	<Card title="Sign In" description="Sign in to access your dashboard or use 1-click demo credentials.">
		<div class="my-4 flex flex-col items-center justify-center">
			<div class="mb-3 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-indigo-50 text-indigo-600 dark:bg-indigo-950/50 dark:text-indigo-400">
				<Sparkles class="h-6 w-6" />
			</div>
		</div>

		{#if form?.error}
			<div class="mb-4 rounded-lg bg-rose-50 p-3 text-xs font-medium text-rose-700 dark:bg-rose-950/50 dark:text-rose-300">
				{form.error}
			</div>
		{/if}

		<div class="space-y-3">
			<Button type="button" variant="primary" class="w-full flex items-center justify-center gap-2" onclick={openModal}>
				<LogIn class="h-4 w-4" />
				<span>Open Sign In Modal</span>
			</Button>

			<!-- 1-Click Instant Demo Routes -->
			<div class="grid grid-cols-2 gap-2 pt-2">
				<a
					href="/demo"
					class="flex items-center justify-center gap-1.5 rounded-xl border border-indigo-200 bg-indigo-50/70 py-2.5 px-3 text-xs font-bold text-indigo-700 hover:bg-indigo-100 dark:border-indigo-900/60 dark:bg-indigo-950/40 dark:text-indigo-300"
				>
					<span>⚡ Demo User</span>
				</a>
				<a
					href="/demo?role=admin"
					class="flex items-center justify-center gap-1.5 rounded-xl border border-purple-200 bg-purple-50/70 py-2.5 px-3 text-xs font-bold text-purple-700 hover:bg-purple-100 dark:border-purple-900/60 dark:bg-purple-950/40 dark:text-purple-300"
				>
					<span>🛡️ Admin User</span>
				</a>
			</div>
		</div>

		{#snippet footer()}
			<div class="text-center text-xs text-slate-500 dark:text-slate-400">
				Don't have an account?
				<a href="/register" class="font-medium text-indigo-600 hover:underline dark:text-indigo-400">
					Create one
				</a>
			</div>
		{/snippet}
	</Card>
</div>
