<script lang="ts">
	import type { ActionData } from './$types.js';
	import { Button, Card, Input } from '$components/index.js';

	let { form }: { form: ActionData } = $props();
</script>

<div class="mx-auto max-w-md px-4 py-16">
	<Card title="Create Account" description="Sign up for a new standard account.">
		{#if form?.error}
			<div class="mb-4 rounded-lg bg-rose-50 p-3 text-xs font-medium text-rose-700 dark:bg-rose-950/50 dark:text-rose-300">
				{form.error}
			</div>
		{/if}

		<form method="POST" class="space-y-4">
			<Input
				label="Full Name"
				type="text"
				name="name"
				placeholder="Alex Doe"
				value={form?.name ?? ''}
			/>

			<Input
				label="Email Address"
				type="email"
				name="email"
				required
				placeholder="alex@example.com"
				value={form?.email ?? ''}
			/>

			<Input
				label="Password"
				type="password"
				name="password"
				required
				placeholder="Minimum 8 characters"
			/>

			<Button type="submit" variant="primary" class="w-full">
				Register
			</Button>
		</form>

		{#snippet footer()}
			<div class="text-center text-xs text-slate-500 dark:text-slate-400">
				Already have an account?
				<a href="/login" class="font-medium text-indigo-600 hover:underline dark:text-indigo-400">
					Sign in
				</a>
			</div>
		{/snippet}
	</Card>
</div>
