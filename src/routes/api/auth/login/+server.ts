import { json, type RequestHandler } from '@sveltejs/kit';
import prisma from '$server/db/client.js';
import { verifyPassword } from '$server/auth/password.js';
import { createSession } from '$server/auth/session.js';

export const POST: RequestHandler = async ({ request, cookies, getClientAddress }) => {
	let body: Record<string, unknown> = {};
	try {
		body = await request.json();
	} catch {
		return json({ success: false, error: 'Invalid JSON payload' }, { status: 400 });
	}

	const email = (body.email as string)?.trim().toLowerCase();
	const password = body.password as string;

	if (!email || !password) {
		return json({ success: false, error: 'Email and password are required' }, { status: 400 });
	}

	const user = await prisma.user.findUnique({
		where: { email }
	});

	if (!user || !user.passwordHash) {
		return json({ success: false, error: 'Invalid email or password' }, { status: 401 });
	}

	if (!user.isActive) {
		return json({ success: false, error: 'Account has been deactivated' }, { status: 403 });
	}

	const isValid = await verifyPassword(password, user.passwordHash);
	if (!isValid) {
		return json({ success: false, error: 'Invalid email or password' }, { status: 401 });
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

	return json({
		success: true,
		user: {
			id: user.id,
			email: user.email,
			name: user.name,
			role: user.role
		}
	});
};
