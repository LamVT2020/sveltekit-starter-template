<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import {
    APP_BUILD_ID,
    fetchServerVersion,
    shouldShowDeploymentPrompt,
    saveSuppressionRecord,
    getSuppressionRecord
  } from '$lib/deployment.js';

  interface Props {
    currentBuildId?: string;
    endpoint?: string;
    pollIntervalMs?: number;
  }

  let {
    currentBuildId = APP_BUILD_ID,
    endpoint = '/api/version',
    pollIntervalMs = 60000
  }: Props = $props();

  let showModal = $state(false);
  let detectedVersion = $state<string | null>(null);

  async function checkVersion() {
    if (!browser) return;
    try {
      const serverVersion = await fetchServerVersion(window.fetch, endpoint);
      if (!serverVersion) return;

      const record = getSuppressionRecord();
      const shouldShow = shouldShowDeploymentPrompt({
        currentBuildId,
        serverBuildId: serverVersion,
        suppressionRecord: record
      });

      if (shouldShow) {
        detectedVersion = serverVersion;
        showModal = true;
      } else {
        showModal = false;
      }
    } catch {
      // Network or malformed response failures must be silent
    }
  }

  function handleReload() {
    if (browser && typeof window !== 'undefined') {
      window.location.reload();
    }
  }

  function handleLater() {
    if (detectedVersion) {
      saveSuppressionRecord(detectedVersion);
    }
    showModal = false;
  }

  onMount(() => {
    checkVersion();

    const intervalId = setInterval(checkVersion, pollIntervalMs);

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        checkVersion();
      }
    };

    const handleFocus = () => {
      checkVersion();
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(intervalId);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('focus', handleFocus);
    };
  });
</script>

{#if showModal}
  <div
    role="dialog"
    aria-live="polite"
    aria-label="New version available"
    class="pointer-events-auto fixed right-6 bottom-6 z-[9999] w-[calc(100vw-3rem)] max-w-sm rounded-xl border border-gray-200 bg-white p-4 shadow-2xl transition-all duration-200 sm:w-96 dark:border-gray-700 dark:bg-gray-800"
  >
    <div class="flex items-start gap-3">
      <div class="mt-0.5 flex-shrink-0">
        <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-blue-100 text-blue-600 dark:bg-blue-900/50 dark:text-blue-400">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </div>
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm leading-snug font-semibold text-gray-900 dark:text-white">A new version is available. Reload to update.</p>
        <div class="mt-3 flex items-center gap-2">
          <button
            type="button"
            class="px-3 py-1.5 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg focus:ring-2 focus:ring-blue-300 dark:bg-blue-500 dark:hover:bg-blue-600 focus:outline-none transition-colors"
            onclick={handleReload}
          >
            Reload
          </button>
          <button
            type="button"
            class="px-3 py-1.5 text-xs font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg focus:ring-2 focus:ring-gray-300 dark:text-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 focus:outline-none transition-colors"
            onclick={handleLater}
          >
            Later
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
