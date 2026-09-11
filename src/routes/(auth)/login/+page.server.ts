import { fail, redirect, type Actions } from '@sveltejs/kit';
import type { PageServerLoad } from './$types.js';
import prisma from '$server/db/client.js';
import { verifyPassword } from '$server/auth/password.js';
import { createSession } from '$server/auth/session.js';

export const load: PageServerLoad = async ({ locals }) => {
	if (locals.user) {
		throw redirect(303, '/dashboard');
	}
	return {};
};

export const actions: Actions = {
	default: async ({ request, cookies, getClientAddress }) => {
		const data = await request.formData();
		const email = (data.get('email') as string)?.trim().toLowerCase();
		const password = data.get('password') as string;

		if (!email || !password) {
			return fail(400, { email, error: 'Email and password are required' });
		}

		const user = await prisma.user.findUnique({
			where: { email }
		});

		if (!user || !user.passwordHash) {
			return fail(401, { email, error: 'Invalid email or password' });
		}

		if (!user.isActive) {
			return fail(403, { email, error: 'Account has been deactivated' });
		}

		const isValid = await verifyPassword(password, user.passwordHash);
		if (!isValid) {
			return fail(401, { email, error: 'Invalid email or password' });
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

		throw redirect(303, '/dashboard');
	}
};
