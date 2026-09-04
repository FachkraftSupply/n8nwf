# Bot Gateway System

Hệ thống gateway tập trung cho bot đa nền tảng (Telegram, dự phòng Zalo/Discord)
chạy trên n8n self-hosted + Postgres Docker + Supabase (dual storage).

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `sql/01_gateway_schema.sql` | Schema DB — chạy trên CẢ Postgres Docker và Supabase |
| `workflows/original/` | 5 workflow production NGUYÊN BẢN, chưa sửa gì |
| `workflows/new_architecture/GW_Gateway_Telegram.json` | Workflow Gateway (import vào n8n) |
| `workflows/new_architecture/GW_Error_Handler.json` | Error handler toàn cục |
| `workflows/new_architecture/sub_workflows_modernized/` | 5 workflow trên đã nâng n8n 2.37.7 + dual storage, sẽ nối vào Gateway |
| `docs/GUIDE_DEPLOY_DATABASE.md` | 👈 BẮT ĐẦU TỪ ĐÂY — triển khai DB cho người mới |
| `docs/BOT_INVENTORY.md` | Ánh xạ 8 bot Telegram hiện có vào vai trò trong Gateway |
| `docs/SETUP_PHASE_0_1.md` | Import workflow + 7 test nghiệm thu |
| `docs/ARCHITECTURE.md` | Kiến trúc + Envelope Spec + hướng dẫn AI dựng nền tảng dự phòng |
| `docs/PROJECT_STATUS.md` | 👈 Trạng thái hiện tại — đọc file này khi mở chat mới để tiếp tục |

## Thứ tự triển khai

1. `docs/GUIDE_DEPLOY_DATABASE.md` — dựng schema trên 2 DB (~20 phút)
2. `docs/BOT_INVENTORY.md` — xác nhận bot nào gắn vào đâu trước khi import
3. `docs/SETUP_PHASE_0_1.md` — import 2 workflow, gắn credential, chạy 7 test
4. `docs/ARCHITECTURE.md` — đọc trước khi migrate các bot production (Phase 2+)

## Hạ tầng đang dùng

- **Postgres Docker**: credential n8n `Postgres account` (id `iNVsYeDUnMl6pq4M`), container `n8n_stack-postgres-1`, database `n8n`
- **Supabase**: project "Telegram authentication DB" (`nlgmkfqtmarsdcqismzz`, ap-southeast-1) — schema `gateway` đã áp dụng qua Supabase MCP
