<script lang="ts">
	import { authModal } from '$lib/state/auth-modal.svelte.js';

	interface Props {
		user?: {
			id: string;
			email: string;
			name?: string | null;
			role: string;
		} | null;
	}

	let { user }: Props = $props();
</script>

<header class="sticky top-0 z-40 border-b border-slate-200 bg-white/80 backdrop-blur-md dark:border-slate-800 dark:bg-slate-900/80">
	<div class="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
		<div class="flex items-center gap-6">
			<a href="/" class="flex items-center gap-2 font-bold text-slate-900 dark:text-white text-lg">
				<span class="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-600 text-white font-black">
					S
				</span>
				<span>SvelteKit Starter</span>
			</a>

			<nav class="hidden md:flex items-center gap-4 text-sm font-medium text-slate-600 dark:text-slate-300">
				<a href="/" class="hover:text-indigo-600 dark:hover:text-indigo-400">Home</a>
				{#if user}
					<a href="/dashboard" class="hover:text-indigo-600 dark:hover:text-indigo-400">Dashboard</a>
					{#if user.role === 'ADMIN'}
						<a href="/admin" class="text-indigo-600 dark:text-indigo-400 font-semibold">Admin Panel</a>
					{/if}
				{/if}
			</nav>
		</div>

		<div class="flex items-center gap-3">
			{#if user}
				<div class="hidden sm:flex flex-col text-right">
					<span class="text-xs font-semibold text-slate-900 dark:text-slate-100">{user.name || user.email}</span>
					<span class="text-[10px] text-slate-500 uppercase tracking-wider">{user.role}</span>
				</div>
				<form action="/logout" method="POST">
					<button
						type="submit"
						class="rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800 cursor-pointer"
					>
						Sign out
					</button>
				</form>
			{:else}
				<button
					type="button"
					onclick={() => authModal.open()}
					class="rounded-lg px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-800 cursor-pointer"
				>
					Sign In
				</button>
				<a
					href="/register"
					class="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700"
				>
					Get Started
				</a>
			{/if}
		</div>
	</div>
</header>
