<script lang="ts">
	import type { PageData } from './$types.js';
	import { Card, Badge } from '$components/index.js';

	let { data }: { data: PageData } = $props();
</script>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 space-y-6">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-slate-900 dark:text-white">Admin Control Center</h1>
			<p class="text-sm text-slate-500 dark:text-slate-400">System overview and user management.</p>
		</div>
		<Badge variant="warning">ADMIN ROLE</Badge>
	</div>

	<!-- Stats Grid -->
	<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
		<Card>
			<div class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Registered Users</div>
			<div class="mt-2 text-3xl font-extrabold text-slate-900 dark:text-white">{data.stats.totalUsers}</div>
		</Card>
		<Card>
			<div class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Active Sessions</div>
			<div class="mt-2 text-3xl font-extrabold text-slate-900 dark:text-white">{data.stats.activeSessions}</div>
		</Card>
	</div>

	<!-- Recent Users Table -->
	<Card title="Recent Users" description="Latest registered or seeded accounts in the system.">
		<div class="overflow-x-auto">
			<table class="w-full text-left text-sm text-slate-600 dark:text-slate-300">
				<thead class="border-b border-slate-200 text-xs uppercase text-slate-500 dark:border-slate-800">
					<tr>
						<th class="py-3 px-2">Email</th>
						<th class="py-3 px-2">Name</th>
						<th class="py-3 px-2">Role</th>
						<th class="py-3 px-2">Joined</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-slate-100 dark:divide-slate-800">
					{#each data.recentUsers as u}
						<tr>
							<td class="py-3 px-2 font-medium text-slate-900 dark:text-white">{u.email}</td>
							<td class="py-3 px-2">{u.name || '-'}</td>
							<td class="py-3 px-2">
								<Badge variant={u.role === 'ADMIN' ? 'warning' : 'default'}>{u.role}</Badge>
							</td>
							<td class="py-3 px-2">{new Date(u.createdAt).toLocaleDateString()}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</Card>
</div>
