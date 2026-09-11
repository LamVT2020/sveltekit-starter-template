import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

export const BCRYPT_SALT_ROUNDS = 12;

/**
 * Normalizes password string into Unicode NFKC form and handles safe byte slice
 */
export function normalizePassword(password: string): string {
	const normalized = password.normalize('NFKC');
	const buf = Buffer.from(normalized, 'utf-8');
	if (buf.length > 72) {
		return buf.subarray(0, 72).toString('utf-8');
	}
	return normalized;
}

/**
 * Hashes a plaintext password using Bcrypt with cost factor 12
 */
export async function hashPassword(password: string): Promise<string> {
	if (!password || typeof password !== 'string') {
		throw new Error('Password must be a non-empty string');
	}
	const safePass = normalizePassword(password);
	return bcrypt.hash(safePass, BCRYPT_SALT_ROUNDS);
}

/**
 * Constant-time comparison helper for legacy hash checks
 */
function safeTimingEqual(a: string, b: string): boolean {
	const bufA = Buffer.from(a, 'utf-8');
	const bufB = Buffer.from(b, 'utf-8');
	if (bufA.length !== bufB.length) {
		return false;
	}
	return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Verifies legacy scrypt hash format `salt:hash`
 */
function verifyLegacyScrypt(password: string, storedHash: string): boolean {
	try {
		const [salt, hash] = storedHash.split(':');
		if (!salt || !hash) return false;
		const calculated = crypto.scryptSync(password, salt, 64).toString('hex');
		return safeTimingEqual(calculated, hash);
	} catch {
		return false;
	}
}

/**
 * Verifies a password against Bcrypt hash or legacy formats
 */
export async function verifyPassword(password: string, storedHash: string): Promise<boolean> {
	if (!password || !storedHash) return false;

	// 1. Check Bcrypt ($2a$, $2b$, $2y$)
	if (storedHash.startsWith('$2a$') || storedHash.startsWith('$2b$') || storedHash.startsWith('$2y$')) {
		const safePass = normalizePassword(password);
		return bcrypt.compare(safePass, storedHash);
	}

	// 2. Check legacy scrypt format (salt:hash)
	if (storedHash.includes(':')) {
		return verifyLegacyScrypt(password, storedHash);
	}

	return false;
}

/**
 * Checks if the stored hash needs rehashing (e.g. legacy algorithm or lower cost)
 */
export function needsRehash(storedHash: string): boolean {
	if (!storedHash.startsWith('$2a$') && !storedHash.startsWith('$2b$') && !storedHash.startsWith('$2y$')) {
		return true;
	}
	const parts = storedHash.split('$');
	if (parts.length >= 3) {
		const rounds = parseInt(parts[2], 10);
		if (rounds < BCRYPT_SALT_ROUNDS) return true;
	}
	return false;
}
