# Bot Gateway System

Hệ thống gateway tập trung cho bot đa nền tảng (Telegram, dự phòng Zalo/Discord)
chạy trên n8n self-hosted + Postgres Docker + Supabase (dual storage).

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `sql/01_gateway_schema.sql` | Schema DB — chạy trên CẢ Postgres Docker và Supabase |
| `workflows/02_GW_Gateway_Telegram.json` | Workflow Gateway (import vào n8n) |
| `workflows/03_GW_Error_Handler.json` | Error handler toàn cục |
| `docs/GUIDE_DEPLOY_DATABASE.md` | 👈 BẮT ĐẦU TỪ ĐÂY — triển khai DB cho người mới |
| `docs/SETUP_PHASE_0_1.md` | Import workflow + 7 test nghiệm thu |
| `docs/ARCHITECTURE.md` | Kiến trúc + Envelope Spec + hướng dẫn AI dựng nền tảng dự phòng |

## Thứ tự triển khai

1. `docs/GUIDE_DEPLOY_DATABASE.md` — dựng schema trên 2 DB (~20 phút)
2. `docs/SETUP_PHASE_0_1.md` — import 2 workflow, gắn credential, chạy 7 test
3. Đọc `docs/ARCHITECTURE.md` trước khi migrate các bot production (Phase 2+)
