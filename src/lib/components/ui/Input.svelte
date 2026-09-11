<script lang="ts">
	import type { HTMLInputAttributes } from 'svelte/elements';
	import { cn } from '$utils/cn.js';

	interface Props extends HTMLInputAttributes {
		label?: string;
		error?: string;
		class?: string;
	}

	let {
		label,
		error,
		class: className = '',
		id,
		value = $bindable(),
		...restProps
	}: Props = $props();

	const inputId = $derived(id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined));
</script>

<div class="w-full space-y-1">
	{#if label}
		<label for={inputId} class="block text-sm font-medium text-slate-700 dark:text-slate-300">
			{label}
		</label>
	{/if}
	<input
		id={inputId}
		bind:value
		class={cn(
			'block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder-slate-400 shadow-xs focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:placeholder-slate-500',
			error && 'border-rose-500 focus:border-rose-500 focus:ring-rose-500',
			className
		)}
		{...restProps}
	/>
	{#if error}
		<p class="text-xs text-rose-600 dark:text-rose-400">{error}</p>
	{/if}
</div>
