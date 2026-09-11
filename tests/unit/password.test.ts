import { describe, it, expect } from 'vitest';
import {
	hashPassword,
	verifyPassword,
	normalizePassword,
	needsRehash
} from '../../src/lib/server/auth/password.js';

describe('Password Module Standards', () => {
	it('should normalize and hash password with Bcrypt cost factor 12', async () => {
		const password = 'mySecurePassword123!';
		const hash = await hashPassword(password);

		expect(hash).toBeDefined();
		expect(hash.startsWith('$2a$12$') || hash.startsWith('$2b$12$')).toBe(true);

		const isValid = await verifyPassword(password, hash);
		expect(isValid).toBe(true);

		const isInvalid = await verifyPassword('wrongPassword', hash);
		expect(isInvalid).toBe(false);
	});

	it('should normalize NFKC strings correctly and truncate > 72 bytes safely', () => {
		const longPass = 'A'.repeat(100);
		const normalized = normalizePassword(longPass);
		expect(Buffer.from(normalized, 'utf-8').length).toBe(72);
	});

	it('should verify legacy scrypt hash and signal needsRehash', async () => {
		// Mock legacy scrypt: salt:scryptSyncHex
		const crypto = await import('node:crypto');
		const salt = 'testsalt123';
		const scryptHash = crypto.scryptSync('legacyPass123', salt, 64).toString('hex');
		const storedLegacy = `${salt}:${scryptHash}`;

		expect(needsRehash(storedLegacy)).toBe(true);

		const isValid = await verifyPassword('legacyPass123', storedLegacy);
		expect(isValid).toBe(true);

		const isWrong = await verifyPassword('wrong', storedLegacy);
		expect(isWrong).toBe(false);
	});
});
