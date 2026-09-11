import { redirect, type RequestHandler } from '@sveltejs/kit';
import { invalidateSession } from '$server/auth/session.js';

export const POST: RequestHandler = async ({ cookies }) => {
	const sessionToken = cookies.get('session_token');
	if (sessionToken) {
		await invalidateSession(sessionToken);
		cookies.delete('session_token', { path: '/' });
	}

	throw redirect(303, '/login');
};
