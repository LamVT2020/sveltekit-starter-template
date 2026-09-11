interface RateLimitRecord {
	count: number;
	resetAt: number;
}

const memoryStore = new Map<string, RateLimitRecord>();

export interface RateLimitOptions {
	limit?: number;
	windowMs?: number;
}

export function checkRateLimit(
	key: string,
	options: RateLimitOptions = {}
): { allowed: boolean; remaining: number; resetAt: number } {
	const limit = options.limit || 60;
	const windowMs = options.windowMs || 60 * 1000;
	const now = Date.now();

	const record = memoryStore.get(key);

	if (!record || now > record.resetAt) {
		const resetAt = now + windowMs;
		memoryStore.set(key, { count: 1, resetAt });
		return { allowed: true, remaining: limit - 1, resetAt };
	}

	if (record.count >= limit) {
		return { allowed: false, remaining: 0, resetAt: record.resetAt };
	}

	record.count += 1;
	return { allowed: true, remaining: limit - record.count, resetAt: record.resetAt };
}
