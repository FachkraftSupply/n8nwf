# Bot Gateway System

Hệ thống gateway tập trung cho bot đa nền tảng (Telegram, dự phòng Zalo/Discord)
chạy trên n8n self-hosted + Postgres Docker + Supabase (dual storage).

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| sql/01_gateway_schema.sql | Schema DB — chạy trên CẢ Postgres Docker và Supabase |
| workflows/02_GW_Gateway_Telegram.json | Workflow Gateway (import vào n8n) |
| workflows/03_GW_Error_Handler.json | Error handler toàn cục |
| docs/GUIDE_DEPLOY_DATABASE.md | 👈 BẮT ĐẦU TỪ ĐÂY — triển khai DB cho người mới |
| docs/SETUP_PHASE_0_1.md | Import workflow + 7 test nghiệm thu |
| docs/BOT_INVENTORY.md | Ánh xạ 8 bot Telegram hiện có vào vai trò trong Gateway |
| docs/ARCHITECTURE.md | Kiến trúc + Envelope Spec + hướng dẫn AI dựng nền tảng dự phòng |

## Thứ tự triển khai

1. docs/GUIDE_DEPLOY_DATABASE.md — dựng schema trên 2 DB (~20 phút)
2. docs/BOT_INVENTORY.md — xác nhận bot nào gắn vào đâu trước khi import
3. docs/SETUP_PHASE_0_1.md — import 2 workflow, gắn credential, chạy 7 test
4. Đọc docs/ARCHITECTURE.md trước khi migrate các bot production (Phase 2+)

## Hạ tầng đang dùng

- Postgres Docker: credential n8n "Postgres account" (instance chính, Mac Mini)
- Supabase: project "Telegram authentication DB" (nlgmkfqtmarsdcqismzz, region ap-southeast-1)
  — schema gateway đã được áp dụng trực tiếp qua Supabase MCP. Schema này KHÔNG expose qua
  REST API (PostgREST) nên không cần RLS — chỉ truy cập được qua kết nối Postgres trực tiếp
  (n8n Postgres credential), không phơi ra API công khai.
