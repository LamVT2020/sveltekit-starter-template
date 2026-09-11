import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();

async function main() {
	console.log('[Seed] Seeding standard demo & admin users...');

	const password = '12345678';
	const saltRounds = 12;
	const passwordHash = await bcrypt.hash(password, saltRounds);

	// 1. Upsert Demo User
	const demoUser = await prisma.user.upsert({
		where: { email: 'demo@example.com' },
		update: {
			name: 'Demo User',
			role: 'USER',
			passwordHash,
			isActive: true
		},
		create: {
			email: 'demo@example.com',
			name: 'Demo User',
			role: 'USER',
			passwordHash,
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
			passwordHash,
			isActive: true
		},
		create: {
			email: 'admin@example.com',
			name: 'Administrator',
			role: 'ADMIN',
			passwordHash,
			isActive: true
		}
	});
	console.log(`[Seed] Admin user ready: admin@example.com (Role: ${adminUser.role})`);

	console.log('[Seed] Standard users seeded successfully! Password for both: 12345678');
}

main()
	.catch((e) => {
		console.error('[Seed] Error seeding users:', e);
		process.exit(1);
	})
	.finally(async () => {
		await prisma.$disconnect();
	});
