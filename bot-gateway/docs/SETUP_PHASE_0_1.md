# SETUP GIAI ĐOẠN 0 + 1 — làm theo thứ tự, ~30 phút

## Giai đoạn 0 — Chuẩn bị (không đụng production)

1. **Tạo bot Telegram DEV**: chat @BotFather → `/newbot` → lấy token.
   Trong n8n tạo credential Telegram mới tên `Telegram Dev Bot`.
2. **Chạy DDL**: mở file `01_gateway_schema.sql`
   - Postgres Docker: `docker exec -i <postgres_container> psql -U <user> -d <db> < 01_gateway_schema.sql`
   - Supabase: dán vào SQL Editor → Run.
   - Kiểm tra admin ID trong phần SEED (đang là `7030500584`) — nếu sai thì sửa trước khi chạy.
3. **Credential Supabase Postgres** (nếu chưa có từ đợt Telebot sql): n8n → Credentials →
   Postgres mới tên `Supabase Postgres`, dùng thông tin từ Supabase → Settings → Database
   → Connection pooler (host `aws-xxx.pooler.supabase.com`, port 6543, SSL require).

## Giai đoạn 1 — Import & test Gateway

4. **Import `03_GW_Error_Handler.json`** → gắn credential `Telegram Dev Bot` → Save → Activate.
5. **Import `02_GW_Gateway_Telegram.json`**, sau đó:
   - Gắn credential `Telegram Dev Bot` vào Telegram Trigger + tất cả node Telegram (9 node).
   - Node `Audit Log (Supabase)`: chọn credential `Supabase Postgres`.
   - Các node Postgres còn lại đã trỏ sẵn `Postgres account` (docker) — kiểm tra lại.
   - 3 node `→ Sub: ...`: TẠM THỜI để nguyên placeholder (Giai đoạn 2 mới gắn). Muốn test
     router chưa cần sub-workflow: disable 3 node này, luồng vẫn chạy tới Route bot.
   - Node `⚙️ Config`: xác nhận ADMIN_CHAT_ID.
   - Workflow Settings → Error Workflow → chọn `GW Error Handler`.
   - Save → Activate.

## Test nghiệm thu (5 phút)

| # | Hành động | Kỳ vọng |
|---|---|---|
| 1 | Nhắn bot dev bằng tài khoản admin: `/help` | Nhận "Hướng dẫn lệnh" hoặc route (admin đã seed active) |
| 2 | Nhắn bot bằng 1 tài khoản Telegram khác (user lạ) | User nhận "chờ phê duyệt"; admin nhận tin có 5 nút |
| 3 | Admin bấm `✅ help_bot` | Admin nhận xác nhận; user nhận "đã được cấp quyền" |
| 4 | User đó nhắn `/ask xin chào` | Route vào nhánh Help Bot (nếu sub chưa gắn: execution dừng ở node placeholder — đúng kỳ vọng) |
| 5 | User đó nhắn `/task abc` | Nhận "chưa được cấp quyền dùng chức năng telebot_main" |
| 6 | Kiểm tra log 2 DB | `SELECT * FROM gateway.interaction_logs ORDER BY id DESC LIMIT 10;` — có trên CẢ docker lẫn Supabase |
| 7 | Tài khoản không phải admin bấm thử nút approve (forward tin) | Nhận "Bạn không có quyền thực hiện thao tác này" |

## Fallback đã cài sẵn trong thiết kế
- Audit Supabase lỗi → luồng chính vẫn chạy (`onError: continue`).
- Gửi tin cho user thất bại (user block bot) → không chặn nhánh admin.
- Mọi lỗi node khác → `GW Error Handler` báo về Telegram admin kèm tên node.

Xong 7/7 test → báo tôi, ta sang Giai đoạn 2: chuyển Elite Help Bot GPT thành sub-workflow đầu tiên.
