import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';

dotenv.config();

const possibleEnvPaths = [
	process.env.ENV_FILE,
	process.env.CONFIG_DIR ? `${process.env.CONFIG_DIR}/.env` : null,
	path.resolve(process.cwd(), '.env'),
	'/home/deploy/configs/starter-template/.env',
	'/home/deploy/configs/starter-template.env',
	'/home/deploy/configs/.env',
	'/home/deploy/config/starter-template/.env',
	'/home/deploy/config/starter-template.env',
	'/home/deploy/config/.env'
].filter(Boolean) as string[];

for (const p of possibleEnvPaths) {
	if (fs.existsSync(p)) {
		try {
			const content = fs.readFileSync(p, 'utf8');
			const lines = content.split('\n');
			for (const line of lines) {
				const match = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)?\s*$/);
				if (match) {
					let val = (match[2] || '').trim();
					if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
						val = val.slice(1, -1);
					} else {
						val = val.replace(/\s*#.*$/, '').trim();
					}
					if (process.env[match[1]] === undefined) {
						process.env[match[1]] = val;
					}
				}
			}
		} catch {}
		break;
	}
}

const prisma = new PrismaClient();

async function main() {
	console.log('[Seed] Seeding standard demo & admin users...');

	const defaultPasswordHash = await bcrypt.hash('12345678', 12);
	const lamvtPasswordHash = await bcrypt.hash('09061990Lk!', 12);

	// 1. Upsert Demo User
	const demoUser = await prisma.user.upsert({
		where: { email: 'demo@example.com' },
		update: {
			name: 'Demo User',
			role: 'USER',
			passwordHash: defaultPasswordHash,
			isActive: true
		},
		create: {
			email: 'demo@example.com',
			name: 'Demo User',
			role: 'USER',
			passwordHash: defaultPasswordHash,
			isActive: true
		}
	});
	console.log(`[Seed] Demo user ready: demo@example.com (Role: ${demoUser.role})`);

	// 2. Upsert Admin User
	const adminUser = await prisma.user.upsert({
		where: { email: 'admin@example.com' },
		update: {
			name: 'Administrator',
			role: 'ADMIN',
			passwordHash: defaultPasswordHash,
			isActive: true
		},
		create: {
			email: 'admin@example.com',
			name: 'Administrator',
			role: 'ADMIN',
			passwordHash: defaultPasswordHash,
			isActive: true
		}
	});
	console.log(`[Seed] Admin user ready: admin@example.com (Role: ${adminUser.role})`);

	// 3. Upsert LamVT Admin Users
	for (const email of ['lamvt@example.com', 'lamvt@binaheimdall.com']) {
		await prisma.user.upsert({
			where: { email },
			update: {
				name: 'Lam VT',
				role: 'ADMIN',
				passwordHash: lamvtPasswordHash,
				isActive: true
			},
			create: {
				email,
				name: 'Lam VT',
				role: 'ADMIN',
				passwordHash: lamvtPasswordHash,
				isActive: true
			}
		});
		console.log(`[Seed] LamVT user ready: ${email} (Role: ADMIN)`);
	}

	console.log('[Seed] Standard users seeded successfully!');
}

main()
	.catch((e) => {
		console.error('[Seed] Error seeding users:', e);
		process.exit(1);
	})
	.finally(async () => {
		await prisma.$disconnect();
	});
