# 📚 Mục lục tài liệu — Bot Gateway (n8n)

Dự án tự động hoá: Telegram Bot Gateway + đồng bộ ClickUp ↔ Postgres (n8n, FachkraftSupply/n8nwf).

## 🚀 Bắt đầu ở đây

| Tài liệu | Nội dung |
|---|---|
| [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) | **Đọc file này TRƯỚC** mỗi khi bắt đầu phiên làm việc mới — trạng thái hiện tại, checklist việc còn dang dở |
| [`RULES.md`](./RULES.md) | ⚠️ Quy tắc BẮT BUỘC khi sửa workflow — đọc trước khi động vào bất kỳ node nào |
| [`FAQ.md`](./FAQ.md) | Lỗi thường gặp + cách đã sửa — tra cứu nhanh khi gặp lỗi quen thuộc |
| [`CHANGELOG.md`](./CHANGELOG.md) | Lịch sử thay đổi theo ngày, chi tiết kỹ thuật đầy đủ |
| [`GO_LIVE_CHECKLIST.md`](./GO_LIVE_CHECKLIST.md) | Checklist đổi credential khi go-live (cutover sang bot PROD) |

## 🔧 Giải thích chi tiết từng workflow (dành cho người học lập trình)

Mỗi file dưới đây giải thích TỪNG node Code theo cấu trúc **Vấn đề → Ý tưởng → Cách làm thực tế**,
kèm giải thích từng biến/hàm/khái niệm JavaScript cho người mới bắt đầu.

| Workflow | Giải thích chi tiết |
|---|---|
| `GW_Gateway_Telegram.json` | [`GUIDE_gateway_explained.md`](./GUIDE_gateway_explained.md) |
| `SQL_ClickUp_Full_Reconcile.json` | [`GUIDE_FULL_RECONCILE_EXPLAINED.md`](./GUIDE_FULL_RECONCILE_EXPLAINED.md) |
| `SQL_ClickUp_Live_Update.json` | [`GUIDE_live_update_explained.md`](./GUIDE_live_update_explained.md) |
| `SQL_ClickUp_Sync_Scheduler.json` | [`GUIDE_scheduler_explained.md`](./GUIDE_scheduler_explained.md) |
| `Telebot_ClickUp_Reader.json` + `Telebot_Admin_System.json` | [`GUIDE_reader_adminsystem_explained.md`](./GUIDE_reader_adminsystem_explained.md) |

## 📖 Hướng dẫn vận hành

| Tài liệu | Nội dung |
|---|---|
| [`GUIDE_SQL_CLICKUP_SYNC.md`](./GUIDE_SQL_CLICKUP_SYNC.md) | Hướng dẫn vận hành đầy đủ Full Reconcile + Live Update + Sync Scheduler |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Kiến trúc tổng thể hệ thống |
| [`BOT_INVENTORY.md`](./BOT_INVENTORY.md) | Danh sách bot Telegram và vai trò từng bot |
| [`GUIDE_DEPLOY_DATABASE.md`](./GUIDE_DEPLOY_DATABASE.md) | Hướng dẫn triển khai database |
| [`SETUP_PHASE_0_1.md`](./SETUP_PHASE_0_1.md) | Setup ban đầu Phase 0-1 |

## 🗂️ Cấu trúc workflow hiện tại

```
Bot thường (@elite_n8n_test_bot → sắp cutover @Elite_clickup_bot)
  → GW_Gateway_Telegram.json → Telebot_ClickUp_Reader.json (/task, chitiet_, /help rút gọn)

Bot Admin (@elite_n8n_system_bot, Trigger riêng, KHÔNG qua Gateway)
  → Telebot_Admin_System.json (đầy đủ: /task, /sync, /sync_status, /db_status, /help, chitiet_)

Đồng bộ dữ liệu (chạy nền, không qua Telegram Trigger)
  → SQL_ClickUp_Sync_Scheduler.json (định kỳ 5 ngày, điều phối đa-List)
      → SQL_ClickUp_Full_Reconcile.json (engine sync 1 List)
  → SQL_ClickUp_Live_Update.json (webhook real-time, tức thời)
```
