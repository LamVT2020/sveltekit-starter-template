import { describe, it, expect } from 'vitest';
import { env } from '../../src/lib/server/core/config/env.js';

describe('Standardized Env Module', () => {
	it('should load default port, node_env, and app_origin correctly', () => {
		expect(env.NODE_ENV).toBeDefined();
		expect(typeof env.PORT).toBe('number');
		expect(env.APP_ORIGIN).toBeDefined();
	});

	it('should provide standardized storage directories', () => {
		expect(env.DATA_DIR).toBeDefined();
		expect(env.LOG_DIR).toBeDefined();
		expect(env.BACKUP_DIR).toBeDefined();
	});

	it('should provide auth secret with minimum security requirements', () => {
		expect(env.AUTH_SECRET).toBeDefined();
		expect(env.AUTH_SECRET.length).toBeGreaterThanOrEqual(16);
	});
});
