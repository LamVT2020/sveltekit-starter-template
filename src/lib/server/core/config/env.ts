import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
	NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
	PORT: z.coerce.number().default(3005),
	APP_ORIGIN: z.string().default('http://localhost:3005'),

	DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
	CONFIG_DIR: z.string().optional().default('./configs'),
	DATA_DIR: z.string().default('./data'),
	LOG_DIR: z.string().default('./logs'),
	BACKUP_DIR: z.string().default('./backups'),

	LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
	GOOGLE_ANALYTICS_ID: z.string().optional().default(''),

	AUTH_SECRET: z
		.string()
		.min(16, 'AUTH_SECRET must be at least 16 characters for security')
		.default('starter-template-super-secret-key-32chars'),
	ENABLE_DEMO_LOGIN: z.boolean().default(true),

	AI_PROVIDER: z.string().default('gemini'),
	AI_MODEL: z.string().default('gemini-3.7-flash'),
	GEMINI_API_KEY: z.string().optional().default('')
});

export const env = envSchema.parse({
	NODE_ENV: process.env.NODE_ENV,
	PORT: process.env.PORT,
	APP_ORIGIN: process.env.APP_ORIGIN,
	DATABASE_URL: process.env.DATABASE_URL || 'file:./prisma/dev.db',
	CONFIG_DIR: process.env.CONFIG_DIR,
	DATA_DIR: process.env.DATA_DIR,
	LOG_DIR: process.env.LOG_DIR,
	BACKUP_DIR: process.env.BACKUP_DIR,
	LOG_LEVEL: process.env.LOG_LEVEL,
	GOOGLE_ANALYTICS_ID: process.env.GOOGLE_ANALYTICS_ID || process.env.GA_MEASUREMENT_ID,
	AUTH_SECRET:
		process.env.AUTH_SECRET ||
		process.env.SESSION_SECRET ||
		process.env.APP_SECRET ||
		'starter-template-super-secret-key-32chars',
	ENABLE_DEMO_LOGIN: (process.env.ENABLE_DEMO_LOGIN ?? 'true').toLowerCase() === 'true',
	AI_PROVIDER: process.env.AI_PROVIDER,
	AI_MODEL: process.env.AI_MODEL,
	GEMINI_API_KEY: process.env.GEMINI_API_KEY
});

export type Env = z.infer<typeof envSchema>;
