# Feature Builder Prompts

Use these prompt templates when requesting AI assistants to implement new business modules in this project.

---

### Prompt 1: New Domain Feature Scaffold
```markdown
Please implement a new domain feature `<FEATURE_NAME>` following our canonical SvelteKit architecture:
1. Schema: Add Prisma models in `prisma/schema.prisma` with appropriate relationships to `User`.
2. Service: Create `src/lib/server/modules/<FEATURE_NAME>/service.ts` with business logic and transactional safety.
3. API / Route: Create `src/routes/(app)/<FEATURE_NAME>/` with `+page.server.ts` enforcing `requireUser(locals)`.
4. UI: Build Svelte 5 runes components in `src/lib/components/features/<FEATURE_NAME>/`.
5. Testing: Write unit tests in `tests/unit/<FEATURE_NAME>.test.ts`.
Do not introduce breaking changes or push to git.
```

---

### Prompt 2: API Endpoint Standard
```markdown
Create a secure JSON API endpoint at `src/routes/api/<ENDPOINT_NAME>/+server.ts`:
1. Use `jsonOk` and `jsonError` helpers from `$server/core/http/index.ts`.
2. Validate input payload using Zod schemas.
3. Enforce rate limiting via `$server/security/rate-limit.ts`.
4. Authenticate user via `event.locals.user` or return 401 UnauthorizedError.
```
