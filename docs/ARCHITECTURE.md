# Architecture Documentation

## Overview
This project follows a Modular Monolith architecture based on SvelteKit 2, Svelte 5, Tailwind CSS 4, and Prisma ORM.

## Key Layers
1. **Presentation Layer (`src/routes/`, `src/lib/components/`)**
   - Route grouping: `(auth)` for public authentication pages, `(app)` for protected user areas, `(admin)` for administrative dashboards.
   - UI components organized into `ui/` (atoms), `layout/` (navigation), and `features/` (domain-specific components).

2. **Application & Domain Layer (`src/lib/server/`)**
   - Strictly server-side isolated (`$lib/server/*`).
   - `core/config/env.ts`: Centralized, validated environment variables with Zod.
   - `core/logging/`: Structured JSON logging with multiple severity levels.
   - `core/errors/`: Standardized error hierarchy (`AppError`, `UnauthorizedError`, `ForbiddenError`, `NotFoundError`).
   - `auth/`: Bcrypt 12 hashing, session management, and RBAC guards.
   - `db/`: Prisma client singleton with connection pooling.
   - `security/`: Rate limiting and input sanitization.

3. **Operations & Deployment (`scripts/`, `ecosystem.config.cjs`)**
   - Standardized 7-step deployment script (`scripts/deploy.sh`).
   - Pre-deployment automated backups (`scripts/backup-db.ts`).
   - Standard demo and admin user seeding (`scripts/seed-users.ts`).
   - PM2 cluster orchestration.
