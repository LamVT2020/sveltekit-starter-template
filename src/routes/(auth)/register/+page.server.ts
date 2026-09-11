import { fail, redirect, type Actions } from '@sveltejs/kit';
import type { PageServerLoad } from './$types.js';
import prisma from '$server/db/client.js';
import { hashPassword } from '$server/auth/password.js';
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
		const name = (data.get('name') as string)?.trim();
		const email = (data.get('email') as string)?.trim().toLowerCase();
		const password = data.get('password') as string;

		if (!email || !password) {
			return fail(400, { email, name, error: 'Email and password are required' });
		}

		if (password.length < 8) {
			return fail(400, { email, name, error: 'Password must be at least 8 characters long' });
		}

		const existing = await prisma.user.findUnique({
			where: { email }
		});

		if (existing) {
			return fail(400, { email, name, error: 'An account with this email already exists' });
		}

		const passwordHash = await hashPassword(password);

		const user = await prisma.user.create({
			data: {
				email,
				name: name || null,
				passwordHash,
				role: 'USER'
			}
		});

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
