declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			user: {
				id: string;
				email: string;
				name: string | null;
				role: string;
				image: string | null;
			} | null;
			session: {
				id: string;
				sessionToken: string;
				userId: string;
				expiresAt: Date;
			} | null;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
