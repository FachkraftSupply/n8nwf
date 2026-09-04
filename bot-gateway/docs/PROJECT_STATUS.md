# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Dán file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm đủ ngữ cảnh
> mà không cần đọc lại lịch sử debug dài ở phiên trước.

## Repo
`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua Composio (OAuth, không dùng token).

## Đã HOÀN THÀNH (Giai đoạn 0–1)
- Schema `gateway` (4 bảng: bot_users, bot_permissions, interaction_logs, config) đã tạo trên **cả 2 DB**: Postgres Docker (`n8n_stack-postgres-1`, database `n8n`) và Supabase (project **"Telegram authentication DB"**, ref `nlgmkfqtmarsdcqismzz`).
- Admin ID đúng: **`975005174`** (đã sửa từ ID sai `7030500584` ban đầu, đồng bộ cả 2 DB + workflow).
- Workflow `GW Gateway - Telegram (DEV)` đã import vào n8n, gắn đủ credential (`Telegram Dev Bot` = `@elite_n8n_test_bot`, `Telegram System Bot` = `@elite_n8n_system_bot`, `Supabase Postgres`).
- Workflow `GW Error Handler` đã import + set làm Error Workflow toàn cục.
- **Đã sửa lỗi cú pháp quan trọng**: mọi `queryReplacement` nhiều tham số trong Postgres node phải viết dạng mảng `={{ [$json.a, $json.b] }}`, KHÔNG được viết `={{ $json.a }},{{ $json.b }}` (cú pháp cũ gây lỗi "no parameter $N", đã sửa ở 4 node: Audit Log Docker/Supabase, Tạo pending user, Approve: cấp quyền).
- Test đã pass: admin nhắn `/help` → route đúng tới `help_bot` (dừng ở node placeholder vì sub-workflow thật chưa nối — đúng kỳ vọng).

## Đang làm dở — 7 test nghiệm thu (`docs/SETUP_PHASE_0_1.md`)
| # | Test | Trạng thái |
|---|---|---|
| 1 | Admin route đúng | ✅ |
| 2 | User lạ → chờ duyệt + admin nhận nút | 🔄 đang test lại sau fix queryReplacement |
| 3 | Admin bấm approve → cả 2 bên nhận thông báo | ⬜ |
| 4 | User được duyệt dùng lệnh | ⬜ |
| 5 | User chưa có quyền bị chặn đúng cách | ⬜ |
| 6 | Log ghi đủ cả 2 DB | ⬜ (cần verify lại sau fix) |
| 7 | Non-admin bấm nút approve bị chặn | ⬜ |

## Bot inventory (chi tiết: `docs/BOT_INVENTORY.md`)
- `@elite_n8n_test_bot` → Gateway DEV (đang dùng)
- `@Elite_clickup_bot` → Gateway PROD (dành cho Giai đoạn 4 - cutover)
- `@elite_n8n_system_bot` → kênh Error Handler
- `@Elite_system_bot` (backup_data) → output crawl_bot + BACKUP N8N
- `@elite_tele_help_bot` → nghỉ hưu dần, chức năng gộp vào Gateway (`bot_key: help_bot`)

## VIỆC TIẾP THEO — Giai đoạn 2
Chuyển **Elite Help Bot GPT** (workflow production hiện có, đang chạy độc lập với Telegram Trigger riêng) thành sub-workflow nhận input từ Gateway:
1. Thêm **Execute Workflow Trigger** vào đầu workflow Elite Help Bot GPT, nhận đúng Message Envelope spec (xem `docs/ARCHITECTURE.md` mục 3).
2. Giữ nguyên 100% logic AI Agent bên trong.
3. Bất kỳ node nào trong đó tự gửi Telegram trực tiếp → cân nhắc chuyển thành return data về Gateway (nguyên tắc: chỉ Gateway được nói chuyện với nền tảng) — **hoặc** đơn giản hơn cho giai đoạn này: cho phép nó tự gửi luôn (dùng chung `Telegram Dev Bot`), tối ưu sau.
4. Gắn workflow ID thật vào node `→ Sub: Help Bot` trong Gateway (đang là placeholder `REPLACE_HELP_BOT_ID`).
5. Production Elite Help Bot GPT (trigger cũ) vẫn chạy song song, không tắt.

## Quy tắc làm việc để tránh phình context (áp dụng từ chat mới)
- Khi sửa workflow JSON, dùng `str_replace` trên phần thay đổi thay vì dán lại toàn bộ file.
- Khi cần commit lên GitHub qua Composio, chỉ đưa đúng nội dung file cuối cùng 1 lần, tránh thử nhiều phương án (base64/chunk) trong cùng lượt nếu cách đơn giản (UTF-8 trực tiếp) đã từng chạy được.
- Credential Postgres docker: `Postgres account` (id `iNVsYeDUnMl6pq4M`). Credential Supabase: `Supabase Postgres`.
