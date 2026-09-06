# CHANGELOG — Bot Gateway (bàn giao sang phiên chat mới đọc `docs/PROJECT_STATUS.md`)

Ghi theo ngày, mới nhất lên trên. Chỉ ghi thay đổi có ý nghĩa (workflow/schema/kiến trúc),
không ghi từng lần sửa lỗi vặt trong 1 phiên debug — xem chi tiết trong PROJECT_STATUS.md
nếu cần.

## 2026-09-05
- **SQL_ClickUp_Full_Reconcile.json — bản FINAL, 18 node.** Gộp toàn bộ fix sau nhiều vòng
  test thực tế với n8n live:
  - Node ClickUp native dùng **tham số phẳng** (`team: "..."`, `list: "={{ }}"`), KHÔNG dùng
    resource-locator `{__rl:true,...}` — sai định dạng này là nguyên nhân gốc rễ của hầu hết
    lỗi ClickUp node gặp phải trước đó.
  - `ClickUp - Get Comments` bắt buộc cần vòng lặp `SplitInBatches(batchSize=1)` bao ngoài —
    node này không tự lặp qua nhiều item như phần lớn node khác.
  - Ensure Schema đổi từ `CREATE TABLE` sang `ALTER TABLE ADD COLUMN IF NOT EXISTS` (bảng đã
    tồn tại từ trước) + ép cột `id` về `TEXT` (ClickUp đổi định dạng ID sang chữ+số).
  - Bật `pg_trgm` cho tìm kiếm mờ (Phương án A đã chọn, xem PROJECT_STATUS).
  - Thêm thống kê cuối theo List + Status kèm emoji trong thông báo Telegram.
  - **Xóa** `SQL_ClickUp_Full_Reconcile_v2_simplified.json` và `SQL_ClickUp_to_Postgres_Sync.json`
    (bản nháp/superseded) — từ giờ chỉ dùng 1 file `SQL_ClickUp_Full_Reconcile.json` duy nhất.

## 2026-09-04
- Dựng `Telebot_ClickUp_Reader.json` (26 node) thay thế hoàn toàn `Telebot_main.json` (72 node,
  chưa từng import lên n8n live) — đọc/tìm task ClickUp + xem file OneDrive từ comment.
- Dựng `SQL_ClickUp_Full_Reconcile.json` + `SQL_ClickUp_Live_Update.json` (bản đầu, sau đó
  Full Reconcile được thay bằng bản FINAL đơn giản hoá ở trên).
- `Elite_Help_Bot_GPT.json`: thêm Execute Workflow Trigger nhận Message Envelope từ Gateway.
- README.md + ARCHITECTURE.md cập nhật theo trạng thái file mới.

## 2026-09-03 (Phase 0-1)
- Schema `gateway` (4 bảng) triển khai trên Postgres Docker + Supabase.
- Import Gateway + Error Handler, test luồng approve — 7/7 test pass.

## 2026-09-05 (tiếp) — SQL_ClickUp_Live_Update.json HOÀN TẤT
- **Đơn giản hoá mạnh**: 36 node (Switch + 24 node Update riêng cột) → **9 node** duy nhất, dùng 1 câu
  UPDATE với tên cột build ĐỘNG (an toàn — cột luôn lấy từ danh sách cố định trong code).
- Nhận diện đúng 6 loại thay đổi thật (xác nhận qua nhiều payload webhook thật): `status` (hiện
  trước➜sau), `name`, `content` (parse Quill Delta), `custom_field` (đọc tên trực tiếp từ payload, tự
  hỗ trợ field mới không cần sửa code), `assignee_add`, `comment` (tự trích link OneDrive/Youtube, ghi
  thẳng vào `onedrive_link`/`youtube_link`).
- Bỏ hẳn việc gọi lại ClickUp API để lấy comment — dùng thẳng dữ liệu có sẵn trong payload webhook
  (`history_items[].comment`), vừa né lỗi `httpRequestWithAuthentication` không hỗ trợ trong Code node,
  vừa nhanh hơn.
- Bỏ query `gateway.config` cho admin_chat_id, thay bằng node Config điền tay (giảm phụ thuộc, theo yêu
  cầu người dùng).
- Cả `SQL_ClickUp_Full_Reconcile.json` và `SQL_ClickUp_Live_Update.json` nay đã HOÀN TẤT.

## 2026-09-06 — Telebot_ClickUp_Reader REVAMP HOÀN TOÀN + gắn vào Gateway
- **Gắn Workflow ID thật (`9JJRrh36H2rLwtnu`) vào Gateway** — node `→ Sub: Telebot Main` đổi tên thành
  `→ Sub: Telebot ClickUp Reader`, trỏ đúng sub-workflow.
- **Phát hiện + fix bug tìm kiếm "không ra kết quả" dù Postgres có dữ liệu đúng**: 2 nguyên nhân độc lập:
  1. `queryReplacement` của node search dùng giá trị đơn `={{ $json.x }}` thay vì mảng
     `={{ [$json.x] }}` — n8n Postgres node luôn cần mảng dù chỉ 1 tham số.
  2. `Code1` (lớp chấm điểm JS) đọc `task.searchKeywords` từ item ĐÃ bị node Postgres phía trước ghi
     đè mất field đó — match_score luôn = 0, rơi vào "noresult" dù Postgres xếp hạng đúng.
- **REVAMP hoàn toàn `Telebot_ClickUp_Reader_v2_with_sync.json`**: 45 node → **16 node**. Bỏ hẳn lớp
  chấm điểm JS lỗi (Code1/Switch2), tin thẳng `ts_rank` có sẵn của Postgres. Dùng `alwaysOutputData`
  thay cho node If/Limit riêng để tránh bẫy quen thuộc "node bị bỏ qua khi 0 item". Tạm TẮT: OneDrive
  `view_file` (Graph API resolve, giữ lại link phẳng thôi) và toàn bộ `/sync` — sẽ làm lại từ đầu sau.
- **Fix deep link `chitiet_<id>` mở nhầm bot**: link cứng trỏ `Elite_clickup_bot` (bot PROD chưa
  active) thay vì `elite_n8n_test_bot` (bot DEV đang dùng) — bấm vào chỉ hiện "start" trơ trọi do bot
  PROD không xử lý gì lệnh đó.
- **Thêm node `⚙️ Config`** đầu workflow — biến `USE_PROD_BOT` để chuyển đổi bot DEV↔PROD 1 chỗ duy
  nhất khi tới Giai đoạn 4 (cutover), không cần sửa rải rác trong code.

## 2026-09-06 (tiếp) — Xác nhận toàn bộ luồng tìm kiếm task hoạt động đúng qua Gateway
- Fix Gateway: thêm `start` vào `COMMAND_MAP` (route tới `telebot_main`) — deep-link `chitiet_<id>` dùng
  lệnh `/start` chuẩn Telegram deep-link nhưng map cũ thiếu key này, khiến Gateway tự trả lời "lệnh
  không hợp lệ" (dùng danh sách lệnh khác hẳn — `/ask`, `/sum`) trước khi kịp chuyển sang sub-workflow.
- Thêm node `⚙️ Config` đầu `Telebot_ClickUp_Reader` — biến `USE_PROD_BOT` để đổi bot DEV↔PROD 1 chỗ
  duy nhất khi cutover Giai đoạn 4.
- Nâng cấp tìm kiếm: dùng `COUNT(*) OVER()` trong query lấy TỔNG SỐ kết quả chính xác (không bị ảnh
  hưởng bởi `LIMIT`), hiển thị "Tìm thấy N kết quả phù hợp, hiển thị 10 kết quả gần đúng nhất" thay vì
  thông báo chung chung "hơn 10 kết quả".
- **Xác nhận: toàn bộ luồng tìm kiếm task (`/task`, `chitiet_<id>`, đếm tổng kết quả) hoạt động đúng
  qua Gateway.** `/sync` và xem file OneDrive vẫn đang tắt, để làm ở phiên sau.

## 2026-09-06 (tối) — Tính năng `/sync` HOÀN TẤT, hoạt động đúng qua Gateway
- **Xây lại `/sync` từ đầu** (admin-only, chọn Folder → List → lưu `clickup.sync_targets` → hỏi đồng bộ
  ngay/chờ lần sau) và thêm Execute Workflow Trigger vào `SQL_ClickUp_Full_Reconcile.json` để nhận
  `list_id`/`testMode` truyền động — gộp thành `Telebot_ClickUp_Reader.json` duy nhất (35 node, xoá file
  `_v2_with_sync`).
- **Phát hiện lỗi kiến trúc Gateway quan trọng**: TOÀN BỘ callback (bấm nút inline keyboard) trước đây
  route thẳng vào luồng duyệt user (`ap:`/`dn:`) riêng biệt — không hề có đường chung sang sub-workflow
  như message thường. Đã thêm node `Là Callback Duyệt User?` rẽ nhánh: chỉ `ap:`/`dn:` vào luồng duyệt
  cũ, còn lại đi chung đường với message. `GW-03 Router` thêm nhận diện bot_key qua PREFIX của
  callback_data (vì callback không có dạng `/lệnh` nên `env.command` luôn null).
- **Cuối cùng chuyển hẳn `/sync` từ inline keyboard sang deep-link dạng text** (giống `chitiet_` đã ổn
  định) vì inline keyboard vẫn vướng dù đã fix Gateway — tin cậy hơn, không phụ thuộc callback routing
  nữa. Lưu ý kỹ thuật: deep-link Telegram chỉ cho phép `[A-Za-z0-9_-]`, đổi separator từ `:` sang `_`.
- Thêm `sync` vào `COMMAND_MAP` của Gateway.
- Nâng cấp trích link comment (cả Full Reconcile lẫn Live Update): ưu tiên đọc `bookmark.service`
  (`"youtube"`) do ClickUp tự gắn — đáng tin cậy hơn so khớp domain URL, đặc biệt với link rút gọn
  `youtu.be`.
- **Bài học lớn nhất trong phiên**: lỗi cuối cùng hoá ra do set nhầm bot Telegram Trigger
  (`@elite_n8n_system_bot` thay vì bot test) khi cấu hình trên n8n — không phải lỗi logic workflow.

## 2026-09-06 (khuya) — Full Reconcile hỗ trợ SYNC ĐA-LIST TỰ ĐỘNG + fix chat_id rỗng
- **Hoàn thiện đúng ý ban đầu của `/sync`**: trước đây lưu List vào `clickup.sync_targets` chỉ là ghi
  chép, Schedule (5 ngày/lần) vẫn luôn chạy đúng 1 List cố định trong Config — KHÔNG hề tự động theo
  bảng. Đã nối lại: Schedule giờ đọc TOÀN BỘ `clickup.sync_targets`, lặp qua từng dòng bằng cách
  **tự gọi lại chính workflow này** (self-reference qua Execute Workflow node, `waitForSubWorkflow: true`
  để chạy tuần tự, tránh chồng chéo rate-limit ClickUp). Nếu bảng trống (chưa ai dùng `/sync` lần nào) →
  fallback về List mặc định trong Config, giữ đúng hành vi cũ.
  - ⚠️ Cần điền Workflow ID thật (self-reference) vào 2 node mới trước khi tin tưởng chạy đúng — xem
    CHECKLIST trong PROJECT_STATUS.md.
- **Fix lỗi "Bad Request: chat_id is empty" ở `Notify Start`**: xảy ra khi chạy qua Execute Workflow
  Trigger (từ nút "Đồng bộ ngay" hoặc từ vòng lặp multi-list mới) vì `notifyChatId` để trống và
  `Notify Start` chạy TRƯỚC khi kịp query `admin_chat_id` từ Postgres (node đó chỉ chạy gần cuối
  workflow). Sửa theo đúng hướng đã áp dụng ở Live Update/Reader: thêm `ADMIN_CHAT_ID` hardcode ngay
  trong Config, `Build Notify Start`/`Build Notify Done` đều fallback về giá trị này. Xoá hẳn node
  Postgres `Lay Admin Chat ID` (không còn cần thiết) — Full Reconcile còn 26 node.

## 2026-09-06 (khuya, tiếp) — Tách Scheduler riêng + hiện tên List trong thông báo
- **Tách điều phối đa-List ra workflow riêng** (`SQL_ClickUp_Sync_Scheduler.json`, 6 node) khỏi
  `SQL_ClickUp_Full_Reconcile.json` (còn lại 21 node, chỉ là "engine" sync 1 List) — theo yêu cầu để dễ
  theo dõi Executions (trước đó self-reference gây lẫn lộn giữa lần chạy điều phối và lần chạy sync
  từng List trong cùng 1 danh sách Execution). Scheduler giờ gọi SANG Full Reconcile thay vì tự gọi
  chính nó.
- **Thông báo "Bắt đầu đồng bộ" hiện tên List thay vì chỉ ID số**: thêm node `Xác Định Tên List` — ưu
  tiên tên được truyền vào (Scheduler đã có sẵn từ `Query Sync Targets`, không cần tra lại), fallback
  tra `clickup.sync_targets` theo `list_id`, cuối cùng mới hiện ID thô nếu không tìm thấy gì.
