<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLButtonAttributes } from 'svelte/elements';
	import { cn } from '$utils/cn.js';

	interface Props extends HTMLButtonAttributes {
		variant?: 'primary' | 'secondary' | 'outline' | 'danger' | 'ghost';
		size?: 'sm' | 'md' | 'lg';
		children?: Snippet;
		class?: string;
	}

	let {
		variant = 'primary',
		size = 'md',
		class: className = '',
		children,
		...restProps
	}: Props = $props();

	const variantStyles = {
		primary: 'bg-indigo-600 text-white hover:bg-indigo-700 shadow-sm focus-visible:ring-indigo-500',
		secondary: 'bg-slate-800 text-white hover:bg-slate-900 shadow-sm focus-visible:ring-slate-700',
		outline: 'border border-slate-300 text-slate-700 hover:bg-slate-50 focus-visible:ring-slate-400 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800',
		danger: 'bg-rose-600 text-white hover:bg-rose-700 shadow-sm focus-visible:ring-rose-500',
		ghost: 'text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-800'
	};

	const sizeStyles = {
		sm: 'px-3 py-1.5 text-xs font-medium rounded-md',
		md: 'px-4 py-2 text-sm font-medium rounded-lg',
		lg: 'px-5 py-2.5 text-base font-medium rounded-xl'
	};
</script>

<button
	class={cn(
		'inline-flex items-center justify-center transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none cursor-pointer',
		variantStyles[variant],
		sizeStyles[size],
		className
	)}
	{...restProps}
>
	{@render children?.()}
</button>
