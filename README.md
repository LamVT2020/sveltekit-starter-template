# SvelteKit Starter Template

Production-grade canonical starter template for SvelteKit 2 + Svelte 5 (Runes) + Tailwind CSS 4 + Prisma ORM. Standardized across configuration, deployment, authentication, and directory structure to facilitate rapid scaling of N projects.

---

## 🌟 Architecture Highlights

- **SvelteKit 2 + Svelte 5 Runes**: Modern, high-performance reactivity.
- **Tailwind CSS 4**: Next-generation CSS framework with `@tailwindcss/vite`.
- **Standardized Environment (`.env`)**: 5 uniform blocks (`Network`, `Storage/DB`, `Observability`, `Auth`, `AI`).
- **Prisma SQLite / Postgres Ready**: Pre-configured `User`, `Session`, `Account`, `PasswordResetToken`, and `AuditLog` models.
- **Enterprise Password Hashing**: Bcrypt 12 rounds + Unicode NFKC normalization + 72-byte safe slice + legacy fallback.
- **Automated Seeding**: Ready-to-use demo (`demo@example.com` / `12345678`) and admin (`admin@example.com` / `12345678`) accounts.
- **7-Step Deploy Pipeline (`scripts/deploy.sh`)**: Pre-backup, git pull, npm install, schema sync, build, PM2 reload, zero-downtime health check.
- **PM2 Orchestration (`ecosystem.config.cjs`)**: Process management with memory caps and auto-restart.

---

## 📁 Canonical Directory Structure

```
sveltekit-starter-template/
├── .env.example                  # Standardized 5-block environment template
├── ecosystem.config.cjs          # PM2 configuration
├── docs/                         # Architecture documentation & playbooks
│   ├── ARCHITECTURE.md           # Architectural layers specification
│   └── promts/                   # AI prompt templates & engineering runbooks
│       ├── README.md
│       ├── AI_FEATURE_BUILDER_PROMPTS.md
│       └── PROJECT_HARDENING_PROMPTS.md
├── prisma/
│   └── schema.prisma             # User, Session, Account, AuditLog schema
├── scripts/
│   ├── deploy.sh                 # 7-step zero-downtime deployment script
│   ├── seed-users.ts             # Demo & Admin user seeder
│   └── backup-db.ts              # SQLite vacuum backup script
├── src/
│   ├── app.html                  # HTML Shell
│   ├── app.d.ts                  # App.Locals typing (user, session)
│   ├── app.css                   # Tailwind CSS 4 theme setup
│   ├── hooks.server.ts           # Session validation & security headers
│   ├── lib/
│   │   ├── components/           # Reusable UI (ui/, layout/, features/)
│   │   ├── server/               # ⚠️ Server-only code ($lib/server/*)
│   │   │   ├── auth/             # password.ts, session.ts, guards.ts
│   │   │   ├── core/             # config/env.ts, logging/, errors/, http/
│   │   │   ├── db/               # client.ts (Prisma singleton)
│   │   │   └── security/         # rate-limit.ts, sanitization
│   │   ├── types/                # Shared TypeScript types & DTOs
│   │   └── utils/                # Utility functions (cn, formatters)
│   └── routes/
│       ├── (auth)/               # login, register, logout
│       ├── (app)/                # dashboard (authenticated)
│       ├── (admin)/              # admin panel (ADMIN role)
│       └── api/health/           # Health check endpoint
└── tests/
    └── unit/                     # Vitest unit test suite
```

---

## 🚀 Creating a New Project from this Template

When you want to scaffold and initialize a new project:

```bash
# 1. Copy the starter template to your new project directory
cp -r /Users/thanhlam/myProjects/sveltekit-starter-template /Users/thanhlam/myProjects/my-new-project
cd /Users/thanhlam/myProjects/my-new-project

# 2. Install dependencies & initialize the database
npm install
cp .env.example .env
npm run db:push
npm run seed:users

# 3. Start the development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 🔑 Pre-Seeded Default Accounts

| Role | Email | Password |
| :--- | :--- | :--- |
| **USER** | `demo@example.com` | `12345678` |
| **ADMIN** | `admin@example.com` | `12345678` |

---

## 🧪 Running Tests
```bash
npm test
```

## 🚢 Deployment
```bash
./scripts/deploy.sh
```
