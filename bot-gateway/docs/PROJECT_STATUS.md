# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để nắm được trạng thái hiện tại mà
> không cần đọc lại lịch sử debug dài của các phiên trước — file này chỉ giữ TRẠNG THÁI HIỆN TẠI,
> không giữ tường thuật quá trình (tường thuật đầy đủ nằm ở `docs/CHANGELOG.md`, mới nhất lên trên).
>
> **Trước khi sửa bất kỳ workflow nào**: đọc `docs/RULES.md` — đặc biệt mục 12-15 (publish sau khi
> update, tên tham số đúng cho addConnection, batch rollback, bẫy inlineKeyboard động). Đây là 4
> nguyên nhân gây bug im lặng đã gặp NHIỀU LẦN, không phải lý thuyết suông.
>
> Tài liệu khác: `docs/ARCHITECTURE.md` (thiết kế hệ thống + mục 9 nợ kỹ thuật/refactor),
> `docs/GUIDE_SQL_CLICKUP_SYNC.md` (vận hành sync), `docs/GO_LIVE_CHECKLIST.md`,
> `docs/FEATURE_CATALOG.md` (bảng đầy đủ tính năng theo từng bot), `docs/FAQ.md`.
>
> **⚠️ Rủi ro đã xảy ra thật**: 2 phiên chat khác nhau từng sửa CÙNG 1 workflow song song mà không
> biết về nhau, gây lệch dữ liệu (xem CHANGELOG 09/09/2026). Nếu thấy `nodeCount`/`connections` khác
> con số bạn nhớ — ĐỪNG cho là mình nhớ nhầm, hãy đọc lại file này (bản mới nhất trên GitHub, không
> tin bộ nhớ hội thoại) trước khi sửa tiếp.

## Trạng thái theo bot / workflow (09/09/2026)

| Bot / Workflow | Trạng thái | Ghi chú |
|---|---|---|
| **Gateway** (`GW Gateway - Telegram`, `xmEKeIUnzxm2F7dF`) | ✅ Hoạt động, PROD (`@Elite_clickup_bot`) | Auth, router, callback whitelist (`od_`, `odfwd_`, `odhelp`, `chitiet_`, `sync_`) |
| **Telebot ClickUp Reader** (`9JJRrh36H2rLwtnu`, chạy qua Gateway, `bot_key: telebot_main`) | ✅ Hoạt động đầy đủ | `/task`, chi tiết task, Upload OneDrive (chọn tên/preset/tùy chỉnh/giữ gốc, forward thông báo vào nhóm, `/cancel`) — TẤT CẢ đã user xác nhận chạy thật |
| **Bot Xử Lý Ảnh** (`6I4MnJiJCiv2JOIr`, qua Gateway, `bot_key: image_bot`) | 🟡 Đã build thêm, CHƯA test thật | `/xoanen`, `/tomtat` hoạt động OK. MỚI (09/09/2026): sau `/xoanen` (kể cả khi remove.bg lỗi) hiện 3 nút — 🤖 Xoá nền bằng AI (fallback, model `google/gemini-2.5-flash-image` qua OpenRouter), 🔍 Upscale, ❌ Huỷ. **⚠️ CẦN TẠO credential mới trước khi dùng được** — xem mục checklist |
| **Telebot Admin System** (`eWtu7Qs85Hes0HuP`, bot riêng `@elite_n8n_system_bot`) | ✅ Hoạt động đầy đủ | `/task`, `/sync`, `/sync_status`, `/db_status`, `/backup_n8n`, `/backup_db`, `/version`, `/cancel`, `/user_list` (danh sách + panel quản lý quyền đầy đủ 13 route) |
| **SQL - ClickUp Full Reconcile** (`G1R0okF0rUziySu9`) | ✅ Hoạt động, đã fix DKPV/PVTC | Xem mục "DKPV/PVTC" bên dưới |
| **SQL - ClickUp Sync Scheduler** (`loCm8Tg8Sqfj7ygy`) | ✅ Hoạt động | Điều phối đa-List theo `clickup.sync_targets`, chạy mỗi 5 ngày |
| **SQL - ClickUp Live Update (Webhook)** (`uqTqjtHYieotPZuc`) | ✅ Hoạt động, đã fix 2 lỗi | Ghi đè Postgres real-time khi sửa trên ClickUp; thông báo → nhóm topic 2 |
| **SQL - Backup System** (`iVtOA9LEtjpLDkln`) | ✅ Hoạt động | `/backup_*` trả lời trực tiếp admin; chạy tự động (Chủ nhật 2h sáng) báo vào nhóm topic 6 |
| **GW Error Handler** (`34ccboHpyoY2r691`) | ✅ Hoạt động | Báo lỗi vào nhóm topic 4 + ghi `gateway.error_logs` |
| **GW Weekly Error Report** (`ZJvP7L2aVPpeCGGW`, MỚI) | 🟡 Đã build, CHƯA test thật | Thứ 2 8h sáng, DM admin — xem checklist |
| **Help Bot GPT** | ⏳ Code xong, CHƯA gắn Gateway | Chờ Workflow ID thật (placeholder `REPLACE_HELP_BOT_ID`) |
| **Crawl Bot** | ⏳ Chưa bắt đầu | Placeholder `REPLACE_CRAWL_BOT_ID` |
| **Nhóm chat capture + tóm tắt AI** | 🟡 Đã build xong, CHƯA test thật | Ghi log (Gateway) + tóm tắt hàng đêm (`GW Daily Chat Summary`, DeepSeek) + `/lichsu`/`/timkiem` (Admin System). **⚠️ Cần tắt Privacy Mode qua @BotFather** — xem checklist |

## ✅ Đã xác nhận SỬA XONG — Phương án A cho DKPV/PVTC (quyết định 09/09/2026)

Kiểm tra trực tiếp Postgres xác nhận **đã được triển khai đúng, không cần sửa gì thêm**:
- Khóa chính `clickup.task_links` hiện là `(student_task_id, order_task_id, link_type, year)` —
  cho phép 1 đơn hàng xuất hiện ở NHIỀU năm khác nhau (học sinh apply lại) mà không bị lỗi
  "duplicate key" như trước.
- Node `Trích Xuất Task Links` (trong `SQL_ClickUp_Full_Reconcile.json`) nhận diện CẢ `DKPV <năm>`
  lẫn `PVTC <năm>` bằng regex tự động, không hardcode tên field theo năm.
- Đã xác nhận 0 dòng trùng lặp thật trong bảng.

## 🔴 Việc còn tồn đọng thật sự (đã lọc bỏ mục đã xong/lỗi thời)

0. **⚠️ CẦN TẠO CREDENTIAL MỚI để dùng tính năng AI xoá nền/upscale (Bot Xử Lý Ảnh)** — đã build
   xong node gọi OpenRouter Image API (`https://openrouter.ai/api/v1/images`, model
   `google/gemini-2.5-flash-image`, ~$0.0003/ảnh input + ~$0.00003/ảnh output — giá tra trực tiếp
   từ API OpenRouter, không đoán) nhưng 2 node `Call OpenRouter (AI Bỏ Xoá Nền)` và
   `Call OpenRouter (Upscale)` trong workflow `Bot Xử Lý Ảnh` (`6I4MnJiJCiv2JOIr`) CHƯA có
   credential (Claude không tự tạo credential chứa API key được). **User cần**: tạo 1 credential
   loại "Simplified Custom Auth" (`httpTemplatedCustomAuth`) tên gợi ý "OpenRouter HTTP", Auth
   Template `{"headers":{"Authorization":"Bearer {{api_key}}"}}`, dán OpenRouter API key vào ô
   secret — rồi gán credential đó vào ĐÚNG 2 node trên trong n8n UI. **CHƯA test thật** lượt nào
   (cần credential trước, và trigger callback không execute được qua MCP).
1. **Bot Xử Lý Ảnh — vẫn còn "nền trắng"/"chèn logo" CHƯA CÓ SPEC RÕ** (khác với tính năng AI
   xoá nền/upscale ở mục 0, đã có spec rõ và build xong). Cần user cung cấp: tên lệnh, logo lấy từ
   đâu (file cố định hay user gửi kèm), có kết hợp với `/xoanen` không, vị trí/kích thước logo.
2. **Nhóm chat capture + tóm tắt AI** — phạm vi vừa được làm rõ lại (09/09/2026), RỘNG HƠN ý tưởng
   ban đầu. Đã có sẵn 2 bảng SQL cũ (`gateway.group_chat_log`, `gateway.daily_chat_summary`) nhưng
   CHƯA có workflow nào ghi/đọc chúng. Yêu cầu mới nhất gồm:
   - (a) Ghi log MỌI tin nhắn trong các nhóm Telegram bot có mặt (SQL + workflow) — **KHÔNG** tự
     động đẩy tóm tắt hàng ngày cho user (phần "tự động push" bị hoãn lại, chỉ làm phần lưu trữ).
   - (b) Lệnh xem lại tóm tắt lịch sử trò chuyện theo khoảng ngày (1/3/5/7 ngày) — chỉ trả về nội
     dung liên quan tới user hỏi (hoặc toàn bộ hội thoại liên quan tới họ, hoặc lọc theo 1 nhóm cụ
     thể do user chọn).
   - (c) Lệnh tìm kiếm nội dung (full-text) trong lịch sử của 1 nhóm cụ thể.
   - **Trạng thái: đang trong quá trình xây dựng (bắt đầu 09/09/2026) — xem CHANGELOG cùng ngày để
     biết chính xác đã làm tới đâu.**
3. **`GW Weekly Error Report`** (mới tạo 09/09/2026) — chưa test thật qua Telegram (chạy thử sẽ gửi
   tin nhắn thật cho admin nên chưa tự chạy). Cần user tự bấm "Execute workflow" trong n8n để xem
   trước, hoặc đợi tới Thứ 2 tới.
4. **Help Bot GPT** — code đã viết, chưa gắn vào Gateway vì chưa có Workflow ID thật.
5. **Crawl Bot** — chưa bắt đầu (Phase 3 cũ).
6. **`restore.sh`** (script khôi phục thảm họa) — chưa test trên 1 n8n instance trống thật sự.

## 📇 Index thay đổi/lỗi đã fix gần đây (đọc CHANGELOG.md để biết chi tiết đầy đủ từng mục)

Danh sách tra nhanh — mỗi dòng trỏ tới mục tương ứng trong `CHANGELOG.md` (tìm theo ngày/tiêu đề):

- **09/09/2026**: fix nút `/user_list` bị lệch route do 2 phiên sửa song song · phát hiện tên tham
  số đúng cho `addConnection` là `sourceIndex`/`targetIndex` (RULES.md #13) · thêm `/version` ·
  fix Upload OneDrive không hiện nút (bẫy inlineKeyboard động, RULES.md #14) · thêm auto-delete tin
  nhắn cũ (ClickUp Reader + Admin System) · fix bug xóa-tin-trước-khi-gửi-tin-mới do mất envelope ·
  thêm forward thông báo upload vào nhóm/topic (`gateway.notify_targets`) · fix Gateway thiếu
  whitelist `odfwd_`/`odhelp` khiến nút forward không phản hồi · phát hiện lỗi batch-rollback khi 1
  operation lỗi giữa chừng làm mất luôn các operation trước đó trong cùng batch (RULES.md #15) ·
  thêm `/cancel` cho Admin System + nút Hủy cho các menu · sanitize tên file upload (5 từ, không
  emoji/số/ký tự đặc biệt) · định tuyến 3 loại thông báo hệ thống (ClickUp update/lịch/lỗi) vào
  nhóm riêng · phát hiện + fix credential sai (Telegram Dev Bot cũ) trên 4 node backup · phát hiện
  + fix thiếu dấu `=` khiến ghi đè Postgres từ ClickUp Live Update luôn lỗi cú pháp · fix thông báo
  hiện "—" khi task chưa từng đồng bộ vào Postgres · thêm `gateway.error_logs` + workflow
  `GW Weekly Error Report` · xác nhận DKPV/PVTC (Phương án A) đã được 1 phiên trước làm đúng.
- **08/09/2026**: cutover PROD bot toàn bộ · `/xoanen` + `/tomtat` test thật OK · chuyển OCR sang
  Mistral native · backup Postgres qua SSH thật (pg_dump) · redesign format `/task chitiet_<id>` ·
  fix credential sai bot ở nhiều node · xây `Telebot Admin System` tách riêng bot admin.
- **Trước 08/09/2026**: xem trực tiếp `CHANGELOG.md` — các mốc Phase 0-3 (schema DB, Gateway, Full
  Reconcile, Live Update, Sync Scheduler) đều đã hoàn tất và đang chạy ổn định.

## Repo

`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua `gh` CLI (đã auth sẵn trong môi
trường Claude Code) hoặc Composio (OAuth) tuỳ phiên.

## Cấu trúc repo hiện tại

```
bot-gateway/
├── README.md
├── docs/
│   ├── CHANGELOG.md          <- lịch sử thay đổi chi tiết theo ngày (nguồn sự thật đầy đủ)
│   ├── PROJECT_STATUS.md     <- file này (trạng thái hiện tại + index tra nhanh)
│   ├── ARCHITECTURE.md       <- thiết kế hệ thống + mục 9: nợ kỹ thuật/refactor
│   ├── RULES.md              <- quy tắc bắt buộc, ĐỌC TRƯỚC khi sửa workflow (15 mục)
│   ├── FEATURE_CATALOG.md    <- bảng đầy đủ tính năng theo từng bot
│   ├── BOT_INVENTORY.md, GUIDE_DEPLOY_DATABASE.md, SETUP_PHASE_0_1.md
│   ├── GUIDE_SQL_CLICKUP_SYNC.md, GO_LIVE_CHECKLIST.md, FAQ.md
├── sql/
│   ├── 01_gateway_schema.sql, 02_clickup_tasks_schema.sql
│   ├── 03_gateway_changelog.sql          <- bảng cho lệnh /version
│   ├── 04_gateway_notify_targets.sql     <- cấu hình forward OneDrive
│   ├── 05_gateway_notify_targets_system.sql  <- cấu hình thông báo hệ thống
│   └── 06_gateway_error_logs.sql         <- log lỗi cho Weekly Error Report
├── scripts/restore.sh        <- khôi phục thảm họa, CHƯA test trên instance trống
├── original/                 5 workflow production NGUYÊN BẢN (tham khảo, không sửa)
└── workflows/new_architecture/
    ├── GW_Gateway_Telegram.json, GW_Error_Handler.json
    ├── SQL_ClickUp_Full_Reconcile.json, SQL_ClickUp_Sync_Scheduler.json,
    │   SQL_ClickUp_Live_Update.json
    └── sub_workflows_modernized/
        ├── Elite_Help_Bot_GPT.json        (chờ Workflow ID để gắn Gateway)
        ├── Telebot_ClickUp_Reader.json    (đang dùng)
        ├── Telebot_Admin_System.json      (đang dùng, bot riêng)
        └── Bot_Image_Processing.json      (đang dùng, /xoanen + /tomtat)
```

## Ghi nhớ kỹ thuật quan trọng nhất

Đã chuyển toàn bộ vào `docs/RULES.md` (15 mục, cập nhật liên tục) để tránh trùng lặp nội dung giữa
2 file. Luôn đọc RULES.md trước khi sửa bất kỳ workflow nào — đặc biệt các mục về ClickUp node dùng
tham số phẳng (không phải resource-locator), `SplitInBatches`, và 4 bẫy kỹ thuật mới phát hiện
09/09/2026 (mục 12-15).
