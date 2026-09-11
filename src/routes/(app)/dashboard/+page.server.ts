import type { PageServerLoad } from './$types.js';
import { requireUser } from '$server/auth/guards.js';

export const load: PageServerLoad = async ({ locals }) => {
	const user = requireUser(locals);
	return {
		user
	};
};
