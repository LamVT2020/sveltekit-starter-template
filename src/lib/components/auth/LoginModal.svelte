<script lang="ts">
	import { authModal } from '$lib/state/auth-modal.svelte.js';
	import { invalidateAll, goto } from '$app/navigation';
	import { page } from '$app/state';
	import {
		X,
		ArrowRight,
		ShieldCheck,
		Key,
		Eye,
		EyeOff,
		AlertCircle
	} from 'lucide-svelte';

	let email = $state('demo@example.com');
	let password = $state('12345678');
	let showPassword = $state(false);
	let loading = $state(false);
	let quickLoading = $state<'admin' | 'demo' | null>(null);
	let localError = $state<string | null>(null);

	const activeError = $derived(localError || authModal.error);
	const isDemoEnabled = $derived((page.data.enableDemoLogin ?? true) === true);

	function fillAccount(type: 'admin' | 'demo') {
		email = type === 'admin' ? 'admin@example.com' : 'demo@example.com';
		password = '12345678';
		localError = null;
	}

	function handleClose() {
		authModal.close();
		localError = null;
		if (page.url.pathname === '/login') {
			const target = authModal.redirectUrl && authModal.redirectUrl !== '/login' ? authModal.redirectUrl : '/';
			goto(target);
		}
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!email.trim() || !password) {
			localError = 'Please enter both email and password';
			return;
		}

		localError = null;
		loading = true;

		try {
			const res = await fetch('/api/auth/login', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					email: email.trim(),
					password
				})
			});

			const data = await res.json().catch(() => ({}));

			if (res.ok && data.success) {
				const redirectTarget = authModal.redirectUrl;
				authModal.close();
				email = '';
				password = '';
				localError = null;

				if (redirectTarget && redirectTarget !== '/login') {
					await goto(redirectTarget);
				} else if (page.url.pathname === '/login') {
					await goto('/dashboard');
				} else {
					await invalidateAll();
				}
			} else {
				localError = data.error || 'Invalid email or password. Please try again.';
			}
		} catch {
			localError = 'Login failed. Please check network connection.';
		} finally {
			loading = false;
		}
	}

	async function handleQuickLogin(role: 'admin' | 'demo') {
		if (!isDemoEnabled) return;
		quickLoading = role;
		localError = null;

		try {
			const res = await fetch(`/api/auth/demo?role=${role}`, {
				method: 'POST'
			});

			const data = await res.json().catch(() => ({}));

			if (res.ok && data.success) {
				const redirectTarget = authModal.redirectUrl;
				authModal.close();
				email = '';
				password = '';
				localError = null;

				if (redirectTarget && redirectTarget !== '/login') {
					await goto(redirectTarget);
				} else if (page.url.pathname === '/login') {
					await goto('/dashboard');
				} else {
					await invalidateAll();
				}
			} else {
				localError = data.error || 'Quick login failed.';
			}
		} catch {
			localError = 'Quick login failed. Please try again.';
		} finally {
			quickLoading = null;
		}
	}
</script>

<svelte:window
	onkeydown={(e) => {
		if (authModal.isOpen && e.key === 'Escape') {
			handleClose();
		}
	}}
/>

{#if authModal.isOpen}
	<!-- Fixed Fullscreen Modal Backdrop -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/70 backdrop-blur-md transition-all duration-200"
		role="dialog"
		aria-modal="true"
		aria-labelledby="login-modal-title"
	>
		<!-- Overlay Backdrop Click Area -->
		<div
			class="fixed inset-0"
			onclick={handleClose}
			role="button"
			tabindex="-1"
			aria-label="Close dialog"
			onkeydown={(e) => {
				if (e.key === 'Escape') handleClose();
			}}
		></div>

		<!-- Modal Dialog Box -->
		<div
			class="relative z-10 w-full max-w-md max-h-[92vh] overflow-y-auto rounded-3xl border border-slate-200/80 bg-white/95 p-6 shadow-2xl backdrop-blur-2xl sm:p-8 dark:border-slate-800/80 dark:bg-slate-900/95 text-slate-900 dark:text-slate-100"
		>
			<!-- Ambient Background Glows -->
			<div
				class="pointer-events-none absolute -top-16 -left-16 h-36 w-36 rounded-full bg-indigo-500/20 blur-3xl"
			></div>
			<div
				class="pointer-events-none absolute -bottom-16 -right-16 h-36 w-36 rounded-full bg-purple-500/20 blur-3xl"
			></div>

			<!-- Top Bar: Close Button -->
			<button
				type="button"
				onclick={handleClose}
				class="absolute top-4 right-4 z-20 flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-slate-500 transition-colors hover:bg-slate-200 hover:text-slate-800 dark:bg-slate-800/80 dark:text-slate-400 dark:hover:bg-slate-700 dark:hover:text-slate-100 cursor-pointer"
				aria-label="Close dialog"
			>
				<X class="h-4 w-4" />
			</button>

			<!-- Header -->
			<div class="mb-5 text-center">
				<div
					class="mb-3 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-tr from-indigo-600 to-purple-600 text-white shadow-lg shadow-indigo-500/30 font-black text-xl"
				>
					S
				</div>
				<h2
					id="login-modal-title"
					class="text-2xl font-black tracking-tight text-slate-900 dark:text-white"
				>
					Welcome Back
				</h2>
				<p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
					Sign in to your account or use 1-click demo access
				</p>
			</div>

			<!-- 1-Click Demo & Admin Quick Accounts Banner -->
			{#if isDemoEnabled}
				<div
					class="mb-5 space-y-3 rounded-2xl border border-indigo-200/70 bg-indigo-50/70 p-4 dark:border-indigo-900/60 dark:bg-indigo-950/40"
				>
					<div class="flex items-center justify-between">
						<div class="flex items-center gap-1.5">
							<Key class="h-3.5 w-3.5 text-indigo-600 dark:text-indigo-400" />
							<span class="text-xs font-bold text-indigo-900 dark:text-indigo-200"
								>Demo Accounts</span
							>
						</div>
						<span class="font-mono text-[11px] text-slate-500 dark:text-slate-400"
							>pass: 12345678</span
						>
					</div>

					<div class="flex flex-wrap items-center gap-2">
						<button
							type="button"
							onclick={() => handleQuickLogin('admin')}
							disabled={quickLoading !== null}
							class="flex cursor-pointer items-center gap-1.5 rounded-xl border border-purple-300 bg-purple-100/80 px-3 py-1.5 text-xs font-bold text-purple-700 shadow-xs transition hover:bg-purple-200 disabled:opacity-50 dark:border-purple-800 dark:bg-purple-950/70 dark:text-purple-300"
							title="1-Click Login as Admin"
						>
							{#if quickLoading === 'admin'}
								<span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-purple-700 border-t-transparent"></span>
							{:else}
								<span>⚡ 1-Click Admin</span>
							{/if}
							<span class="rounded-md bg-purple-600 px-1.5 py-0.5 text-[9px] font-extrabold text-white">ADMIN</span>
						</button>

						<button
							type="button"
							onclick={() => handleQuickLogin('demo')}
							disabled={quickLoading !== null}
							class="flex cursor-pointer items-center gap-1.5 rounded-xl border border-indigo-200 bg-white px-3 py-1.5 text-xs font-bold text-indigo-700 shadow-xs transition hover:bg-slate-50 disabled:opacity-50 dark:border-indigo-800 dark:bg-slate-800 dark:text-indigo-300"
							title="1-Click Login as Demo"
						>
							{#if quickLoading === 'demo'}
								<span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-indigo-700 border-t-transparent"></span>
							{:else}
								<span>⚡ 1-Click Demo</span>
							{/if}
							<span class="rounded-md bg-indigo-600 px-1.5 py-0.5 text-[9px] font-extrabold text-white">USER</span>
						</button>
					</div>

					<div class="flex items-center gap-2 text-[11px] text-slate-500 dark:text-slate-400">
						<span>Auto-fill:</span>
						<button
							type="button"
							onclick={() => fillAccount('admin')}
							class="cursor-pointer font-mono font-bold text-purple-600 hover:underline dark:text-purple-400"
						>
							admin@example.com
						</button>
						<span>•</span>
						<button
							type="button"
							onclick={() => fillAccount('demo')}
							class="cursor-pointer font-mono font-bold text-indigo-600 hover:underline dark:text-indigo-400"
						>
							demo@example.com
						</button>
					</div>
				</div>
			{/if}

			<!-- Error Alert -->
			{#if activeError}
				<div
					class="mb-4 flex items-start gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-xs font-semibold text-rose-600 dark:border-rose-900/60 dark:bg-rose-950/40 dark:text-rose-400"
				>
					<AlertCircle class="h-4 w-4 shrink-0 mt-0.5" />
					<span>{activeError}</span>
				</div>
			{/if}

			<!-- Standard Login Form -->
			<form onsubmit={handleSubmit} class="space-y-4">
				<div>
					<label
						for="modal-email"
						class="block mb-1 text-xs font-semibold tracking-wider text-slate-700 uppercase dark:text-slate-300"
					>
						Email Address
					</label>
					<input
						id="modal-email"
						type="email"
						bind:value={email}
						placeholder="admin@example.com or demo@example.com"
						required
						class="flex h-11 w-full rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-sm transition-colors placeholder:text-slate-400 focus:border-indigo-500 focus:outline-hidden focus:ring-2 focus:ring-indigo-500/20 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100"
					/>
				</div>

				<div>
					<div class="mb-1 flex items-center justify-between">
						<label
							for="modal-password"
							class="text-xs font-semibold tracking-wider text-slate-700 uppercase dark:text-slate-300"
						>
							Password
						</label>
						<a
							href="/demo"
							onclick={handleClose}
							class="text-xs font-medium text-indigo-600 hover:underline dark:text-indigo-400"
						>
							1-Click Demo Link
						</a>
					</div>
					<div class="relative">
						<input
							id="modal-password"
							type={showPassword ? 'text' : 'password'}
							bind:value={password}
							placeholder="••••••••"
							required
							class="flex h-11 w-full rounded-xl border border-slate-200 bg-white px-3.5 py-2 pr-10 text-sm transition-colors placeholder:text-slate-400 focus:border-indigo-500 focus:outline-hidden focus:ring-2 focus:ring-indigo-500/20 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100"
						/>
						<button
							type="button"
							onclick={() => (showPassword = !showPassword)}
							class="absolute inset-y-0 right-0 flex items-center pr-3 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
							aria-label={showPassword ? 'Hide password' : 'Show password'}
						>
							{#if showPassword}
								<EyeOff class="h-4 w-4" />
							{:else}
								<Eye class="h-4 w-4" />
							{/if}
						</button>
					</div>
				</div>

				<button
					type="submit"
					disabled={loading}
					class="w-full h-11 rounded-xl bg-indigo-600 text-white font-bold shadow-lg shadow-indigo-500/25 hover:bg-indigo-700 transition flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
				>
					{#if loading}
						<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
						<span>Signing In...</span>
					{:else}
						<span>Sign In with Password</span>
						<ArrowRight class="h-4 w-4" />
					{/if}
				</button>
			</form>

			<!-- OpenID Social Login -->
			<div class="relative my-5 text-center">
				<div class="absolute inset-0 flex items-center">
					<div class="w-full border-t border-slate-200 dark:border-slate-800"></div>
				</div>
				<span
					class="relative bg-white px-3 text-[11px] font-bold tracking-wider text-slate-400 uppercase dark:bg-slate-900"
				>
					Or Continue with OpenID
				</span>
			</div>

			<div class="grid grid-cols-2 gap-3">
				<a
					href="/demo"
					class="flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-xs font-bold text-slate-800 shadow-xs transition-colors hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700"
				>
					<svg class="h-4 w-4" viewBox="0 0 24 24">
						<path
							fill="#4285F4"
							d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
						/>
						<path
							fill="#34A853"
							d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
						/>
						<path
							fill="#FBBC05"
							d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
						/>
						<path
							fill="#EA4335"
							d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
						/>
					</svg>
					<span>Google</span>
				</a>

				<a
					href="/demo"
					class="flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-xs font-bold text-slate-800 shadow-xs transition-colors hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700"
				>
					<svg class="h-4 w-4 fill-[#1877F2]" viewBox="0 0 24 24">
						<path
							d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"
						/>
					</svg>
					<span>Facebook</span>
				</a>
			</div>

			<!-- Footer Link -->
			<p class="mt-5 text-center text-xs text-slate-500 dark:text-slate-400">
				Don't have an account?
				<a
					href="/register"
					onclick={handleClose}
					class="font-bold text-indigo-600 hover:underline dark:text-indigo-400"
				>
					Sign Up Free
				</a>
			</p>

			<!-- Security Badge -->
			<div class="mt-4 flex items-center justify-center gap-1.5 text-[11px] font-medium text-slate-400">
				<ShieldCheck class="h-3.5 w-3.5 text-emerald-500" />
				<span>Secure Argon2 / SHA-256 Authentication</span>
			</div>
		</div>
	</div>
{/if}
