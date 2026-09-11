<script lang="ts">
	import type { ActionData } from './$types.js';
	import { Button, Card, Input } from '$components/index.js';

	let { form }: { form: ActionData } = $props();

	let email = $state('demo@example.com');
	let password = $state('12345678');

	function setDemo() {
		email = 'demo@example.com';
		password = '12345678';
	}

	function setAdmin() {
		email = 'admin@example.com';
		password = '12345678';
	}
</script>

<div class="mx-auto max-w-md px-4 py-16">
	<Card title="Sign In" description="Enter your credentials or pick a pre-seeded demo account.">
		{#if form?.error}
			<div class="mb-4 rounded-lg bg-rose-50 p-3 text-xs font-medium text-rose-700 dark:bg-rose-950/50 dark:text-rose-300">
				{form.error}
			</div>
		{/if}

		<!-- Quick Fill Presets -->
		<div class="mb-6 flex gap-2">
			<button
				type="button"
				onclick={setDemo}
				class="flex-1 rounded-md border border-slate-200 bg-slate-50 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100 dark:border-slate-800 dark:bg-slate-800 dark:text-slate-300 cursor-pointer"
			>
				Fill Demo User
			</button>
			<button
				type="button"
				onclick={setAdmin}
				class="flex-1 rounded-md border border-slate-200 bg-slate-50 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100 dark:border-slate-800 dark:bg-slate-800 dark:text-slate-300 cursor-pointer"
			>
				Fill Admin User
			</button>
		</div>

		<form method="POST" class="space-y-4">
			<Input
				label="Email Address"
				type="email"
				name="email"
				required
				bind:value={email}
			/>

			<Input
				label="Password"
				type="password"
				name="password"
				required
				bind:value={password}
			/>

			<Button type="submit" variant="primary" class="w-full">
				Sign In
			</Button>
		</form>

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
