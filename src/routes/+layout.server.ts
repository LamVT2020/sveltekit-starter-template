import type { LayoutServerLoad } from './$types.js';

export const load: LayoutServerLoad = async ({ locals }) => {
	const enableDemoLogin = (process.env.ENABLE_DEMO_LOGIN ?? 'true').toLowerCase() === 'true';

	return {
		user: locals.user,
		enableDemoLogin
	};
};
