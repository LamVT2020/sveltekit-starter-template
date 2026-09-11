import crypto from 'node:crypto';
import prisma from '../db/client.js';

const SESSION_EXPIRATION_DAYS = 30;

export async function createSession(
	userId: string,
	meta?: { ipAddress?: string; userAgent?: string }
) {
	const sessionToken = crypto.randomBytes(32).toString('hex');
	const expiresAt = new Date(Date.now() + SESSION_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);

	const session = await prisma.session.create({
		data: {
			sessionToken,
			userId,
			expiresAt,
			ipAddress: meta?.ipAddress,
			userAgent: meta?.userAgent
		},
		include: {
			user: {
				select: {
					id: true,
					name: true,
					email: true,
					role: true,
					image: true,
					isActive: true
				}
			}
		}
	});

	return session;
}

export async function validateSessionToken(token: string) {
	if (!token) return null;

	const session = await prisma.session.findUnique({
		where: { sessionToken: token },
		include: {
			user: {
				select: {
					id: true,
					name: true,
					email: true,
					role: true,
					image: true,
					isActive: true
				}
			}
		}
	});

	if (!session) return null;

	// Check expiration
	if (Date.now() >= session.expiresAt.getTime()) {
		await prisma.session.delete({ where: { id: session.id } }).catch(() => {});
		return null;
	}

	// Check if user is active
	if (!session.user.isActive) {
		return null;
	}

	// Slide expiration if closer than 15 days
	if (Date.now() >= session.expiresAt.getTime() - 15 * 24 * 60 * 60 * 1000) {
		const newExpiresAt = new Date(Date.now() + SESSION_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);
		await prisma.session
			.update({
				where: { id: session.id },
				data: { expiresAt: newExpiresAt }
			})
			.catch(() => {});
	}

	return session;
}

export async function invalidateSession(token: string) {
	if (!token) return;
	await prisma.session.delete({ where: { sessionToken: token } }).catch(() => {});
}

export async function invalidateUserSessions(userId: string) {
	if (!userId) return;
	await prisma.session.deleteMany({ where: { userId } }).catch(() => {});
}
