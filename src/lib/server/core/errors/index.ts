export class AppError extends Error {
	constructor(
		message: string,
		public statusCode: number = 500,
		public code: string = 'INTERNAL_ERROR',
		public details?: unknown
	) {
		super(message);
		this.name = 'AppError';
	}
}

export class UnauthorizedError extends AppError {
	constructor(message: string = 'Authentication required', details?: unknown) {
		super(message, 401, 'UNAUTHORIZED', details);
		this.name = 'UnauthorizedError';
	}
}

export class ForbiddenError extends AppError {
	constructor(message: string = 'Insufficient permissions', details?: unknown) {
		super(message, 403, 'FORBIDDEN', details);
		this.name = 'ForbiddenError';
	}
}

export class NotFoundError extends AppError {
	constructor(message: string = 'Resource not found', details?: unknown) {
		super(message, 404, 'NOT_FOUND', details);
		this.name = 'NotFoundError';
	}
}

export class ValidationError extends AppError {
	constructor(message: string = 'Invalid input provided', details?: unknown) {
		super(message, 400, 'VALIDATION_ERROR', details);
		this.name = 'ValidationError';
	}
}
