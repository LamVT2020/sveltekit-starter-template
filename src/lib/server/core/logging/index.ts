import { env } from '../config/env.js';

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVEL_WEIGHTS: Record<LogLevel, number> = {
	debug: 0,
	info: 1,
	warn: 2,
	error: 3
};

class Logger {
	private currentWeight: number;

	constructor() {
		this.currentWeight = LEVEL_WEIGHTS[env.LOG_LEVEL as LogLevel] ?? 1;
	}

	private log(level: LogLevel, message: string, meta?: Record<string, unknown>) {
		if (LEVEL_WEIGHTS[level] < this.currentWeight) return;

		const payload = {
			timestamp: new Date().toISOString(),
			level: level.toUpperCase(),
			message,
			...(meta ? { meta } : {})
		};

		const line = JSON.stringify(payload);
		if (level === 'error') {
			console.error(line);
		} else if (level === 'warn') {
			console.warn(line);
		} else {
			console.log(line);
		}
	}

	debug(message: string, meta?: Record<string, unknown>) {
		this.log('debug', message, meta);
	}

	info(message: string, meta?: Record<string, unknown>) {
		this.log('info', message, meta);
	}

	warn(message: string, meta?: Record<string, unknown>) {
		this.log('warn', message, meta);
	}

	error(message: string, meta?: Record<string, unknown>) {
		this.log('error', message, meta);
	}
}

export const logger = new Logger();
