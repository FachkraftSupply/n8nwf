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
| `/cancel` + nút ❌ Hủy | Hủy 1 luồng Upload OneDrive đang dở (đang chờ chọn tên/chờ gửi file) | Callback `od_cancel` hoặc lệnh gõ tay → DELETE dòng `clickup.pending_uploads` của chat đó | 2026-09-09 |
| `/lichsu` + `/timkiem` (bản User, CÓ LỌC) | Xem lại tóm tắt chat nhóm / tìm tin nhắn gốc theo từ khóa — CHỈ thấy/tìm được nhóm mà CHÍNH user đó từng nhắn tin (lọc theo `user_id`, kể cả cố gõ tay `chat_id` nhóm khác cũng không thấy) | Bấm nút chọn số ngày → chọn nhóm (deep-link) → đọc `gateway.daily_chat_summary`/`group_chat_log` có `EXISTS` join lọc theo `user_id` | 2026-09-09 |
| `/sum` | Tóm tắt nhanh tất cả nhóm của user từ đầu tuần (Thứ 2) tới giờ | Query `gateway.daily_chat_summary` lọc theo user, gộp nhiều nhóm | 2026-09-09 |
| **📤 Upload OneDrive** | Nút trên tin chi tiết task (chỉ hiện nếu task có `onedrive_link`) → chọn tên file (5 preset BAV/Kammer/EZB/Schulbestätigung/Spateinstieg + tên học sinh, hoặc tên tùy chỉnh, hoặc giữ tên gốc) → gửi file → bot upload lên đúng folder OneDrive của task | Callback `od_start_/od_q_/od_custom_/od_orig_` → lưu state `clickup.pending_uploads` (nay có thêm `student_name`, `task_url` "đi nhờ" tới bước forward) → Gateway ép route file/tin nhắn tiếp theo về workflow này → resolve `onedrive_link` (share URL) qua Microsoft Graph `GET /shares/{id}/driveItem` → tải file Telegram → `PUT /drives/{driveId}/items/{itemId}:/{tên file}:/content` | 2026-09-08 (build) → ✅ hoạt động thật 09/09/2026, có `/cancel` + nút ❌ Hủy để xóa dở dang |
| 📨 Forward thông báo upload vào nhóm + Zalo | Sau khi upload xong, admin bấm 1 trong 3 nút (🏛️ Kammer/BAV, 🧾 Hóa đơn, 📄 Giấy tờ khác) → gửi thông báo CHI TIẾT (người upload, tên file, học sinh — hyperlink, giờ upload, link) vào đúng nhóm/topic Telegram phụ trách loại giấy tờ đó, ĐỒNG THỜI mirror sang 1 nhóm Zalo nếu đã cấu hình `zalo_chat_id` | Callback `odfwd_<queueId>_<targetId>` → tra `clickup.upload_notify_queue` (có `uploader_name`/`student_name`/`task_url`) + `gateway.notify_targets` (có `zalo_chat_id`) → gửi Telegram (`chat_id`/`topic_id`, tên học sinh hyperlink `chitiet_<id>`) + gửi Zalo song song (`POST bot-api.zaloplatforms.com/bot<token>/sendMessage`, tên học sinh hyperlink ClickUp URL) → hashtag tự động theo loại giấy tờ (`#BAV`/`#Kammer`/`#EZB`/.../`#GIAYTOKHAC` nếu tên tùy chỉnh/giữ gốc) + `#CapNhatHoSo`. Mở rộng thêm nhóm Telegram chỉ cần INSERT 1 dòng vào `notify_targets`, không cần sửa code | 2026-09-09 — **✅ TEST THẬT OK CẢ TELEGRAM LẪN ZALO** (user xác nhận nhận được tin ở cả 2 nền tảng, xem PROJECT_STATUS.md). Token Zalo hardcode trực tiếp trong node `Send Zalo Notify` (n8n Community, không dùng env var được — xem RULES.md #17 về redact trước khi commit) |

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
| **`/user_list`** (alias `/users`) — danh sách user | Liệt kê tối đa 25 user gần nhất kèm trạng thái/quyền | Query `gateway.bot_users` JOIN `bot_permissions` | 2026-09-08 (tối), fix routing 2 lớp cùng ngày → ✅ hoạt động đầy đủ, đã xác nhận |
| `/cancel` + nút ❌ Hủy (Admin System) | Hủy panel/menu đang thao tác dở | Xóa trạng thái tạm liên quan, trả lời "❌ Đã hủy" | 2026-09-09 |
| `/lichsu` (bản Admin, mọi nhóm) + `/timkiem` | Xem tóm tắt chat MỌI nhóm (không lọc, chỉ admin) theo số ngày, hoặc tìm tin nhắn gốc theo `chat_id`+từ khóa | Bấm nút chọn ngày → chọn nhóm (deep-link) → đọc `gateway.daily_chat_summary`/`group_chat_log`, không lọc user vì admin được xem hết | 2026-09-09 |
| `/error_logs` (xem) + `/error_log_now` (xem + đánh dấu đã xử lý) | Xem nhanh lỗi tuần qua ngay lập tức (không cần đợi Thứ 2 hoặc vào n8n UI), kèm sẵn 1 prompt copy thẳng vào Claude Code để sửa | Query `gateway.error_logs`, `/error_log_now` thêm `UPDATE status='reported'` | 2026-09-09 |
| **Panel chi tiết 1 user** (bấm từ danh sách) | Xem chi tiết + quản lý quyền 1 user cụ thể | Callback `um:<uid>` → query `bot_users`+`bot_permissions` 1 user → hiện panel với 6 nút thao tác (bên dưới) | 2026-09-08 (tối) |
| ➕ Thêm quyền (menu chọn bot) | Chọn 1 trong 4 bot để cấp thêm quyền cho user | Callback `ga:<uid>` → menu → `gc:<uid>:<bot>` → INSERT `bot_permissions` (dual-write) | 2026-09-08 (tối) |
| ➖ Xóa quyền (menu chọn bot) | Thu hồi 1 quyền cụ thể đã cấp | Callback `rv:<uid>` → menu → `rc:<uid>:<bot>` → DELETE khỏi `bot_permissions` (dual-write) | 2026-09-08 (tối) |
| ⚡ Cấp tất cả quyền | 1 nút cấp thẳng cả 4 bot cùng lúc, không cần chọn từng cái | Callback `gall:<uid>` → INSERT `bot_permissions` cho cả 4 bot_key (dual-write) | 2026-09-08 (tối, phiên 3), thuộc bộ 13 route `/user_list` đã hoạt động đầy đủ 09/09 |
| ⛔ Block user | Chặn truy cập 1 user đang active (khác "Từ chối" — dành cho user MỚI xin quyền) | Callback `bl:<uid>` → UPDATE `status='blocked'` (dual-write); Gateway tự coi mọi status khác active/pending là bị chặn, không cần sửa thêm | 2026-09-08 (tối, phiên 3) |
| 🗑️ Xóa hoàn toàn user | Xóa vĩnh viễn record user khỏi hệ thống, có bước xác nhận vì không thể hoàn tác | Callback `dl:<uid>` → panel xác nhận (✅/❌) → `dlc:<uid>` mới thực sự DELETE `bot_users`+`bot_permissions` (dual-write) | 2026-09-08 (tối, phiên 3) |
| ⬅️ Quay lại danh sách | Điều hướng quay lại `/user_list` từ bất kỳ panel con nào | Callback `ub` | 2026-09-08 (tối) |
| **`/version`** | Xem phiên bản hiện tại + các thay đổi gần nhất, link sang file này | Query bảng `gateway.changelog` (seed v1-v8), chỉ admin (`Check Admin (Version)`) | 2026-09-09 |

## 5. Workflow nền (không có lệnh Telegram trực tiếp, chạy tự động)

| Workflow | Vai trò | Bot dùng để thông báo | Cập nhật |
|---|---|---|---|
| `GW Error Handler` (`34ccboHpyoY2r691`) | Bắt lỗi từ MỌI workflow khác (gán qua `errorWorkflow` setting), báo ngay + ghi vào `gateway.error_logs` để tổng hợp hàng tuần | Nhóm hệ thống, topic lỗi | 2026-09-03, gửi nhóm+lưu DB 09/09/2026 |
| **`GW Weekly Error Report`** (`ZJvP7L2aVPpeCGGW`) | Mỗi Thứ 2 8h sáng, tổng hợp lỗi 7 ngày qua từ `gateway.error_logs` theo workflow, gửi riêng cho admin để chạy Claude Code rà soát/sửa | @elite_n8n_system_bot (nhắn riêng admin) | 2026-09-09 — build xong, tương đương đã có `/error_logs`+`/error_log_now` để test ngay không cần đợi Thứ 2 |
| `SQL - ClickUp Live Update (Webhook)` (`uqTqjtHYieotPZuc`) | Nghe sự kiện ClickUp (task update/comment) real-time, ghi đè Postgres tương ứng, báo admin tin "🔄 CẬP NHẬT Task" vào nhóm topic 2 | @elite_n8n_system_bot | 2026-09-05, định tuyến nhóm/topic 09/09 |
| `SQL - ClickUp Full Reconcile` (`G1R0okF0rUziySu9`) | "Engine" đồng bộ 1 List ClickUp ↔ Postgres đầy đủ (dùng bởi `/sync` và Scheduler); DKPV/PVTC nhận diện theo năm bằng regex | — (không tự gửi Telegram, được gọi bởi workflow khác) | 2026-09-06 (khuya), xác nhận DKPV/PVTC đúng 09/09 |
| `SQL - ClickUp Sync Scheduler` (`loCm8Tg8Sqfj7ygy`) | Điều phối tự động đồng bộ NHIỀU List theo lịch (mỗi 5 ngày), đọc `clickup.sync_targets` | — | 2026-09-06 (khuya, tách riêng khỏi Full Reconcile) |
| `SQL - Backup System (n8n + Postgres)` (`iVtOA9LEtjpLDkln`) | Backup n8n + Postgres lên OneDrive; `/backup_*` trả lời trực tiếp admin, chạy tự động Chủ nhật 2h sáng báo vào nhóm topic 6 | @elite_n8n_system_bot (báo kết quả) | 2026-09-08, định tuyến nhóm/topic 09/09 |
| `GW Error Handler` (`34ccboHpyoY2r691`) | Bắt lỗi từ MỌI workflow khác (`errorWorkflow` setting), báo vào nhóm topic 4 + ghi `gateway.error_logs` | Nhóm hệ thống, topic 4 | 2026-09-03, ghi DB+định tuyến topic 09/09 |
| **`GW Crawl Bot - Group Capture`** (`SNNrXneenXVnLHh6`) | Bot riêng (`Elite Crawl Bot`) lắng nghe MỌI tin nhắn thường trong nhóm bot có mặt, ghi vào `gateway.group_chat_log` (giữ 14 ngày) — nền tảng cho `/lichsu`/`/timkiem`/`/sum` | Ghi log âm thầm, không phản hồi user | 2026-09-09 |
| **`GW Daily Chat Summary`** (`ElSGQgdHPMtrzwME`) | Chạy 1h sáng mỗi ngày: tóm tắt `group_chat_log` của từng nhóm bằng AI (DeepSeek) → `gateway.daily_chat_summary` (giữ 365 ngày); kèm dọn dữ liệu cũ tự động | AI tóm tắt, không gửi Telegram trực tiếp (dữ liệu được `/lichsu`/`/sum` đọc lại) | 2026-09-09 build → 10/09 fix 2 bug thật (lệch múi giờ + queryBatching), xác nhận chạy thật ra kết quả đúng — CHƯA test đường đọc lại `/lichsu`/`/sum` qua Telegram |

## 6. Bot/bot_key CHƯA hoàn thiện (placeholder, đã khai báo route nhưng chưa gắn workflow thật)

| bot_key | Lệnh dự kiến | Trạng thái | Ghi chú |
|---|---|---|---|
| `help_bot` | `/ask`, tin nhắn tự do (DEFAULT_BOT) | ⏳ Chờ Workflow ID thật (`REPLACE_HELP_BOT_ID`) | Sub-workflow `Elite_Help_Bot_GPT.json` đã viết code, chưa gắn vào Gateway |
| ~~`crawl_bot`~~ | ~~`/sum`, `/crawl`~~ | ❌ Đã bỏ hẳn 09/09/2026 | `/crawl` không còn tồn tại. Ý tưởng gốc ("bot lắng nghe + ghi Postgres") chính là tính năng `GW Crawl Bot - Group Capture` ở mục 5 — không phải 2 việc khác nhau, không cần xây thêm gì |
| **AI xóa nền / Upscale** (Bot Xử Lý Ảnh) | `🤖 Xóa nền bằng AI` / `🔍 Upscale` (nút trên kết quả `/xoanen`) | ⏸️ TẠM DEACTIVATE 09/09/2026 | Đã build xong (OpenRouter Image API), 2 node + 2 nút đang bị tắt vì thiếu credential đúng loại (Simplified Custom Auth) — chờ user tạo credential rồi bật lại, xem PROJECT_STATUS.md |

---

**Cách cập nhật file này**: mỗi khi thêm/sửa 1 tính năng có ảnh hưởng tới user hoặc admin, thêm 1
dòng mới vào đúng bảng bot liên quan, cột "Cập nhật" ghi ngày phiên làm việc (định dạng
`YYYY-MM-DD`, thêm `(tối)`/`(khuya)`/số thứ tự phiên trong ngày nếu cần phân biệt nhiều đợt cùng
ngày — theo đúng quy ước `CHANGELOG.md`). Không xoá dòng cũ khi tính năng bị thay thế — sửa cột mô
tả kèm ghi chú "đã thay bằng X" để giữ lịch sử.
