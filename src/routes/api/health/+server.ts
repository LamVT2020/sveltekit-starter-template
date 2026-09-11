import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types.js';
import prisma from '$server/db/client.js';

export const GET: RequestHandler = async () => {
	let dbStatus = 'disconnected';
	try {
		await prisma.$queryRaw`SELECT 1`;
		dbStatus = 'connected';
	} catch (error) {
		dbStatus = 'error';
	}

	return json({
		status: 'ok',
		timestamp: new Date().toISOString(),
		uptime: process.uptime(),
		database: dbStatus,
		version: '1.0.0'
	});
};
