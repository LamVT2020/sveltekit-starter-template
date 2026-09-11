<script lang="ts">
	import type { Snippet } from 'svelte';
	import { cn } from '$utils/cn.js';

	interface Props {
		title?: string;
		description?: string;
		class?: string;
		header?: Snippet;
		children?: Snippet;
		footer?: Snippet;
	}

	let {
		title,
		description,
		class: className = '',
		header,
		children,
		footer
	}: Props = $props();
</script>

<div
	class={cn(
		'rounded-xl border border-slate-200 bg-white p-6 shadow-xs dark:border-slate-800 dark:bg-slate-900',
		className
	)}
>
	{#if header}
		{@render header()}
	{:else if title || description}
		<div class="mb-4">
			{#if title}
				<h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">{title}</h3>
			{/if}
			{#if description}
				<p class="text-sm text-slate-500 dark:text-slate-400">{description}</p>
			{/if}
		</div>
	{/if}

	<div>
		{@render children?.()}
	</div>

	{#if footer}
		<div class="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800">
			{@render footer()}
		</div>
	{/if}
</div>
