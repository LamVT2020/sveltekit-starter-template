<script lang="ts">
	import { Button, Card, Badge } from '$components/index.js';
</script>

<div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
	<!-- Hero Section -->
	<div class="text-center space-y-4 max-w-3xl mx-auto">
		<div class="flex items-center justify-center gap-2">
			<Badge variant="info">SvelteKit 2</Badge>
			<Badge variant="success">Svelte 5 Runes</Badge>
			<Badge variant="warning">Tailwind CSS 4</Badge>
			<Badge variant="default">Prisma ORM</Badge>
		</div>

		<h1 class="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white sm:text-5xl">
			Canonical SvelteKit Starter
		</h1>
		<p class="text-lg text-slate-600 dark:text-slate-400">
			A robust, production-grade template standardized with 7-step deployment, PM2 orchestration,
			Bcrypt 12 auth, structured logging, and scalable modular architecture.
		</p>

		<div class="flex items-center justify-center gap-4 pt-4">
			<a href="/login">
				<Button size="lg" variant="primary">Sign In to Dashboard</Button>
			</a>
			<a href="https://github.com" target="_blank" rel="noreferrer">
				<Button size="lg" variant="outline">View Architecture Spec</Button>
			</a>
		</div>
	</div>

	<!-- Architecture Grid -->
	<div class="mt-16 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
		<Card title="⚡ Unified Env & Config" description="Strict Zod validation across 5 standard environment blocks.">
			<ul class="mt-3 space-y-1 text-xs text-slate-500 dark:text-slate-400 list-disc list-inside">
				<li>Port, Origin, Database URL</li>
				<li>Data, Log, and Backup directories</li>
				<li>Log level & Google Analytics ID</li>
				<li>Auth secret & AI providers</li>
			</ul>
		</Card>

		<Card title="🛡️ Enterprise Auth & Security" description="Bcrypt 12 rounds, unicode NFKC normalization, role-based access.">
			<ul class="mt-3 space-y-1 text-xs text-slate-500 dark:text-slate-400 list-disc list-inside">
				<li>Pre-seeded demo & admin credentials</li>
				<li>Sliding window session handling</li>
				<li>Role guards (USER & ADMIN)</li>
				<li>Security headers & rate limiter</li>
			</ul>
		</Card>

		<Card title="🚀 7-Step Deployment Script" description="Automated zero-downtime deployment pipeline.">
			<ul class="mt-3 space-y-1 text-xs text-slate-500 dark:text-slate-400 list-disc list-inside">
				<li>Pre-deployment DB backup</li>
				<li>Prisma push & auto-seeding</li>
				<li>Production build with Vite</li>
				<li>PM2 cluster reload & health check</li>
			</ul>
		</Card>
	</div>
</div>
