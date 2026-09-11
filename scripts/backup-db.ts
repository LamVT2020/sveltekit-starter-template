import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';

dotenv.config();

const backupDir = process.env.BACKUP_DIR || './backups';
const retentionDays = parseInt(process.env.BACKUP_RETENTION_DAYS || '30', 10);

async function runBackup() {
	const now = new Date();
	const yyyymmdd = now.toISOString().slice(0, 10).replace(/-/g, '');
	const hhmmss = now.toTimeString().slice(0, 8).replace(/:/g, '');
	const timestamp = `${yyyymmdd}-${hhmmss}`;

	if (!fs.existsSync(backupDir)) {
		fs.mkdirSync(backupDir, { recursive: true });
	}

	const backupFilePath = path.resolve(backupDir, `backup-app-${timestamp}.db`);

	console.log(`[Backup] Initiating SQLite VACUUM INTO backup...`);
	console.log(`[Backup] Destination: ${backupFilePath}`);

	const prisma = new PrismaClient();

	try {
		await prisma.$executeRawUnsafe(`VACUUM INTO "${backupFilePath}";`);
		console.log(`[Backup] VACUUM INTO completed successfully.`);

		const stats = fs.statSync(backupFilePath);
		console.log(`[Backup] Created backup size: ${(stats.size / 1024).toFixed(2)} KB`);

		const files = fs.readdirSync(backupDir);
		const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;

		let prunedCount = 0;
		for (const file of files) {
			if (file.startsWith('backup-app-') && file.endsWith('.db')) {
				const fullPath = path.join(backupDir, file);
				const fileStat = fs.statSync(fullPath);
				if (fileStat.mtimeMs < cutoff) {
					fs.unlinkSync(fullPath);
					prunedCount++;
					console.log(`[Backup] Pruned expired backup: ${file}`);
				}
			}
		}
		if (prunedCount > 0) {
			console.log(`[Backup] Cleaned up ${prunedCount} old backups.`);
		}
	} catch (error) {
		console.error('[Backup] Backup failed:', error);
		process.exit(1);
	} finally {
		await prisma.$disconnect();
	}
}

runBackup();
