import { json } from '@sveltejs/kit';
import { AppError } from '../errors/index.js';

export function jsonOk<T>(data: T, status: number = 200) {
	return json(
		{
			success: true,
			data
		},
		{ status }
	);
}

export function jsonError(error: unknown) {
	if (error instanceof AppError) {
		return json(
			{
				success: false,
				error: {
					message: error.message,
					code: error.code,
					details: error.details
				}
			},
			{ status: error.statusCode }
		);
	}

	const message = error instanceof Error ? error.message : 'Unknown server error';
	return json(
		{
			success: false,
			error: {
				message,
				code: 'INTERNAL_SERVER_ERROR'
			}
		},
		{ status: 500 }
	);
}
