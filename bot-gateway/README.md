# Bot Gateway System

Hệ thống automation cho **FS International / Elite Education** (công ty đưa học sinh Việt Nam đi
Ausbildung tại Đức): gateway tập trung cho bot đa nền tảng (Telegram, dự kiến mở rộng Zalo/Discord),
đồng bộ dữ liệu ClickUp ↔ Postgres, backup hệ thống. Chạy trên n8n self-hosted + Postgres Docker.

> **AI đọc file này lần đầu:** nên đọc theo thứ tự **1. Mục này (cấu trúc repo) → 2. `docs/PROJECT_STATUS.md`
> (trạng thái/checklist hiện tại) → 3. `docs/RULES.md` (quy tắc bắt buộc trước khi sửa bất kỳ workflow
> nào)**. 3 file này đủ để nắm toàn bộ ngữ cảnh dự án mà không cần đọc lại lịch sử chat.

## Cấu trúc repo

```
bot-gateway/
├── README.md                          ← file này — bắt đầu đọc từ đây
├── docs/                               ← TOÀN BỘ tài liệu, xem bảng chi tiết bên dưới
├── sql/                                ← schema SQL gốc (deploy DB lần đầu)
│   ├── 01_gateway_schema.sql              schema `gateway` (auth, duyệt user, config)
│   └── 02_clickup_tasks_schema.sql        schema `clickup` (tasks/task_links/sync_targets) — LƯU Ý:
│                                          các bảng đã tiến hoá nhiều qua ALTER TABLE trong Ensure
│                                          Schema của workflow — file này KHÔNG còn phản ánh 100%
│                                          cấu trúc bảng hiện tại, chỉ dùng cho lần khởi tạo đầu tiên.
├── scripts/
│   └── restore.sh                         script khôi phục DB từ backup
├── original/                           ← 5 workflow PRODUCTION GỐC, chỉ để THAM KHẢO, KHÔNG SỬA
│   ├── BACKUP_N8N.json                    mẫu tham khảo cho SQL_Backup_System.json
│   ├── Elite_Crawl_Bot.json                mẫu tham khảo cho tính năng tóm tắt/crawl (chưa xây)
│   ├── Elite_Help_Bot_GPT.json             mẫu gốc — bản đã nâng cấp nằm ở new_architecture/
│   ├── Telebot_main.json                   mẫu tham khảo xử lý ảnh (xoá nền, OCR) — CHƯA XÂY
│   └── Telebot_sql.json                    QUAN TRỌNG: mẫu tham số ClickUp node ĐÚNG (xem RULES.md #4)
└── workflows/new_architecture/         ← TOÀN BỘ workflow đang triển khai/sẽ triển khai
    ├── GW_Gateway_Telegram.json            ✅ ACTIVE — Gateway, chạy trên bot user thường (DEV/PROD)
    ├── GW_Error_Handler.json               ✅ ACTIVE — xử lý lỗi tập trung
    ├── SQL_ClickUp_Full_Reconcile.json     ✅ ACTIVE — "engine" sync 1 List ClickUp → Postgres
    ├── SQL_ClickUp_Sync_Scheduler.json     ✅ ACTIVE — điều phối đa-List, gọi Full Reconcile định kỳ
    ├── SQL_ClickUp_Live_Update.json        ✅ ACTIVE — webhook real-time khi ClickUp thay đổi
    ├── SQL_Backup_System.json              🚧 ĐANG XÂY — backup n8n + Postgres, xem PROJECT_STATUS.md
    └── sub_workflows_modernized/
        ├── Telebot_ClickUp_Reader.json     ✅ ACTIVE — bot user thường (qua Gateway): /task, chi tiết
        ├── Telebot_Admin_System.json       ✅ ACTIVE — bot Admin (Trigger riêng, KHÔNG qua Gateway):
        │                                      /task, /sync, /sync_status, /db_status, /backup_n8n,
        │                                      /backup_db, /help — đầy đủ mọi lệnh
        ├── Elite_Help_Bot_GPT.json         ⏳ SẴN SÀNG — đã nhận Envelope, chờ Workflow ID gắn Gateway
        ├── Telebot_main.json               ⚠️ KHÔNG DÙNG — bản copy tham khảo, đã thay bằng Reader+AdminSystem
        ├── Telebot_sql.json                ⚠️ KHÔNG DÙNG — bản copy tham khảo
        ├── Elite_Crawl_Bot.json            ⚠️ KHÔNG DÙNG — bản copy tham khảo, chờ xây tính năng mới
        └── BACKUP_N8N.json                 ⚠️ KHÔNG DÙNG — bản copy tham khảo, đã thay bằng SQL_Backup_System.json
```

## Nhiệm vụ từng file trong `docs/`

| File | Khi nào đọc | Nội dung |
|---|---|---|
| **`PROJECT_STATUS.md`** | **Luôn đọc đầu tiên** khi bắt đầu phiên làm việc mới | Trạng thái hiện tại, checklist việc dang dở, phát hiện/lỗi mới nhất chưa xử lý xong |
| **`RULES.md`** | **Luôn đọc trước khi sửa bất kỳ workflow nào** | Quy tắc bắt buộc: Gateway COMMAND_MAP, tham chiếu `$json` tường minh, không dùng inline keyboard, format node ClickUp, cách giữ dữ liệu qua chuỗi Postgres node... |
| `FAQ.md` | Khi gặp lỗi | Lỗi thường gặp + cách đã sửa, tra cứu nhanh trước khi debug lại từ đầu |
| `CHANGELOG.md` | Muốn biết lịch sử | Lịch sử thay đổi theo ngày, chi tiết kỹ thuật đầy đủ hơn PROJECT_STATUS |
| `ARCHITECTURE.md` | Hiểu kiến trúc tổng thể | Kiến trúc gateway, Envelope Spec, hướng dẫn AI dựng thêm sub-workflow mới |
| `BOT_INVENTORY.md` | Cần biết vai trò từng bot | Danh sách bot Telegram, vai trò, bot nào dùng cho việc gì |
| `GO_LIVE_CHECKLIST.md` | Chuẩn bị go-live | Checklist đổi credential khi cutover sang bot PROD |
| `GUIDE_SQL_CLICKUP_SYNC.md` | Vận hành sync ClickUp | Hướng dẫn vận hành Full Reconcile + Live Update + Sync Scheduler |
| `GUIDE_DEPLOY_DATABASE.md` | Deploy DB lần đầu | Hướng dẫn triển khai 2 DB (Postgres + Supabase) cho người mới |
| `SETUP_PHASE_0_1.md` | Setup ban đầu | Import workflow, 7 test nghiệm thu Phase 0-1 |
| `GUIDE_FULL_RECONCILE_EXPLAINED.md` | Học/hiểu code | Giải thích chi tiết từng node Code trong Full Reconcile (Vấn đề→Ý tưởng→Cách làm) |
| `GUIDE_gateway_explained.md` | Học/hiểu code | Giải thích chi tiết node Code trong Gateway, dành cho người mới học lập trình |
| `GUIDE_live_update_explained.md` | Học/hiểu code | Giải thích chi tiết node Code trong Live Update |
| `GUIDE_reader_adminsystem_explained.md` | Học/hiểu code | Giải thích chi tiết node Code trong Reader + Admin System |
| `GUIDE_scheduler_explained.md` | Học/hiểu code | Giải thích Sync Scheduler (không có node Code, giải thích ý nghĩa từng node có sẵn) |
| `README.md` (trong docs/) | Mục lục nhanh | Bảng liên kết ngắn gọn tới tất cả file trên (bản rút gọn của bảng này) |

## Kiến trúc luồng chính

```
👤 User thường → @elite_n8n_test_bot (→ @Elite_clickup_bot khi go-live)
                 → GW_Gateway_Telegram.json → Telebot_ClickUp_Reader.json
                    (/task, chitiet_, /help rút gọn)

👨‍💼 Admin → @elite_n8n_system_bot (Trigger riêng, KHÔNG qua Gateway)
             → Telebot_Admin_System.json (đầy đủ mọi lệnh)

🔄 Đồng bộ dữ liệu (chạy nền)
   SQL_ClickUp_Sync_Scheduler.json (định kỳ 5 ngày, điều phối đa-List)
     → SQL_ClickUp_Full_Reconcile.json (engine sync 1 List)
   SQL_ClickUp_Live_Update.json (webhook real-time)

💾 Backup (chạy nền hoặc theo lệnh admin)
   SQL_Backup_System.json (Manual/Schedule/Execute Workflow Trigger)
```

## Hạ tầng đang dùng

- **n8n**: self-hosted, VPS Hostinger (AlmaLinux 10 + DirectAdmin), Docker Compose stack `n8n_stack`,
  image `n8nio/n8n:2.37.7` (Docker Hardened Image — không có `apk`, không cài thêm gói trực tiếp được).
- **Postgres**: Docker container `n8n_stack-postgres-1`, image `postgres:16-alpine`, database `n8n`,
  schema `clickup` (tasks/task_links/sync_targets) + `gateway` (auth/config).
- **Supabase**: project "Telegram authentication DB" — dùng song song cho 1 phần schema `gateway`.
- **OneDrive**: lưu trữ file backup (đã chuyển từ Google Drive).
- **Repo**: `FachkraftSupply/n8nwf`, kết nối qua Composio (OAuth, không dùng token thô).

## Quy trình làm việc chuẩn (cho AI hỗ trợ dự án)

1. Đọc `docs/PROJECT_STATUS.md` trước.
2. Đọc `docs/RULES.md` trước khi sửa bất kỳ workflow nào.
3. Sửa file JSON lớn: dùng Composio remote workbench (fetch GitHub → sửa Python trong sandbox → commit).
4. Validate trước khi commit (connections orphan, dup id, surrogate lỗi encoding).
5. Sau mỗi thay đổi được xác nhận: cập nhật `CHANGELOG.md` + `PROJECT_STATUS.md`.
6. Mỗi khi thêm lệnh mới: kiểm tra CÓ ĐIỀU KIỆN xem sub-workflow đó gọi qua Gateway hay có Trigger riêng
   — chỉ cập nhật `COMMAND_MAP` của Gateway nếu gọi qua Gateway.
