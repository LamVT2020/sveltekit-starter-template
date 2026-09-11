<script lang="ts">
	import type { PageData } from './$types.js';
	import { Card, Badge, Button } from '$components/index.js';

	let { data }: { data: PageData } = $props();
</script>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 space-y-6">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-slate-900 dark:text-white">User Dashboard</h1>
			<p class="text-sm text-slate-500 dark:text-slate-400">Welcome back, {data.user.name || data.user.email}!</p>
		</div>
		<Badge variant="success">Authenticated</Badge>
	</div>

	<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
		<Card title="Account Details" description="Information regarding your current session.">
			<div class="space-y-2 text-sm text-slate-600 dark:text-slate-300">
				<div><strong class="text-slate-900 dark:text-white">ID:</strong> {data.user.id}</div>
				<div><strong class="text-slate-900 dark:text-white">Email:</strong> {data.user.email}</div>
				<div><strong class="text-slate-900 dark:text-white">Role:</strong> <Badge variant="default">{data.user.role}</Badge></div>
			</div>
		</Card>

		<Card title="Quick Actions" description="Navigate application features.">
			<div class="flex flex-wrap gap-3">
				{#if data.user.role === 'ADMIN'}
					<a href="/admin">
						<Button variant="primary">Go to Admin Panel</Button>
					</a>
				{/if}
				<form action="/logout" method="POST">
					<Button type="submit" variant="outline">Sign Out</Button>
				</form>
			</div>
		</Card>
	</div>
</div>
