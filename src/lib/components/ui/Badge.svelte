<script lang="ts">
	import type { Snippet } from 'svelte';
	import { cn } from '$utils/cn.js';

	interface Props {
		variant?: 'default' | 'success' | 'warning' | 'danger' | 'info';
		children?: Snippet;
		class?: string;
	}

	let {
		variant = 'default',
		class: className = '',
		children
	}: Props = $props();

	const variantStyles = {
		default: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300',
		success: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300',
		warning: 'bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300',
		danger: 'bg-rose-100 text-rose-800 dark:bg-rose-950/60 dark:text-rose-300',
		info: 'bg-blue-100 text-blue-800 dark:bg-blue-950/60 dark:text-blue-300'
	};
</script>

<span
	class={cn(
		'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium',
		variantStyles[variant],
		className
	)}
>
	{@render children?.()}
</span>
