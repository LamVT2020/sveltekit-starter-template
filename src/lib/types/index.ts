export interface UserDto {
	id: string;
	email: string;
	name: string | null;
	role: 'USER' | 'ADMIN' | string;
	image?: string | null;
	createdAt: Date;
}

export interface ApiResponse<T = unknown> {
	success: boolean;
	data?: T;
	error?: {
		message: string;
		code: string;
		details?: unknown;
	};
}
