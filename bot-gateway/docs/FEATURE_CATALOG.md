# FEATURE CATALOG — Bảng thống kê toàn bộ tính năng theo bot

> Mục đích: 1 nơi duy nhất trả lời "tính năng X thuộc bot nào, hoạt động ra sao, nằm ở workflow
> nào, thêm từ bao giờ". Đây là nguồn dữ liệu dự kiến dùng cho lệnh `/version` (chưa build — xem
> `PROJECT_STATUS.md` mục backlog) một khi tính năng đó hoàn thành.
>
> **Về "phiên bản"**: dự án hiện CHƯA có hệ version số hình thức (v1.0, v1.1...). Cột "Cập nhật"
> dùng ngày thật lấy từ `CHANGELOG.md`/lịch sử phiên chat, theo đúng quy ước đang dùng trong repo.
> Khi lệnh `/version` được build, có thể gán lại thành version số dựa theo thứ tự ngày ở đây.

## 1. Bot Gateway — @Elite_clickup_bot (PROD) / @elite_n8n_test_bot (DEV cũ)

**Vai trò**: cổng vào DUY NHẤT cho user thường (không phải admin). 1 Telegram Trigger duy nhất,
tự làm xác thực + định tuyến sang đúng bot con (`bot_key`) theo lệnh gõ vào. User không thấy sự
khác biệt — vẫn nhắn 1 bot như cũ, "bộ não" phía sau là Gateway.
**Workflow**: `GW Gateway - Telegram (DEV)` (n8n ID `xmEKeIUnzxm2F7dF`)

| Tính năng | Mô tả | Cách hoạt động | Cập nhật |
|---|---|---|---|
| Xác thực user (auth) | Kiểm tra user đã được cấp quyền hay chưa mỗi khi nhắn tin | Tra `gateway.bot_users` + `gateway.bot_permissions` theo `user_id`; phân loại `new`/`pending`/`denied`/`active` | 2026-09-03 (Phase 0-1) |
| Tự tạo user mới (self-onboarding) | User lạ nhắn bot lần đầu → tự tạo record `pending`, báo admin duyệt | INSERT `gateway.bot_users` (dual-write Postgres Docker + Supabase) + gửi tin "🆕 USER MỚI XIN QUYỀN" cho admin kèm nút duyệt nhanh (telebot_main/help_bot/crawl_bot/TẤT CẢ/Từ chối) | 2026-09-03 |
| Duyệt/từ chối user (từ phía admin, qua callback) | Admin bấm nút trên tin "🆕 USER MỚI..." → cấp quyền hoặc từ chối ngay, không cần mở bot riêng | Callback `ap:<uid>:<bot>` / `dn:<uid>:-` → UPDATE status + INSERT `bot_permissions` (dual-write) → báo lại cho cả admin và user | 2026-09-03, sửa bug bot gửi nhầm 08/09/2026 (xem bên dưới) |
| Định tuyến lệnh → bot con (Router) | `/task`, `/ask`, `/sum`, `/xoanen`... tự động chuyển tới đúng sub-workflow xử lý | `COMMAND_MAP` trong node `⚙️ Config` ánh xạ lệnh → `bot_key`; callback nhận diện qua prefix (`chitiet_`, `sync_`, `od_`...) | 2026-09-03, mở rộng dần mỗi khi thêm lệnh mới |
| Audit log mọi tương tác | Ghi lại toàn bộ tin nhắn/callback vào DB để tra cứu khi debug (`request_id` xuyên suốt) | INSERT `gateway.interaction_logs` (dual-write, dù nhánh "Supabase" hiện đang trỏ nhầm cùng credential Docker — biết nhưng chưa sửa vì không ảnh hưởng chức năng) | 2026-09-03 |
| Chờ upload OneDrive (pending state) | Nhớ tạm "user đang giữa chừng 1 lượt upload file" để tin nhắn/tài liệu tiếp theo không bị lạc sang bot khác | Bảng mới `clickup.pending_uploads` (chat_id, task_id, filename, mode) — tra ngay sau bước auth, ép route về `telebot_main` nếu có pending | 2026-09-08 (tối, cùng đợt Upload OneDrive) — ⚠️ đã gây sự cố ngừng toàn bộ phản hồi bot do thiếu `alwaysOutputData`, đã vá cùng ngày |

## 2. Telebot ClickUp Reader (bot_key: `telebot_main`) — chạy sau Gateway, KHÔNG có bot riêng

**Vai trò**: tra cứu task ClickUp qua Postgres (không gọi trực tiếp ClickUp API) + (mới) upload file
lên OneDrive gắn với task.
**Workflow**: `Telebot ClickUp Reader` (n8n ID `9JJRrh36H2rLwtnu`)

| Tính năng | Mô tả | Cách hoạt động | Cập nhật |
|---|---|---|---|
| `/task <từ khóa>` — tìm task | Trả danh sách tối đa 10 task khớp từ khóa (full-text search, không dấu) | `clickup.tasks` (`ts_rank` + `ILIKE` fallback), kèm link OneDrive/ClickUp nếu có | 2026-09-06 (revamp), full-text search bổ sung sau |
| `chitiet_<id>` — xem chi tiết task | Deep-link `https://t.me/<bot>?start=chitiet_<id>` (KHÔNG dùng inline keyboard, theo RULES.md) mở tin nhắn chi tiết 1 task | Query `clickup.tasks` + `clickup.task_links` (nhóm theo năm DKPV/PVTC), format HTML | 2026-09-06 |
| `/help` | Danh sách lệnh khả dụng cho user thường | Code node dựng text tĩnh | 2026-09-06 |
| **📤 Upload OneDrive** | Nút trên tin chi tiết task (chỉ hiện nếu task có `onedrive_link`) → chọn tên file (5 preset BAV/Kammer/EZB/Schulbestätigung/Spateinstieg + tên học sinh, hoặc tên tùy chỉnh, hoặc giữ tên gốc) → gửi file → bot upload lên đúng folder OneDrive của task | Callback `od_start_/od_q_/od_custom_/od_orig_` → lưu state `clickup.pending_uploads` → Gateway ép route file/tin nhắn tiếp theo về workflow này → resolve `onedrive_link` (share URL) qua Microsoft Graph `GET /shares/{id}/driveItem` → tải file Telegram → `PUT /drives/{driveId}/items/{itemId}:/{tên file}:/content` | 2026-09-08 (tối, build) → **✅ FIX XONG + hoạt động thật 09/09/2026** (bẫy inlineKeyboard động, xem RULES.md #14 — chi tiết đầy đủ trong PROJECT_STATUS.md, mục này chỉ cập nhật trạng thái cuối cùng, không lặp lại quá trình debug) |
| 📨 Forward thông báo upload vào nhóm | Sau khi upload xong, admin bấm 1 trong 3 nút (🏛️ Kammer/BAV, 🧾 Hóa đơn, 📄 Giấy tờ khác) để gửi lại thông báo (tên file + link) vào đúng nhóm/topic Telegram phụ trách loại giấy tờ đó | Callback `odfwd_<queueId>_<targetId>` → tra `clickup.upload_notify_queue` + `gateway.notify_targets` → gửi Telegram vào `chat_id`/`topic_id` cấu hình sẵn, mở rộng thêm nhóm chỉ cần INSERT 1 dòng vào `notify_targets`, không cần sửa code | 2026-09-09 |
| 🇻🇳 Mirror thông báo forward sang nhóm Zalo (MỚI) | Khi forward thông báo upload vào 1 nhóm Telegram (mục trên), ĐỒNG THỜI gửi thêm cùng nội dung sang 1 nhóm Zalo tương ứng nếu đã cấu hình | Cột mới `gateway.notify_targets.zalo_chat_id` (tự tạo qua node "Ensure Zalo Notify Column") → node `Has Zalo Target?` (IF) → `Send Zalo Notify` (HTTP Request `POST https://bot-api.zaloplatforms.com/bot<TOKEN>/sendMessage`, token đọc từ biến môi trường `ZALO_BOT_TOKEN`, best-effort không chặn luồng chính nếu lỗi) | 2026-09-09 — **⚠️ ĐÃ BUILD, CHƯA HOẠT ĐỘNG**: thiếu `ZALO_BOT_TOKEN` (biến môi trường, user tự thêm vào docker-compose n8n) và `zalo_chat_id` thật cho từng category (user cung cấp sau khi thêm bot Zalo vào nhóm) — xem PROJECT_STATUS.md |

## 3. Bot Xử Lý Ảnh (bot_key: `image_bot`) — chạy sau Gateway, KHÔNG có bot riêng

**Vai trò**: xử lý ảnh gửi kèm caption lệnh.
**Workflow**: `Bot Xử Lý Ảnh (xoanen + tomtat)` (n8n ID `6I4MnJiJCiv2JOIr`)

| Tính năng | Mô tả | Cách hoạt động | Cập nhật |
|---|---|---|---|
| `/xoanen` (caption kèm ảnh) — xóa nền ảnh | Nhận ảnh, xóa nền, trả lại file `.png` giữ trong suốt | Gọi API remove.bg (credential `REMOVE.BG`), gửi lại bằng Telegram document | 2026-09-08 (tối) — TEST THẬT OK |
| `/tomtat` (caption kèm ảnh) — OCR + tóm tắt | Đọc chữ trong ảnh rồi tóm tắt nội dung bằng AI | OCR qua node gốc `mistralAi` (`extractText`, đọc `pages[0].markdown`) → tóm tắt bằng model `google/gemini-3.5-flash-lite` (qua node tên "Mistral (qua OpenRouter)" — TÊN NODE GÂY NHẦM LẪN, model thật là Gemini) | 2026-09-08 (tối) — build xong, cần 1 lượt test cuối xác nhận field OCR đúng |

## 4. Telebot Admin System — @elite_n8n_system_bot (bot admin riêng, KHÔNG qua Gateway)

**Vai trò**: mọi tính năng chỉ dành cho admin (chat_id `975005174`, hardcode, kiểm tra 2 nơi trong
workflow). Có Telegram Trigger RIÊNG, độc lập hoàn toàn với Gateway.
**Workflow**: `Telebot Admin System (System Bot dedicated)` (n8n ID `eWtu7Qs85Hes0HuP`)

| Tính năng | Mô tả | Cách hoạt động | Cập nhật |
|---|---|---|---|
| `/task <từ khóa>` + `chitiet_<id>` | Giống hệt bản user thường nhưng chạy trên bot admin riêng | Query `clickup.tasks`/`clickup.task_links`, format HTML | 2026-09-07 |
| `/help` | Danh sách lệnh admin | Text tĩnh, liệt kê mọi mục dưới đây | 2026-09-07, cập nhật dần mỗi khi thêm lệnh |
| `/sync` (chọn Folder→List→Đồng bộ ngay) | Admin chọn 1 List ClickUp để đồng bộ dữ liệu về Postgres, có thể bật auto-sync định kỳ | Deep-link từng bước (Folder→List) → lưu `clickup.sync_targets` → gọi `SQL - ClickUp Full Reconcile` | 2026-09-06 (tối), hoạt động ổn định từ 2026-09-07 |
| `/sync_status` | Xem danh sách List đang được auto-sync | Query `clickup.sync_targets` | 2026-09-07 |
| `/db_status` | Thống kê nhanh số lượng task/dữ liệu hiện có trong DB | Query đếm `clickup.tasks` theo điều kiện | 2026-09-07 |
| `/backup_n8n` | Backup toàn bộ workflow n8n lên OneDrive | Gọi sang `SQL_Backup_System.json` với `backupType:'n8n'` | 2026-09-08 |
| `/backup_db` | Backup Postgres (pg_dump thật qua SSH) lên OneDrive | Gọi sang `SQL_Backup_System.json` với `backupType:'db'`, SSH vào VPS chạy `docker exec ... pg_dump` | 2026-09-08 — HOÀN TẤT, test thật OK |
| **`/user_list`** (alias `/users`) — danh sách user | Liệt kê tối đa 25 user gần nhất kèm trạng thái/quyền | Query `gateway.bot_users` JOIN `bot_permissions` | 2026-09-08 (tối) — **routing bị lỗi 2 lớp (IF/Switch nối sai output), đã sửa cùng ngày, cần user xác nhận lại** |
| **Panel chi tiết 1 user** (bấm từ danh sách) | Xem chi tiết + quản lý quyền 1 user cụ thể | Callback `um:<uid>` → query `bot_users`+`bot_permissions` 1 user → hiện panel với 6 nút thao tác (bên dưới) | 2026-09-08 (tối) |
| ➕ Thêm quyền (menu chọn bot) | Chọn 1 trong 4 bot để cấp thêm quyền cho user | Callback `ga:<uid>` → menu → `gc:<uid>:<bot>` → INSERT `bot_permissions` (dual-write) | 2026-09-08 (tối) |
| ➖ Xóa quyền (menu chọn bot) | Thu hồi 1 quyền cụ thể đã cấp | Callback `rv:<uid>` → menu → `rc:<uid>:<bot>` → DELETE khỏi `bot_permissions` (dual-write) | 2026-09-08 (tối) |
| ⚡ Cấp tất cả quyền (MỚI) | 1 nút cấp thẳng cả 4 bot cùng lúc, không cần chọn từng cái | Callback `gall:<uid>` → INSERT `bot_permissions` cho cả 4 bot_key (dual-write) | 2026-09-08 (tối, phiên 3) — CHƯA TEST |
| ⛔ Block user (MỚI) | Chặn truy cập 1 user đang active (khác "Từ chối" — dành cho user MỚI xin quyền) | Callback `bl:<uid>` → UPDATE `status='blocked'` (dual-write); Gateway tự coi mọi status khác active/pending là bị chặn, không cần sửa thêm | 2026-09-08 (tối, phiên 3) — CHƯA TEST |
| 🗑️ Xóa hoàn toàn user (MỚI) | Xóa vĩnh viễn record user khỏi hệ thống, có bước xác nhận vì không thể hoàn tác | Callback `dl:<uid>` → panel xác nhận (✅/❌) → `dlc:<uid>` mới thực sự DELETE `bot_users`+`bot_permissions` (dual-write) | 2026-09-08 (tối, phiên 3) — CHƯA TEST, khuyến nghị thử trên user không quan trọng trước |
| ⬅️ Quay lại danh sách | Điều hướng quay lại `/user_list` từ bất kỳ panel con nào | Callback `ub` | 2026-09-08 (tối) |
| **`/version`** (MỚI) | Xem phiên bản hiện tại + các thay đổi gần nhất, link sang file này | Query bảng mới `gateway.changelog` (seed v1-v8), chỉ admin (`Check Admin (Version)`) | 2026-09-09 — CHƯA TEST |

## 5. Workflow nền (không có lệnh Telegram trực tiếp, chạy tự động)

| Workflow | Vai trò | Bot dùng để thông báo | Cập nhật |
|---|---|---|---|
| `GW Error Handler` (`34ccboHpyoY2r691`) | Bắt lỗi từ MỌI workflow khác (gán qua `errorWorkflow` setting), báo ngay + ghi vào `gateway.error_logs` để tổng hợp hàng tuần | Nhóm hệ thống, topic lỗi | 2026-09-03, gửi nhóm+lưu DB 09/09/2026 |
| **`GW Weekly Error Report`** (`ZJvP7L2aVPpeCGGW`, MỚI) | Mỗi Thứ 2 8h sáng, tổng hợp lỗi 7 ngày qua từ `gateway.error_logs` theo workflow, gửi riêng cho admin để chạy Claude Code rà soát/sửa | @elite_n8n_system_bot (nhắn riêng admin) | 2026-09-09 — CHƯA TEST |
| `SQL - ClickUp Live Update (Webhook)` (`uqTqjtHYieotPZuc`) | Nghe sự kiện ClickUp (task update/comment) real-time, ghi đè Postgres tương ứng, báo admin tin "🔄 CẬP NHẬT Task" | @elite_n8n_system_bot | 2026-09-05 |
| `SQL - ClickUp Full Reconcile` | "Engine" đồng bộ 1 List ClickUp ↔ Postgres đầy đủ (dùng bởi `/sync` và Scheduler) | — (không tự gửi Telegram, được gọi bởi workflow khác) | 2026-09-06 (khuya) |
| `SQL - ClickUp Sync Scheduler` | Điều phối tự động đồng bộ NHIỀU List theo lịch, đọc `clickup.sync_targets` | — | 2026-09-06 (khuya, tách riêng khỏi Full Reconcile) |
| `SQL - Backup System (n8n + Postgres)` (`iVtOA9LEtjpLDkln`) | Backup n8n + Postgres lên OneDrive, chạy thủ công (từ `/backup_*`) hoặc lịch Chủ nhật 2h sáng | @elite_n8n_system_bot (báo kết quả) | 2026-09-08 |

## 6. Bot/bot_key CHƯA hoàn thiện (placeholder, đã khai báo route nhưng chưa gắn workflow thật)

| bot_key | Lệnh dự kiến | Trạng thái | Ghi chú |
|---|---|---|---|
| `help_bot` | `/ask`, tin nhắn tự do (DEFAULT_BOT) | ⏳ Chờ Workflow ID thật (`REPLACE_HELP_BOT_ID`) | Sub-workflow `Elite_Help_Bot_GPT.json` đã viết code, chưa gắn vào Gateway |
| `crawl_bot` | `/sum`, `/crawl` | ⏳ Chờ workflow (`REPLACE_CRAWL_BOT_ID`) | "Chuyển Crawl Bot" — Phase 3, chưa bắt đầu |

---

**Cách cập nhật file này**: mỗi khi thêm/sửa 1 tính năng có ảnh hưởng tới user hoặc admin, thêm 1
dòng mới vào đúng bảng bot liên quan, cột "Cập nhật" ghi ngày phiên làm việc (định dạng
`YYYY-MM-DD`, thêm `(tối)`/`(khuya)`/số thứ tự phiên trong ngày nếu cần phân biệt nhiều đợt cùng
ngày — theo đúng quy ước `CHANGELOG.md`). Không xoá dòng cũ khi tính năng bị thay thế — sửa cột mô
tả kèm ghi chú "đã thay bằng X" để giữ lịch sử.
