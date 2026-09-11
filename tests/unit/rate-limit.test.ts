import { describe, it, expect } from 'vitest';
import { checkRateLimit } from '../../src/lib/server/security/rate-limit.js';

describe('Security Rate Limiter', () => {
	it('should allow requests within limit and block when exceeded', () => {
		const key = 'test-ip-123';
		const options = { limit: 3, windowMs: 1000 };

		const res1 = checkRateLimit(key, options);
		expect(res1.allowed).toBe(true);
		expect(res1.remaining).toBe(2);

		const res2 = checkRateLimit(key, options);
		expect(res2.allowed).toBe(true);
		expect(res2.remaining).toBe(1);

		const res3 = checkRateLimit(key, options);
		expect(res3.allowed).toBe(true);
		expect(res3.remaining).toBe(0);

		const res4 = checkRateLimit(key, options);
		expect(res4.allowed).toBe(false);
		expect(res4.remaining).toBe(0);
	});
});
