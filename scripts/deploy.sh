#!/usr/bin/env bash

# ==============================================================================
# 🚀 SvelteKit Starter Template - Production Automated Deployment Script
# ==============================================================================
# Hướng dẫn sử dụng trên VPS:
#   git clone git@github.com-github-thanhlam2020:LamVT2020/sveltekit-starter-template.git
#   cd sveltekit-starter-template
#   ./scripts/deploy.sh (hoặc: npm run deploy)
# ==============================================================================

set -eo pipefail

# ANSI Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'
C_MAGENTA='\033[35m'

echo -e "${C_CYAN}${C_BOLD}"
echo "================================================================="
echo "   🚀 SVELTEKIT STARTER - AUTOMATED PRODUCTION DEPLOYMENT       "
echo "================================================================="
echo -e "${C_RESET}"

# 0. Xác định thư mục dự án
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_DIR="$(pwd)"
fi
cd "$PROJECT_DIR"
echo -e "${C_YELLOW}📍 Thư mục làm việc:${C_RESET} $PROJECT_DIR"

# 1. Kiểm tra môi trường cơ bản (Node.js & npm)
if ! command -v node &> /dev/null; then
    echo -e "${C_RED}❌ Lỗi: Node.js chưa được cài đặt trên máy chủ!${C_RESET}"
    echo "  Vui lòng cài đặt Node.js (phiên bản khuyến nghị >= 18 hoặc 20)."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${C_RED}❌ Lỗi: npm chưa được cài đặt trên máy chủ!${C_RESET}"
    exit 1
fi

NODE_VERSION=$(node -v)
NPM_VERSION=$(npm -v)
echo -e "${C_GREEN}✔ Node.js:${C_RESET} $NODE_VERSION | ${C_GREEN}npm:${C_RESET} $NPM_VERSION"

# Hàm đọc giá trị trong file .env
get_env_val() {
    local key="$1"
    if [ -f ".env" ]; then
        (grep -E "^[[:space:]]*${key}=" .env 2>/dev/null || true) | tail -n 1 | cut -d '=' -f2- | sed -e 's/^[[:space:]]*["'"'"']//' -e 's/["'"'"'][[:space:]]*$//' -e 's/[[:space:]]*#.*$//'
    fi
}

# Hàm tạo chuỗi ngẫu nhiên bảo mật
generate_secret() {
    if command -v openssl &>/dev/null; then
        openssl rand -hex 32
    else
        node -e "console.log(require('crypto').randomBytes(32).toString('hex'))" 2>/dev/null || date +%s%N | sha256sum | head -c 64
    fi
}

# 2. Xử lý file .env & Kiểm tra / Báo cáo cấu hình
echo -e "\n${C_CYAN}⚙️ Bước 1/7: Kiểm tra và chuẩn hóa cấu hình (.env)...${C_RESET}"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${C_YELLOW}ℹ File .env chưa tồn tại. Đang tự động sao chép từ .env.example...${C_RESET}"
        cp .env.example .env
    else
        echo -e "${C_RED}❌ Lỗi: Không tìm thấy .env hoặc .env.example!${C_RESET}"
        exit 1
    fi
fi

# Đảm bảo PORT được định nghĩa (mặc định 3000 cho sveltekit-starter-template)
APP_PORT="$(get_env_val PORT)"
if [ -z "$APP_PORT" ]; then
    APP_PORT="3000"
    echo "PORT=3000" >> .env
    echo -e "${C_GREEN}✔ Đã bổ sung PORT=3000 vào .env${C_RESET}"
fi

# Tự động sinh AUTH_SECRET nếu đang rỗng hoặc mang giá trị placeholder
AUTH_SECRET_VAL="$(get_env_val AUTH_SECRET)"
if [ -z "$AUTH_SECRET_VAL" ] || [[ "$AUTH_SECRET_VAL" == *"change-this"* ]] || [[ "$AUTH_SECRET_VAL" == *"starter-template"* ]]; then
    NEW_SECRET="$(generate_secret)"
    if grep -q "^[[:space:]]*AUTH_SECRET=" .env; then
        sed -i.bak "s|^[[:space:]]*AUTH_SECRET=.*|AUTH_SECRET=\"$NEW_SECRET\"|" .env && rm -f .env.bak
    else
        echo "AUTH_SECRET=\"$NEW_SECRET\"" >> .env
    fi
    echo -e "${C_GREEN}✔ Đã tự động tạo mã bảo mật ngẫu nhiên cho AUTH_SECRET${C_RESET}"
fi

# --- AUDIT CẤU HÌNH ---
echo -e "\n${C_BOLD}${C_MAGENTA}📋 BẢNG KIỂM TRA CẤU HÌNH (CONFIGURATION AUDIT):${C_RESET}"

MISSING_REQUIRED=0
MISSING_OPTIONAL=0
MISSING_KEYS=()

audit_config() {
    local key="$1"
    local level="$2"     # "REQUIRED" | "OPTIONAL"
    local desc="$3"
    local val
    val="$(get_env_val "$key")"

    local is_empty=0
    if [ -z "$val" ]; then
        is_empty=1
    elif [[ "$val" == *"change"* ]] || [[ "$val" == *"your_"* ]] || [[ "$val" == *"TODO"* ]]; then
        is_empty=1
    fi

    if [ "$is_empty" -eq 0 ]; then
        local masked_val="$val"
        if [ ${#val} -gt 24 ]; then
            masked_val="${val:0:8}...${val: -4}"
        fi
        echo -e "  ${C_GREEN}✔ [ĐÃ CÓ]${C_RESET} ${C_BOLD}${key}${C_RESET} = ${masked_val} (${desc})"
    else
        if [ "$level" = "REQUIRED" ]; then
            echo -e "  ${C_RED}✖ [CẦN ĐIỀN]${C_RESET} ${C_BOLD}${key}${C_RESET} - ${desc}"
            MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
            MISSING_KEYS+=("$key ($desc)")
        else
            echo -e "  ${C_YELLOW}⚠ [TÙY CHỌN]${C_RESET} ${C_BOLD}${key}${C_RESET} - ${desc}"
            MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
            MISSING_KEYS+=("$key (Tùy chọn: $desc)")
        fi
    fi
}

echo -e "${C_CYAN}▶ 1. Runtime & Hệ thống:${C_RESET}"
audit_config "PORT" "REQUIRED" "Cổng dịch vụ web (Target: $APP_PORT)"
audit_config "DATABASE_URL" "REQUIRED" "Đường dẫn SQLite database"
audit_config "APP_ORIGIN" "OPTIONAL" "Địa chỉ truy cập (e.g. http://vps-ip:3000 hoặc https://yourdomain.com)"

echo -e "${C_CYAN}▶ 2. Bảo mật & Xác thực:${C_RESET}"
audit_config "AUTH_SECRET" "REQUIRED" "Khóa bí mật Auth"

echo -e "${C_CYAN}▶ 3. Trí tuệ nhân tạo (AI Engine):${C_RESET}"
audit_config "AI_PROVIDER" "REQUIRED" "Provider AI (gemini)"
audit_config "AI_MODEL" "REQUIRED" "Model AI (gemini-2.0-flash)"
audit_config "GEMINI_API_KEY" "OPTIONAL" "Google Gemini API Key"

echo -e "${C_CYAN}▶ 4. Giám sát & Phân tích:${C_RESET}"
audit_config "GOOGLE_ANALYTICS_ID" "OPTIONAL" "Google Analytics Tracking ID"

if [ "$MISSING_REQUIRED" -gt 0 ] || [ "$MISSING_OPTIONAL" -gt 0 ]; then
    echo -e "\n${C_YELLOW}┌────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_YELLOW}│ 💡 HƯỚNG DẪN CẤU HÌNH BỔ SUNG:                                         │${C_RESET}"
    echo -e "${C_YELLOW}│ Để điền các thông tin còn thiếu, bạn chạy:                             │${C_RESET}"
    echo -e "${C_YELLOW}│   ${C_BOLD}nano .env${C_RESET}${C_YELLOW}                                                           │${C_RESET}"
    echo -e "${C_YELLOW}│ Sau khi lưu file (Ctrl+O, Enter, Ctrl+X), khởi động lại bằng:          │${C_RESET}"
    echo -e "${C_YELLOW}│   ${C_BOLD}pm2 restart ecosystem.config.cjs --update-env${C_RESET}${C_YELLOW}                      │${C_RESET}"
    echo -e "${C_YELLOW}└────────────────────────────────────────────────────────────────────────┘${C_RESET}"
fi

# 3. Tạo thư mục dữ liệu cần thiết & Sao lưu nếu có db cũ
echo -e "\n${C_CYAN}📦 Bước 2/7: Chuẩn bị thư mục dữ liệu và sao lưu...${C_RESET}"
mkdir -p data logs backups

if [ -f "prisma/dev.db" ] || [ -f "dev.db" ]; then
    if grep -q '"backup"' package.json 2>/dev/null; then
        echo -e "${C_CYAN}  Đang tạo bản sao lưu snapshot database...${C_RESET}"
        npm run backup 2>/dev/null || true
    fi
fi

# 4. Kéo code mới nếu là repo Git đã clone trước đó
if [ -d ".git" ]; then
    echo -e "\n${C_CYAN}📥 Bước 3/7: Kiểm tra cập nhật từ Git...${C_RESET}"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git pull origin "$CURRENT_BRANCH" 2>/dev/null || echo -e "${C_YELLOW}  Bỏ qua git pull (mã nguồn vừa clone hoặc có local changes)${C_RESET}"
fi

# 5. Cài đặt các gói phụ thuộc (Dependencies / Modules)
echo -e "\n${C_CYAN}📦 Bước 4/7: Đang cài đặt các module npm (dependencies)...${C_RESET}"
npm install --no-audit --no-fund

# 6. Đồng bộ Prisma Database & Seed dữ liệu người dùng ban đầu
echo -e "\n${C_CYAN}🗄️ Bước 5/7: Đồng bộ cấu trúc Database (Prisma) và tài khoản ban đầu...${C_RESET}"
npx prisma generate
npx prisma db push --skip-generate

if grep -q '"seed:users"' package.json 2>/dev/null; then
    echo -e "${C_CYAN}  Đang khởi tạo tài khoản quản trị viên / demo...${C_RESET}"
    npm run seed:users 2>/dev/null || true
fi

# 7. Build ứng dụng SvelteKit Production Bundle
echo -e "\n${C_CYAN}🛠️ Bước 6/7: Đang build SvelteKit bundle cho production...${C_RESET}"
npm run build

if [ ! -f "build/index.js" ]; then
    echo -e "${C_RED}❌ Lỗi: Build thất bại, không tìm thấy file build/index.js!${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✔ Build hoàn tất thành công (build/index.js sẵn sàng)${C_RESET}"

# 8. Quản lý tiến trình PM2
echo -e "\n${C_CYAN}⚡ Bước 7/7: Khởi động / Khởi động lại dịch vụ qua PM2...${C_RESET}"
PM2_CMD="pm2"
if ! command -v pm2 &> /dev/null; then
    echo -e "${C_YELLOW}⚠ PM2 chưa cài đặt global. Đang thử cài đặt pm2 qua npm...${C_RESET}"
    npm install -g pm2 2>/dev/null || true
    if ! command -v pm2 &> /dev/null; then
        PM2_CMD="npx pm2"
    fi
fi

if [ -f "ecosystem.config.cjs" ]; then
    $PM2_CMD startOrRestart ecosystem.config.cjs --env production
    $PM2_CMD save 2>/dev/null || true
    echo -e "${C_GREEN}✔ Đã cập nhật tiến trình PM2 thành công.${C_RESET}"
else
    echo -e "${C_RED}❌ Lỗi: Không tìm thấy ecosystem.config.cjs!${C_RESET}"
    exit 1
fi

# 9. Health Check & Báo cáo tổng kết
echo -e "\n${C_CYAN}🔍 Kiểm tra trạng thái hoạt động trên cổng ${APP_PORT}...${C_RESET}"
sleep 3

HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "307" ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 DEPLOYMENT THÀNH CÔNG!                                     ${C_RESET}"
    echo -e "   Ứng dụng: ${C_BOLD}SvelteKit Starter${C_RESET} đang ONLINE trên cổng: ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_STATUS})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ DEPLOYMENT ĐÃ CHẠY XONG (HTTP Status: ${HTTP_STATUS})                 ${C_RESET}"
    echo -e "   Kiểm tra log bằng: ${C_BOLD}pm2 logs sveltekit-starter-template --lines 50${C_RESET}"
fi
echo -e "   🌐 Địa chỉ nội bộ : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Địa chỉ công khai: http://<IP_CỦA_VPS>:${APP_PORT}"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}"

if [ "${#MISSING_KEYS[@]}" -gt 0 ]; then
    echo -e "\n${C_YELLOW}📌 DANH SÁCH CẤU HÌNH BẠN CẦN TỰ BỔ SUNG TRONG .env:${C_RESET}"
    for item in "${MISSING_KEYS[@]}"; do
        echo -e "  • ${item}"
    done
    echo -e "\n${C_CYAN}👉 Chạy lệnh: ${C_BOLD}nano .env${C_RESET}${C_CYAN} để cập nhật, sau đó chạy lại deploy hoặc: ${C_BOLD}pm2 restart ecosystem.config.cjs --update-env${C_RESET}\n"
fi
