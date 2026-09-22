# Docker & CI/CD Workflow Standardization Prompts

This guide contains standardized prompt templates for AI assistants and software engineers to enforce **Docker containerization** and a **two-tier CI/CD automation pipeline** (Quality Gates + Remote CD Deploy) across all SvelteKit production applications.

---

## 📋 Table of Contents
1. [Prompt 1: Full Docker & CI/CD Workflow Enforcement](#prompt-1-full-docker--cicd-workflow-enforcement)
2. [Prompt 2: GitHub Actions CI/CD Quality Gates & Remote Deployment](#prompt-2-github-actions-cicd-quality-gates--remote-deployment)
3. [Prompt 3: Production Dockerization & Persistent Volume Architecture](#prompt-3-production-dockerization--persistent-volume-architecture)
4. [Prompt 4: Zero-Downtime Docker Lifecycle & Operations Scripts](#prompt-4-zero-downtime-docker-lifecycle--operations-scripts)
5. [Prompt 5: CI/CD & Docker Audit & Verification Runbook](#prompt-5-cicd--docker-audit--verification-runbook)

---

## Prompt 1: Full Docker & CI/CD Workflow Enforcement

```markdown
Vui lòng chuẩn hóa và triển khai đầy đủ kiến trúc Docker và quy trình CI/CD tự động hóa cho dự án `<PROJECT_NAME>` theo tiêu chuẩn Canonical SvelteKit Architecture:

### 1. Docker Multi-Stage & Container Runtime:
- Tạo/cập nhật `Dockerfile` đa tầng (multi-stage) sử dụng Node 22 (bookworm-slim hoặc alpine).
- Stage 1 (`builder`): Cài đặt dependencies, npx prisma generate, build ứng dụng SvelteKit qua `@sveltejs/adapter-node`.
- Stage 2 (`runner`): Cài đặt OpenSSL (cho Prisma engine), curl (cho healthcheck), dumb-init và gosu. Chạy bằng user không đặc quyền (`USER node`).
- Tạo `docker-compose.yml` với service `<PROJECT_NAME>`, expose cổng nội bộ `127.0.0.1:<PORT>:<PORT>`, restart policy `unless-stopped`.
- Định nghĩa Health Check định kỳ gọi `http://127.0.0.1:<PORT>/api/health`.
- Thiết lập cách ly dữ liệu (Volume Isolation): Mount thư mục SQLite database (`/app/data`) và logs (`/app/logs`) ra volume host `/home/deploy/data/<PROJECT_NAME>` và `/home/deploy/logs/<PROJECT_NAME>` để tuyệt đối không làm mất dữ liệu khi build lại container.

### 2. Bộ Script Quản Lý Docker Vòng Đời Cục Bộ & VPS:
- `docker-entrypoint.sh`: Tự động cấp quyền thư mục, chạy `npx prisma migrate deploy` (hoặc `db push`), seed tài khoản demo/admin mặc định nếu cần trước khi khởi động Node.
- `scripts/deploy-docker.sh`: Script triển khai lần đầu, tự động kiểm tra Docker Compose, kiểm tra `.env`, tạo volume host, build image và verify health check HTTP 200.
- `scripts/update-docker.sh`: Script cập nhật code & image trên VPS: Tự động snapshot backup database -> `git pull` -> `docker compose up -d --build` -> kiểm tra health check.
- `scripts/update-docker-env.sh`: Tái khởi động container ngay lập tức (~2 giây) khi cập nhật biến môi trường `.env` mà KHÔNG cần build lại Docker image (`docker compose up -d --force-recreate`).

### 3. GitHub Actions CI/CD Pipeline Hai Tầng (`.github/workflows/ci-cd.yml`):
- **Tầng 1 (Quality Gates - CI)**: Chạy trên mỗi `push` & `pull_request` vào nhánh `main`, và cho phép kích hoạt thủ công (`workflow_dispatch`).
  * Chạy trên Node 20.x và 22.x matrix.
  * Cài đặt dependencies với `npm ci --no-engine-strict`.
  * Validate Prisma schema & sinh Prisma Client.
  * Kiểm tra migration drift hoặc deploy schema vào database SQLite tạm (`file:/tmp/ci_test.db`).
  * Kiểm tra linter (`npm run lint` / ESLint 9 flat config) và code formatting (`npm run format:check`).
  * Kiểm tra kiểu dữ liệu và cú pháp Svelte (`npm run check` / `svelte-check`).
  * Chạy toàn bộ Unit/Integration Tests (`npm test`).
  * Build bản production (`npm run build`).
- **Tầng 2 (Remote Deploy - CD)**: Chỉ kích hoạt khi tầng CI vượt qua 100% trên nhánh `main`.
  * Tự động kiểm tra Secret VPS (`VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`). Nếu chưa cấu hình, đưa ra cảnh báo hướng dẫn mà không làm gãy build.
  * Kết nối SSH an toàn vào VPS qua `appleboy/ssh-action` và thực thi script triển khai `deploy-docker-<PROJECT_NAME>.sh`.

Đảm bảo tuân thủ nghiêm ngặt: không git commit, không git push, không ssh trực tiếp; chỉ kiểm tra, tạo tệp và kiểm thử cục bộ.
```

---

## Prompt 2: GitHub Actions CI/CD Quality Gates & Remote Deployment

```markdown
Hãy cấu hình quy trình CI/CD tự động hai tầng chuẩn hóa qua GitHub Actions tại `.github/workflows/ci-cd.yml` cho dự án:

1. **Trigger Configuration**:
   - Triggers: `push` vào branch `main`, `pull_request` vào branch `main`, và `workflow_dispatch`.
   - Concurrency: Hủy bỏ các job cũ đang chạy khi có commit mới (`cancel-in-progress: true`).

2. **Job 1: Quality Gates (validate-and-test)**:
   - Environment variables: `DATABASE_URL: "file:/tmp/ci_test.db"`, `NODE_ENV: "test"`.
   - Steps:
     1. Checkout mã nguồn (`actions/checkout@v4`).
     2. Cài đặt Node.js 22 LTS (`actions/setup-node@v4`) với cache npm.
     3. Cài đặt packages: `npm ci --no-engine-strict`.
     4. Prisma Schema Validation & Generate: `npx prisma validate && npm run db:generate`.
     5. DB Migration Check: Chạy migration hoặc push schema lên DB test sạch để phát hiện lỗi migration drift.
     6. Svelte & TypeScript Diagnostics: `npm run check`.
     7. Linter & Format Check: `npm run lint` và `npm run format:check`.
     8. Automated Tests: `npm test` hoặc `npm run test:coverage`.
     9. Production Build: `npm run build`.

3. **Job 2: Remote Deploy to Production VPS (cd-deploy)**:
   - Phụ thuộc: `needs: [validate-and-test]`.
   - Điều kiện: Chỉ chạy trên nhánh `main` khi có push hoặc kích hoạt thủ công.
   - Kiểm tra an toàn secrets:
     ```yaml
     - name: Check Deployment Secrets
       id: check-secrets
       run: |
         if [ -z "${{ secrets.VPS_HOST }}" ]; then
           echo "::warning ::Secret VPS_HOST is not configured! Skipping remote SSH deployment."
           echo "configured=false" >> $GITHUB_OUTPUT
         else
           echo "configured=true" >> $GITHUB_OUTPUT
         fi
     ```
   - SSH Remote Trigger: Sử dụng `appleboy/ssh-action@v1.2.0` gọi script `/home/deploy/scripts/deploy-docker-<APP_NAME>.sh`.

Cập nhật `package.json` bổ sung các lệnh: `format:check`, `ci`, `db:generate`, `test`.
```

---

## Prompt 3: Production Dockerization & Persistent Volume Architecture

```markdown
Hãy xây dựng cấu hình Docker chuẩn sản xuất cho dự án SvelteKit 2 với cơ sở dữ liệu SQLite:

1. **Dockerfile Chuẩn Production**:
   - Multi-stage build (`builder` và `runner`).
   - Cài đặt runtime dependencies: `openssl` (yêu cầu của Prisma), `curl` (yêu cầu của healthcheck), `dumb-init` làm PID 1 để handle signals (SIGTERM/SIGINT) đúng cách.
   - Copy artifacts từ stage builder: `package.json`, `node_modules`, `build`, `prisma`, `scripts`.
   - Chạy với người dùng không có quyền root (`USER node`).
   - Khởi chạy qua `ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]` và `CMD ["node", "build/index.js"]`.

2. **Cấu Hình `docker-compose.yml`**:
   - Khai báo service ứng dụng với image tag cụ thể.
   - Gắn cổng: `"127.0.0.1:<PORT>:<PORT>"` (chỉ lắng nghe loopback trên VPS để Nginx reverse proxy an toàn).
   - Thiết lập volume isolation:
     * `${DATA_DIR:-./data}:/app/data` (Bảo đảm tệp SQLite DB không nằm trong ephemeral layer của container).
     * `${LOG_DIR:-./logs}:/app/logs`.
   - Healthcheck với curl tới endpoint `/api/health`, chu kỳ 30s, timeout 5s, 3 retries.
   - Hỗ trợ fallback nạp tệp cấu hình `.env` theo nhiều cấp đường dẫn VPS: `.env`, `/home/deploy/configs/<APP_NAME>/.env`.

3. **Entrypoint Script (`docker-entrypoint.sh`)**:
   - Tạo thư mục `/app/data` và `/app/logs` nếu chưa có.
   - Đồng bộ database: Tự động chạy `npx prisma migrate deploy` hoặc `npx prisma db push --skip-generate`.
   - Tự động seed tài khoản quản trị viên và dữ liệu ban đầu nếu chưa tồn tại.
   - Chuyển quyền thực thi an toàn sang `USER node`.
```

---

## Prompt 4: Zero-Downtime Docker Lifecycle & Operations Scripts

```markdown
Tạo bộ script bash vận hành chuẩn hóa trong thư mục `scripts/` hỗ trợ triển khai và bảo trì Docker không gián đoạn:

1. **`scripts/deploy-docker.sh` (First-time Deployment)**:
   - Kiểm tra `docker` và `docker compose`.
   - Tự động tìm nạp cấu hình `.env` từ `/home/deploy/configs/<APP_NAME>/.env` hoặc `.env.example`.
   - Tự sinh `AUTH_SECRET` an toàn (64 hex characters) nếu chưa được đặt.
   - Chuẩn bị thư mục volume lưu trữ bền vững `/home/deploy/data/<APP_NAME>` và phân quyền thích hợp.
   - Thực thi `docker compose up -d --build`.
   - Polling kiểm tra health check HTTP 200 tại `http://127.0.0.1:<PORT>/api/health` với tối đa 15 lần thử.

2. **`scripts/update-docker.sh` (Code & Image Upgrade)**:
   - Tự động tạo bản sao lưu snapshot database trước khi cập nhật (`npm run backup`).
   - Thực hiện `git pull origin <branch>` để lấy code mới nhất.
   - Rebuild image và recreate container: `docker compose up -d --build`.
   - Verify health check đảm bảo dịch vụ đã sẵn sàng phục vụ người dùng.

3. **`scripts/update-docker-env.sh` (Instant Zero-Rebuild Configuration Reload)**:
   - Sử dụng lệnh `docker compose up -d --force-recreate`.
   - Nạp lại biến môi trường mới vào container đang chạy trong vòng ~2 giây mà KHÔNG cần tốn thời gian rebuild toàn bộ Docker image.
   - Kiểm tra lại endpoint health check sau khi khởi động.
```

---

## Prompt 5: CI/CD & Docker Audit & Verification Runbook

```markdown
Tiến hành kiểm tra (audit) và nghiệm thu toàn diện hệ sinh thái Docker & CI/CD của dự án:

1. **Cục Bộ (Local Machine)**:
   - Chạy `npm run check` đảm bảo SvelteKit và TypeScript không có lỗi cú pháp.
   - Chạy `npm run lint` và `npm run format:check` đảm bảo mã nguồn tuân thủ ESLint 9 và Prettier.
   - Chạy `npm test` đảm bảo 100% unit/integration tests vượt qua.
   - Chạy `npm run build` đảm bảo adapter-node build thành công không có warning nghiêm trọng.
   - Kiểm tra `docker compose config` xác nhận cú pháp compose file hợp lệ.

2. **Quy Trình CI/CD**:
   - Kiểm tra tệp `.github/workflows/ci-cd.yml` có đầy đủ các bước kiểm tra chất lượng.
   - Đảm bảo step kiểm tra secret VPS không gây fail build khi dev fork repo hoặc chưa thêm secrets.
   - Đảm bảo database trong CI sử dụng SQLite isolated file hoặc in-memory để kiểm thử độc lập.

3. **Bảo Mật & Lưu Trữ Dữ Liệu**:
   - Xác nhận đường dẫn database SQLite trong Docker luôn được trỏ vào thư mục mount (`/app/data/`).
   - Kiểm tra `.dockerignore` để loại trừ `node_modules`, `.git`, `data/*.db*`, `.env`, tránh lộ lọt bí mật vào Docker image layers.
```
