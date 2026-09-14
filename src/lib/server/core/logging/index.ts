import fs from 'node:fs';
import path from 'node:path';
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

	private writeToFile(line: string, level: LogLevel, now: Date): void {
		try {
			if (process.env.NODE_ENV === 'test') return;
			const year = now.getFullYear();
			const month = String(now.getMonth() + 1).padStart(2, '0');
			const day = String(now.getDate()).padStart(2, '0');
			const yyyymmdd = `${year}${month}${day}`;

			const baseDir = (env.LOG_DIR || process.env.LOG_DIR || (fs.existsSync('/app/logs') ? '/app/logs' : (fs.existsSync('/home/deploy/logs/starter-template') ? '/home/deploy/logs/starter-template' : './logs'))).trim();
			const targetDir = path.join(baseDir, yyyymmdd);

			if (!fs.existsSync(targetDir)) {
				fs.mkdirSync(targetDir, { recursive: true });
			}

			fs.appendFileSync(path.join(targetDir, 'app.log'), line + '\n');
			if (level === 'error') {
				fs.appendFileSync(path.join(targetDir, 'error.log'), line + '\n');
			}
		} catch {
			// Non-fatal fallback
		}
	}

	private log(level: LogLevel, message: string, meta?: Record<string, unknown>) {
		if (LEVEL_WEIGHTS[level] < this.currentWeight) return;

		const now = new Date();
		const payload = {
			timestamp: now.toISOString(),
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

		this.writeToFile(line, level, now);
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
