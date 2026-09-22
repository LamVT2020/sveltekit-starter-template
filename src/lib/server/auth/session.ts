import crypto from "node:crypto";
import prisma from "../db/client.js";

const SESSION_EXPIRATION_DAYS = 30;

export async function createSession(
	userId: string,
	meta?: { ipAddress?: string; userAgent?: string },
) {
	const sessionToken = crypto.randomBytes(32).toString("hex");
	const expiresAt = new Date(Date.now() + SESSION_EXPIRATION_DAYS * 24 * 60 * 60 * 1000);

	const session = await prisma.session.create({
		data: {
			sessionToken,
			userId,
			expiresAt,
			ipAddress: meta?.ipAddress,
			userAgent: meta?.userAgent,
		},
		include: {
			user: {
				select: {
					id: true,
					name: true,
					email: true,
					role: true,
					image: true,
					isActive: true,
				},
			},
		},
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
					isActive: true,
				},
			},
		},
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
				data: { expiresAt: newExpiresAt },
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

export function isCookieSecure(event?: { url?: URL; request?: Request }): boolean {
	if (process.env.COOKIE_SECURE === "true") return true;
	if (process.env.COOKIE_SECURE === "false") return false;

	const allowInsecure = (process.env.ALLOW_INSECURE_HTTP || "").trim().toLowerCase() === "true";
	const forwardedProto = event?.request?.headers?.get("x-forwarded-proto")?.toLowerCase();
	const origin = event?.request?.headers?.get("origin")?.toLowerCase() || "";
	const referer = event?.request?.headers?.get("referer")?.toLowerCase() || "";
	const host = event?.request?.headers?.get("host")?.toLowerCase() || event?.url?.host?.toLowerCase() || "";

	if (forwardedProto === "http" || origin.startsWith("http://") || referer.startsWith("http://")) {
		return false;
	}

	if (forwardedProto === "https" || origin.startsWith("https://") || referer.startsWith("https://")) {
		return true;
	}

	if (allowInsecure) {
		return false;
	}

	const configuredOrigin = (process.env.ORIGIN || process.env.PUBLIC_APP_URL || process.env.APP_ORIGIN || "").toLowerCase();
	if (configuredOrigin.startsWith("http://")) {
		return false;
	}
	if (configuredOrigin.startsWith("https://")) {
		return true;
	}

	if (
		host.includes("localhost") ||
		host.includes("127.0.0.1") ||
		/^\d+\.\d+\.\d+\.\d+/.test(host)
	) {
		return false;
	}

	return event?.url?.protocol === "https:";
}

export function getSessionCookieOptions(event?: { url?: URL; request?: Request }) {
	return {
		path: "/",
		httpOnly: true,
		sameSite: "lax" as const,
		secure: isCookieSecure(event),
		maxAge: SESSION_EXPIRATION_DAYS * 24 * 60 * 60,
	};
}

