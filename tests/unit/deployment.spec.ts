import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { RequestEvent } from '@sveltejs/kit';
import {
  APP_BUILD_ID,
  SUPPRESSION_DURATION_MS,
  isPromptSuppressed,
  shouldShowDeploymentPrompt,
  getSuppressionRecord,
  saveSuppressionRecord,
  clearSuppressionRecord,
  fetchServerVersion
} from '$lib/deployment';
import { GET } from '../../src/routes/api/version/+server';

describe('Deployment Notification - Core Logic', () => {
  const currentBuild = 'build-20261011-v1';
  const serverBuildOld = 'build-20261011-v1';
  const serverBuildNew = 'build-20261011-v2';
  const serverBuildNewer = 'build-20261011-v3';

  beforeEach(() => {
    clearSuppressionRecord();
  });

  describe('APP_BUILD_ID', () => {
    it('is defined and non-empty string', () => {
      expect(typeof APP_BUILD_ID).toBe('string');
      expect(APP_BUILD_ID.trim().length).toBeGreaterThan(0);
    });
  });

  describe('shouldShowDeploymentPrompt', () => {
    it('returns false when server version equals current build (baseline established, no false popup)', () => {
      const result = shouldShowDeploymentPrompt({
        currentBuildId: currentBuild,
        serverBuildId: serverBuildOld,
        suppressionRecord: null
      });
      expect(result).toBe(false);
    });

    it('returns false when server version is null, undefined, or empty (silent on malformed data)', () => {
      expect(
        shouldShowDeploymentPrompt({
          currentBuildId: currentBuild,
          serverBuildId: null,
          suppressionRecord: null
        })
      ).toBe(false);

      expect(
        shouldShowDeploymentPrompt({
          currentBuildId: currentBuild,
          serverBuildId: undefined,
          suppressionRecord: null
        })
      ).toBe(false);

      expect(
        shouldShowDeploymentPrompt({
          currentBuildId: currentBuild,
          serverBuildId: '   ',
          suppressionRecord: null
        })
      ).toBe(false);
    });

    it('returns true when a different build is detected and not suppressed', () => {
      const result = shouldShowDeploymentPrompt({
        currentBuildId: currentBuild,
        serverBuildId: serverBuildNew,
        suppressionRecord: null
      });
      expect(result).toBe(true);
    });

    it('returns false when the same detected version was suppressed within 30 minutes', () => {
      const now = 1000000;
      const suppressionRecord = {
        version: serverBuildNew,
        dismissedAt: now - 10 * 60 * 1000 // 10 minutes ago
      };

      const result = shouldShowDeploymentPrompt({
        currentBuildId: currentBuild,
        serverBuildId: serverBuildNew,
        suppressionRecord,
        now
      });
      expect(result).toBe(false);
    });

    it('returns true when the 30-minute suppression period has elapsed', () => {
      const now = 1000000;
      const suppressionRecord = {
        version: serverBuildNew,
        dismissedAt: now - (SUPPRESSION_DURATION_MS + 1000) // 30 mins + 1 sec ago
      };

      const result = shouldShowDeploymentPrompt({
        currentBuildId: currentBuild,
        serverBuildId: serverBuildNew,
        suppressionRecord,
        now
      });
      expect(result).toBe(true);
    });

    it('returns true immediately if an even newer version is detected despite active suppression of prior version', () => {
      const now = 1000000;
      const suppressionRecord = {
        version: serverBuildNew,
        dismissedAt: now - 5 * 60 * 1000
      };

      const result = shouldShowDeploymentPrompt({
        currentBuildId: currentBuild,
        serverBuildId: serverBuildNewer,
        suppressionRecord,
        now
      });
      expect(result).toBe(true);
    });
  });

  describe('isPromptSuppressed', () => {
    it('returns false when suppression record is null', () => {
      expect(isPromptSuppressed('v2', null)).toBe(false);
    });

    it('returns true for same version within 30 minutes', () => {
      const now = 500000;
      const record = { version: 'v2', dismissedAt: now - 15 * 60 * 1000 };
      expect(isPromptSuppressed('v2', record, now)).toBe(true);
    });

    it('returns false for same version after 30 minutes', () => {
      const now = 500000;
      const record = { version: 'v2', dismissedAt: now - 30 * 60 * 1000 };
      expect(isPromptSuppressed('v2', record, now)).toBe(false);
    });

    it('returns false immediately when detected version is different from suppressed version', () => {
      const now = 500000;
      const record = { version: 'v2', dismissedAt: now - 2 * 60 * 1000 };
      expect(isPromptSuppressed('v3', record, now)).toBe(false);
    });
  });

  describe('Storage persistence & resilience', () => {
    function createMockStorage(): Storage {
      const store: Record<string, string> = {};
      return {
        getItem: vi.fn((key: string) => store[key] ?? null),
        setItem: vi.fn((key: string, value: string) => {
          store[key] = value;
        }),
        removeItem: vi.fn((key: string) => {
          delete store[key];
        }),
        clear: vi.fn(() => {
          Object.keys(store).forEach((k) => delete store[k]);
        }),
        key: vi.fn(),
        length: 0
      };
    }

    it('saves and retrieves suppression record from storage', () => {
      const storage = createMockStorage();
      const now = 123456789;

      saveSuppressionRecord('v-test', storage, now);
      const record = getSuppressionRecord(storage);

      expect(record).toEqual({
        version: 'v-test',
        dismissedAt: now
      });
    });

    it('handles malformed JSON in storage gracefully without throwing', () => {
      const storage = createMockStorage();
      storage.setItem('starter_template_deployment_notification_suppressed', '{ broken json');

      const record = getSuppressionRecord(storage);
      expect(record).toBeNull();
    });

    it('handles storage throwing exceptions gracefully', () => {
      const throwingStorage = {
        getItem: vi.fn(() => {
          throw new Error('SecurityError: access denied');
        }),
        setItem: vi.fn(() => {
          throw new Error('QuotaExceededError');
        }),
        removeItem: vi.fn(() => {
          throw new Error('Storage error');
        }),
        clear: vi.fn(),
        key: vi.fn(),
        length: 0
      } as unknown as Storage;

      expect(() => saveSuppressionRecord('v-throw', throwingStorage)).not.toThrow();
      const record = getSuppressionRecord(throwingStorage);
      expect(record?.version).toBe('v-throw');
    });
  });

  describe('fetchServerVersion', () => {
    it('requests version with cache busting query param and no-store headers', async () => {
      let capturedUrl = '';
      let capturedInit: RequestInit | undefined;

      const mockFetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
        capturedUrl = input.toString();
        capturedInit = init;
        return new Response(JSON.stringify({ version: 'server-build-99' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      });

      const version = await fetchServerVersion(mockFetch as unknown as typeof fetch, '/api/version');

      expect(version).toBe('server-build-99');
      expect(capturedUrl).toContain('/api/version?_t=');
      expect(capturedInit?.cache).toBe('no-store');
      expect((capturedInit?.headers as Record<string, string>)?.['Cache-Control']).toBe('no-cache');
      expect((capturedInit?.headers as Record<string, string>)?.['Pragma']).toBe('no-cache');
    });

    it('returns null silently when fetch rejects (network failure)', async () => {
      const mockFetch = vi.fn(async () => {
        throw new Error('Network error: failed to fetch');
      });

      const version = await fetchServerVersion(mockFetch as unknown as typeof fetch);
      expect(version).toBeNull();
    });

    it('returns null silently on non-200 HTTP response', async () => {
      const mockFetch = vi.fn(async () => {
        return new Response('Internal Server Error', { status: 500 });
      });

      const version = await fetchServerVersion(mockFetch as unknown as typeof fetch);
      expect(version).toBeNull();
    });

    it('returns null silently on malformed JSON or unexpected response payload', async () => {
      const mockFetch = vi.fn(async () => {
        return new Response(JSON.stringify({ message: 'no version field' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      });

      const version = await fetchServerVersion(mockFetch as unknown as typeof fetch);
      expect(version).toBeNull();
    });
  });

  describe('Endpoint /api/version', () => {
    it('returns HTTP 200 with version and no-store cache headers', async () => {
      const response = await GET({} as RequestEvent);

      expect(response.status).toBe(200);

      const cacheControl = response.headers.get('cache-control') || '';
      expect(cacheControl).toContain('no-store');
      expect(cacheControl).toContain('no-cache');
      expect(cacheControl).toContain('must-revalidate');

      const pragma = response.headers.get('pragma') || '';
      expect(pragma).toContain('no-cache');

      const body = await response.json();
      expect(body).toHaveProperty('version');
      expect(body.version).toBe(APP_BUILD_ID);
    });
  });
});
