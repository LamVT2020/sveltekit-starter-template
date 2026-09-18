import { error, redirect, type RequestHandler } from '@sveltejs/kit';
import prisma from '$server/db/client.js';
import { hashPassword } from '$server/auth/password.js';
import { createSession } from '$server/auth/session.js';

export const GET: RequestHandler = async ({ request, url, cookies, getClientAddress }) => {
	const isDemoEnabled = (process.env.ENABLE_DEMO_LOGIN ?? 'true').toLowerCase() === 'true';
	if (!isDemoEnabled) {
		throw error(403, 'Demo login is disabled');
	}

	const roleParam = (url.searchParams.get('role') || 'user').toLowerCase();
	const isAdmin = roleParam === 'admin';

	const targetEmail = isAdmin ? 'admin@example.com' : 'demo@example.com';
	const targetRole = isAdmin ? 'ADMIN' : 'USER';
	const targetName = isAdmin ? 'Administrator' : 'Demo User';

	let user = await prisma.user.findUnique({
		where: { email: targetEmail }
	});

	if (!user) {
		const passwordHash = await hashPassword('12345678');
		user = await prisma.user.create({
			data: {
				email: targetEmail,
				name: targetName,
				role: targetRole,
				passwordHash,
				isActive: true
			}
		});
	}

	const userAgent = request.headers.get('user-agent') || undefined;
	const ipAddress = getClientAddress();

	const session = await createSession(user.id, { ipAddress, userAgent });

	cookies.set('session_token', session.sessionToken, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		secure: process.env.NODE_ENV === 'production',
		maxAge: 30 * 24 * 60 * 60
	});

	const target = url.searchParams.get('redirect') || '/dashboard';
	throw redirect(303, target === '/login' ? '/dashboard' : target);
};

export const POST: RequestHandler = GET;
