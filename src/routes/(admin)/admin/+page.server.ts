import type { PageServerLoad } from './$types.js';
import { requireAdmin } from '$server/auth/guards.js';
import prisma from '$server/db/client.js';

export const load: PageServerLoad = async ({ locals }) => {
	const adminUser = requireAdmin(locals);

	const [totalUsers, activeSessions] = await Promise.all([
		prisma.user.count(),
		prisma.session.count()
	]);

	const recentUsers = await prisma.user.findMany({
		take: 5,
		orderBy: { createdAt: 'desc' },
		select: { id: true, email: true, name: true, role: true, createdAt: true }
	});

	return {
		admin: adminUser,
		stats: {
			totalUsers,
			activeSessions
		},
		recentUsers
	};
};
