# Project Hardening Prompts

Use these prompts for audit, compliance, and production readiness checks.

---

### Prompt: Pre-Production Security & Architecture Audit
```markdown
Run a comprehensive security and architecture audit on this project:
1. Verify all sensitive server logic is confined to `src/lib/server/`.
2. Ensure password hashing uses Bcrypt with at least 12 rounds and NFKC Unicode normalization.
3. Validate that environment variables are strictly schema-checked with Zod in `src/lib/server/core/config/env.ts`.
4. Ensure all database mutations are isolated per user/tenant.
5. Verify that `scripts/deploy.sh` and `scripts/seed-users.ts` run idempotently without data loss.
```
