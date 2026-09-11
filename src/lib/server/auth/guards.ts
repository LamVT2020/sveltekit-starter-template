import { redirect } from '@sveltejs/kit';
import { UnauthorizedError, ForbiddenError } from '../core/errors/index.js';

export interface AuthLocals {
	user?: {
		id: string;
		name?: string | null;
		email: string;
		role: string;
		image?: string | null;
	} | null;
	session?: {
		id: string;
		sessionToken: string;
		userId: string;
		expiresAt: Date;
	} | null;
}

/**
 * Requires an authenticated user session, otherwise redirects to /login or throws
 */
export function requireUser(locals: AuthLocals, redirectUrl: string = '/login') {
	if (!locals.user) {
		if (redirectUrl) {
			throw redirect(303, redirectUrl);
		}
		throw new UnauthorizedError('You must be signed in to access this resource.');
	}
	return locals.user;
}

/**
 * Requires a specific role (e.g. ADMIN), otherwise redirects or throws 403 Forbidden
 */
export function requireRole(locals: AuthLocals, role: string, redirectUrl: string = '/dashboard') {
	const user = requireUser(locals);
	if (user.role.toUpperCase() !== role.toUpperCase()) {
		if (redirectUrl) {
			throw redirect(303, redirectUrl);
		}
		throw new ForbiddenError(`Access requires ${role} privileges.`);
	}
	return user;
}

export function requireAdmin(locals: AuthLocals, redirectUrl: string = '/dashboard') {
	return requireRole(locals, 'ADMIN', redirectUrl);
}
