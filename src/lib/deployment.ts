import { version } from '$app/environment';

/**
 * SvelteKit generates this version once per build and shares it between the
 * loaded client and server bundle.
 */
export const APP_BUILD_ID = version;

export const SUPPRESSION_DURATION_MS = 30 * 60 * 1000; // 30 minutes
export const STORAGE_KEY_DISMISSED = 'starter_template_deployment_notification_suppressed';

export interface SuppressionRecord {
  version: string;
  dismissedAt: number;
}

let inMemoryRecord: SuppressionRecord | null = null;

/**
 * Resets in-memory suppression record (primarily for testing).
 */
export function resetInMemorySuppression(): void {
  inMemoryRecord = null;
}

/**
 * Checks whether the prompt is currently suppressed for a given version.
 * - Suppressed for 30 minutes for the SAME detected version.
 * - If an even newer version is detected, returns false immediately.
 */
export function isPromptSuppressed(
  detectedVersion: string,
  suppressionRecord: SuppressionRecord | null,
  now: number = Date.now(),
  durationMs: number = SUPPRESSION_DURATION_MS
): boolean {
  if (!suppressionRecord || !suppressionRecord.version) {
    return false;
  }
  // If an even newer (or different) version is detected, do not suppress
  if (suppressionRecord.version !== detectedVersion) {
    return false;
  }
  // Check if within 30-minute window
  return now - suppressionRecord.dismissedAt < durationMs;
}

/**
 * Evaluates whether the new deployment prompt should be shown.
 * - If server version matches current loaded build: returns false (baseline established).
 * - If server version is invalid/empty: returns false.
 * - If server version is suppressed: returns false.
 * - Otherwise: returns true.
 */
export function shouldShowDeploymentPrompt({
  currentBuildId,
  serverBuildId,
  suppressionRecord,
  now = Date.now(),
  durationMs = SUPPRESSION_DURATION_MS
}: {
  currentBuildId: string;
  serverBuildId: string | null | undefined;
  suppressionRecord: SuppressionRecord | null;
  now?: number;
  durationMs?: number;
}): boolean {
  if (!serverBuildId || typeof serverBuildId !== 'string' || serverBuildId.trim() === '') {
    return false;
  }

  // Same build: no prompt
  if (serverBuildId === currentBuildId) {
    return false;
  }

  // Different build: check suppression
  if (isPromptSuppressed(serverBuildId, suppressionRecord, now, durationMs)) {
    return false;
  }

  return true;
}

/**
 * Retrieves the suppression record from storage or in-memory fallback.
 * Safe for SSR and resilient against storage exceptions.
 */
export function getSuppressionRecord(storage?: Storage): SuppressionRecord | null {
  try {
    const store = storage || (typeof window !== 'undefined' ? window.localStorage : undefined);
    if (!store) return inMemoryRecord;
    const raw = store.getItem(STORAGE_KEY_DISMISSED);
    if (!raw) return inMemoryRecord;
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.version === 'string' && typeof parsed.dismissedAt === 'number') {
      return parsed;
    }
    return inMemoryRecord;
  } catch {
    return inMemoryRecord;
  }
}

/**
 * Saves a suppression record for the specified version.
 * Safe for SSR and resilient against storage exceptions.
 */
export function saveSuppressionRecord(version: string, storage?: Storage, now: number = Date.now()): void {
  const record: SuppressionRecord = { version, dismissedAt: now };
  inMemoryRecord = record;
  try {
    const store = storage || (typeof window !== 'undefined' ? window.localStorage : undefined);
    if (!store) return;
    store.setItem(STORAGE_KEY_DISMISSED, JSON.stringify(record));
  } catch {
    // Silently fall back to inMemoryRecord
  }
}

/**
 * Clears the suppression record from storage and in-memory.
 */
export function clearSuppressionRecord(storage?: Storage): void {
  inMemoryRecord = null;
  try {
    const store = storage || (typeof window !== 'undefined' ? window.localStorage : undefined);
    if (!store) return;
    store.removeItem(STORAGE_KEY_DISMISSED);
  } catch {
    // Silent
  }
}

/**
 * Fetches the current server build version from the version endpoint.
 * - Automatically appends a cache-busting timestamp parameter.
 * - Sends cache: 'no-store' and no-cache headers.
 * - Silently handles network or malformed response failures without throwing.
 */
export async function fetchServerVersion(
  fetchFn: typeof fetch = fetch,
  endpointUrl: string = '/api/version'
): Promise<string | null> {
  try {
    const separator = endpointUrl.includes('?') ? '&' : '?';
    const cacheBustedUrl = `${endpointUrl}${separator}_t=${Date.now()}`;
    const response = await fetchFn(cacheBustedUrl, {
      cache: 'no-store',
      headers: {
        'Cache-Control': 'no-cache',
        Pragma: 'no-cache'
      }
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    if (data && typeof data.version === 'string' && data.version.trim() !== '') {
      return data.version.trim();
    }

    return null;
  } catch {
    // Network or malformed-response failures must be silent and never break the app
    return null;
  }
}
