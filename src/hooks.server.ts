import type { Handle } from '@sveltejs/kit';
import { validateSessionToken } from '$server/auth/session.js';

export const handle: Handle = async ({ event, resolve }) => {
	const sessionToken = event.cookies.get('session_token');

	if (!sessionToken) {
		event.locals.user = null;
		event.locals.session = null;
	} else {
		const session = await validateSessionToken(sessionToken);
		if (session) {
			event.locals.user = session.user;
			event.locals.session = {
				id: session.id,
				sessionToken: session.sessionToken,
				userId: session.userId,
				expiresAt: session.expiresAt
			};
		} else {
			event.locals.user = null;
			event.locals.session = null;
			event.cookies.delete('session_token', { path: '/' });
		}
	}

	const response = await resolve(event);

	// Production security headers
	response.headers.set('X-Content-Type-Options', 'nosniff');
	response.headers.set('X-Frame-Options', 'DENY');
	response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');

	return response;
};
