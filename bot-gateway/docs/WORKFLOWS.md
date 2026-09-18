# WORKFLOWS.md — Bản đồ tra cứu workflow n8n (dự án Bot Gateway)

> Mục đích chính: để AI (Claude) tra `workflowId` ngay, không cần `search_workflows` mò lại từ đầu
> mỗi phiên. Người đọc cũng dùng được — cột "Link" bấm mở thẳng workflow trong n8n.
> Khi tạo workflow mới hoặc đổi ID (xoá/tạo lại) — cập nhật NGAY bảng dưới, đừng để bảng lệch thực tế.

**Base URL n8n**: `https://n8n.toididuhoc.net/workflow/<id>`

## Bảng workflow chính

| Tên workflow | ID | Vai trò | Trigger | Gọi bởi / gọi tới |
|---|---|---|---|---|
| **GW Gateway - Telegram (DEV)** | `xmEKeIUnzxm2F7dF` | Cổng vào DUY NHẤT cho mọi lệnh Telegram của bot chính — auth, routing theo `COMMAND_MAP`/`resolveBotKeyForCallback`, log group chat, phát hiện `@@mention` | Telegram Trigger, bot **Elite Clickupbot** (`BHVAx8GV38yQEn1I`) | Gọi tới: Telebot ClickUp Reader, Telebot Lock, Bot Xử Lý Ảnh, GW Mention Resolver |
| **Telebot ClickUp Reader** | `9JJRrh36H2rLwtnu` | Bot chính cho user: `/task`, `/lichsu`, `/timkiem`, `/sum`, `/help`, `/cancel`, chi tiết task, Upload OneDrive + forward thông báo nhóm | Execute Workflow Trigger (gọi từ Gateway) | Gọi từ: Gateway |
| **Telebot Lock (TTLock)** | `vGgJ0XfTR3ltohPB` | Lệnh `/mokhoa` — mở khóa cửa TTLock từ xa, chặn sai nhóm/khung giờ, luồng admin duyệt | Execute Workflow Trigger (gọi từ Gateway) | Gọi từ: Gateway. Gọi tới: TTLock Token Helper |
| **TTLock Token Helper** | `hX4nU6buJNBQKRp8` | Sub-workflow dùng chung: đọc/refresh access token TTLock lưu trong Postgres (`gateway.ttlock_auth`) | Execute Workflow Trigger | Gọi từ: Telebot Lock (TTLock) |
| **GW Mention Resolver** | `ESbedUROf4udAkY6` | Xử lý `@@all`/`@@<nhóm>` — trả lời mention trong nhóm + DM riêng cho người được nhắc kèm link tin nhắn gốc | Execute Workflow Trigger (gọi từ Gateway) | Gọi từ: Gateway |
| **Bot Xử Lý Ảnh (xoanen + tomtat)** | `6I4MnJiJCiv2JOIr` | Lệnh `/xoanen` (xóa nền ảnh AI) và `/tomtat` (OCR + tóm tắt ảnh bằng Mistral) | Execute Workflow Trigger (gọi từ Gateway) | Gọi từ: Gateway |
| **Telebot Admin System (System Bot dedicated)** | `eWtu7Qs85Hes0HuP` | Bot Admin riêng: `/user_list` (cấp/thu hồi quyền, xoá user), `/tao_group`, `/xem_nhom` (quản lý nhóm mention) | Telegram Trigger RIÊNG, bot **Telegram System Bot** (`zSZ6vVapow5LNpFT`) — KHÔNG qua Gateway | Độc lập, không nhận traffic từ Gateway |
| **GW Error Knowledge** | `GSz6ZluGT5jCgdEc` | Lưu/tra cứu lỗi đã sửa (`action:"search"`/`"log_fix"`) — hỗ trợ `/error_logs`, `/error_log_now` bên Admin System | Webhook (`/webhook/gw-error-knowledge`) | Gọi từ: Telebot Admin System (qua HTTP), và nên gọi TRƯỚC/SAU khi Claude sửa 1 lỗi (xem RULES.md/PROJECT_STATUS.md) |
| **GW Crawl Bot - Group Capture** | *(ID chưa xác nhận trong bản đồ này — `search_workflows` nếu cần)* | **DƯ THỪA từ 14/09/2026** (xem PROJECT_STATUS.md "phiên tiếp 43") — Gateway đã tự làm việc log/mention, nên deactivate dần, không phát triển thêm | Telegram Trigger, bot **Elite Crawl Bot** | — |
| *(Gateway error workflow)* | `34ccboHpyoY2r691` | Gán ở `settings.errorWorkflow` của Gateway — chạy khi Gateway lỗi thật (exception/crash). Tên đầy đủ CHƯA xác nhận trong bản đồ này | — | Được Gateway gọi tự động khi crash |

## Credential Telegram hay dùng

| Credential (n8n) | ID | Bot thật | Dùng cho |
|---|---|---|---|
| Elite Clickupbot | `BHVAx8GV38yQEn1I` | @Elite_clickup_bot (PROD) | Gateway + mọi tin nhắn cần callback quay lại được Gateway (nút actionable) — xem RULES.md #23 |
| Telegram System Bot | `zSZ6vVapow5LNpFT` | @elite_n8n_system_bot | Telebot Admin System + tin admin KHÔNG có nút actionable (thông báo thuần) |

## Data Table n8n (không phải Postgres)

| Tên | ID | Vai trò |
|---|---|---|
| Gateway Security Settings | `VEnzx8flp68AoKjU` | Công tắc bảo mật link OneDrive: `setting_key=onedrive_link_security`, `setting_value` = `high` (mặc định, chỉ người có quyền mở được) hoặc `low` (link công khai `1drv.ms`). Đọc bởi `Telebot ClickUp Reader` (`9JJRrh36H2rLwtnu`), node `Đọc Công Tắc Bảo Mật` — **lấy dòng có `createdAt` MỚI NHẤT** (`orderBy: createdAt DESC, limit 1`), không phải dòng duy nhất. Đổi trực tiếp trong n8n UI (Data Tables → sửa ô `setting_value` của dòng hiện có) → không cần publish lại. Đổi qua MCP/Claude (vì MCP data-table tool hiện KHÔNG có update/delete row) → **thêm 1 dòng mới** cùng `setting_key`, dòng mới hơn luôn thắng — dòng cũ giữ lại làm lịch sử, không cần xoá. |

## Credential Postgres

| Credential (n8n) | ID | Vai trò |
|---|---|---|
| Postgres account | `GwUFREmcXzXXj5mZ` | Postgres self-hosted (Docker) — DB CHÍNH, chạy thật |
| Supabase Postgres | `hO4yfw7ailV7jHAv` | Supabase — phụ/offsite, một số bảng dual-write |

## Cách AI dùng file này

1. Cần sửa/tra 1 workflow theo TÊN → tra bảng trên lấy `id`, gọi thẳng `get_workflow_details`/
   `update_workflow` — KHÔNG gọi `search_workflows` trước nếu tên đã có trong bảng.
2. Không thấy tên trong bảng → dùng `search_workflows` như bình thường, sau đó **thêm dòng mới
   vào bảng này** (kèm ID xác nhận được) để lần sau khỏi tìm lại.
3. Bảng "Credential" dùng để tránh đoán sai credential khi thêm node Telegram/Postgres mới — đặc
   biệt quan trọng theo RULES.md #23 (gửi nút actionable qua nhầm bot = nút chết, không lỗi).
