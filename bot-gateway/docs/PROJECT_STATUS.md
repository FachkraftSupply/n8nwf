# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm được ngữ cảnh
> mà không cần lại lịch sử debug dài ở phiên trước.
> Lịch sử thay đổi chi tiết theo ngày: xem `docs/CHANGELOG.md`.
> Hướng dẫn vận hành chi tiết SQL ClickUp Sync (Full Reconcile + Live Update): xem `docs/GUIDE_SQL_CLICKUP_SYNC.md`.
> Checklist đổi credential khi go-live (cutover sang bot PROD): xem `docs/GO_LIVE_CHECKLIST.md`.
> Lỗi thường gặp + cách đã sửa (tra cứu nhanh): xem `docs/FAQ.md`.
> ⚠️ QUY TẮC BẮT BUỘC khi sửa workflow — ĐỌC TRƯỚC: xem `docs/RULES.md`.

## Repo
`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua Composio (OAuth, không dùng token).

## Cấu trúc repo hiện tại
```
bot-gateway/
├── README.md
├── docs/
│   ├── CHANGELOG.md          <- lịch sử thay đổi chi tiết theo ngày
│   ├── PROJECT_STATUS.md     <- file này
│   ├── ARCHITECTURE.md, BOT_INVENTORY.md, GUIDE_DEPLOY_DATABASE.md, SETUP_PHASE_0_1.md
│   ├── GUIDE_SQL_CLICKUP_SYNC.md    <- huong dan van hanh Full Reconcile + Live Update
│   ├── GO_LIVE_CHECKLIST.md         <- checklist doi credential khi cutover sang bot PROD
│   ├── FAQ.md                       <- loi thuong gap + cach da sua, tra cuu nhanh
├── sql/
│   ├── 01_gateway_schema.sql
│   └── 02_clickup_tasks_schema.sql
├── original/                 5 workflow production NGUYÊN BẢN (tham khảo, không sửa)
│   └── Telebot_sql.json      <- QUAN TRỌNG: mẫu tham số ClickUp node ĐÚNG (xem bên dưới)
└── workflows/new_architecture/
    ├── GW_Gateway_Telegram.json       (Gateway, đang chạy trên bot DEV)
    ├── GW_Error_Handler.json
    ├── SQL_ClickUp_Full_Reconcile.json    <- ✅ HOÀN TẤT (21 node) - "engine" sync 1 List,
    │                                          co chong rate-limit + tu tra ten List de hien thi
    ├── SQL_ClickUp_Sync_Scheduler.json    <- ✅ MỚI (6 node) - dieu phoi da-List: Schedule doc
    │                                          clickup.sync_targets, goi SANG Full Reconcile cho tung List
    ├── SQL_ClickUp_Live_Update.json       <- ✅ HOÀN TẤT (9 node, don gian hoa manh, webhook real-time)
    └── sub_workflows_modernized/
        ├── Elite_Help_Bot_GPT.json        (✅ nhận Envelope, chờ Workflow ID để gắn Gateway)
        ├── Telebot_ClickUp_Reader.json    (✅ ĐANG DÙNG - merge day du: tim task + /sync (35 node), OneDrive view_file van tam tat)
        └── Telebot_main.json              (⚠️ KHÔNG dùng nữa, giữ tham khảo logic xử lý ảnh)
```

## QUY TẮC LÀM VIỆC (áp dụng cho mọi phiên chat)
- **⚠️ MỖI KHI thêm/sửa 1 lệnh (command) mới trong bất kỳ sub-workflow nào (Telebot ClickUp Reader,
  Help Bot GPT, Crawl Bot...): BẮT BUỘC kiểm tra và cập nhật `COMMAND_MAP` trong node `⚙️ Config` của
  `GW_Gateway_Telegram.json`, route lệnh đó tới đúng `bot_key`.** Đã quên việc này 2 lần liên tiếp
  (`/sync` và sau đó `/sync_status`+`/db_status`) gây lỗi "route: unknown" — Gateway không hề tự động
  nhận diện lệnh mới của sub-workflow, phải khai báo tay từng lệnh. Coi đây là bước CUỐI CÙNG bắt buộc
  của mọi tính năng thêm lệnh mới, trước khi báo "xong" với user. LƯU Ý: từ khi có `Telebot_Admin_System.json`
  (Trigger riêng, không qua Gateway), quy tắc này CHỈ áp dụng cho sub-workflow nào thực sự gọi qua Gateway
  — kiểm tra trước xem sub-workflow đó có Trigger riêng hay không.
- **⚠️ MỖI KHI thêm/sửa 1 node Telegram gửi tin nhắn (bất kỳ workflow nào): BẮT BUỘC kiểm tra `chatId`
  được truyền đúng và TƯỜNG MINH từ Trigger xuống — không dùng `{{ $json.chatId }}`/`{{ $json.chat_id }}`
  trần, luôn tham chiếu qua tên node cụ thể (`{{ $('Phân tích lệnh').first().json.chatId }}` hoặc
  `{{ $('GW-01 Envelope').first().json.chat_id }}`).** Đã sửa lỗi này ở hơn 10 node trong 3 workflow
  (07/09/2026) vì dùng `$json` trần khiến chatId có thể rỗng tuỳ node liền trước là gì. Áp dụng tương tự
  cho `reply_to_message_id` (để bot trả lời đúng group/topic khi được thêm vào group).
- **⚠️ KHÔNG dùng inline keyboard (Telegram) làm mặc định — chỉ dùng khi user YÊU CẦU RÕ RÀNG.** Mặc
  định LUÔN dùng cơ chế deep-link dạng text (`https://t.me/<bot>?start=<param>`, giống `chitiet_<id>`
  đã chạy ổn định từ đầu dự án). Lý do: đã gặp inline keyboard không hoạt động ổn định NHIỀU LẦN (06/09
  và lặp lại 07/09/2026) qua nhiều nguyên nhân khác nhau (Gateway route callback sai luồng, n8n không
  lưu được field `inlineKeyboard` khi `replyMarkup` là expression động...) — dù đã fix từng nguyên nhân,
  vẫn không tin cậy bằng deep-link. Deep-link đơn giản hơn, không phụ thuộc callback routing, đã proven
  qua nhiều tháng dùng cho `chitiet_`. Nếu user yêu cầu cụ thể muốn dùng inline keyboard, hỏi rõ lý do
  và cảnh báo trước về lịch sử không ổn định này.
- Sửa file JSON lớn: dùng Composio remote workbench (fetch GitHub → sửa Python trong sandbox → commit),
  không dán nguyên workflow vào chat.
- **Khi đang debug/thử nghiệm 1 thay đổi:** KHÔNG tự động commit vào file chính trên GitHub. Chỉ đưa
  nội dung node cần sửa (JSON đầy đủ nếu node thường, chỉ code nếu Code node) để user tự copy/paste
  test trong n8n. Chỉ commit sau khi user xác nhận chạy ổn.
- Thay đổi lớn/rủi ro cao: cân nhắc commit thành file `_v2`/`_wip` riêng trước, merge vào file chính
  sau khi xác nhận — tránh phải rollback file đang dùng.
- Khi rút gọn/đơn giản hoá 1 workflow: LUÔN đối chiếu checklist tính năng bản trước để không bỏ sót
  (từng quên node Notify Start khi đơn giản hoá SQL sync — xem CHANGELOG 2026-09-05).
- Luôn cập nhật CHANGELOG.md + file này sau khi 1 thay đổi được xác nhận thành công.

## ⚠️ GHI NHỚ KỸ THUẬT QUAN TRỌNG NHẤT (tránh lặp lại lỗi đã tốn nhiều vòng debug)

**Node ClickUp native trên n8n của user dùng THAM SỐ PHẲNG, không phải resource-locator.**
```js
// ĐÚNG (đã xác nhận chạy ổn, xem original/Telebot_sql.json node "lay task"/"lay comment1"):
{ team: "9018351620", space: "90183192291", folderless: true, list: "={{ $json.id }}" }
{ resource: "comment", operation: "getAll", commentsOn: "task", id: "={{ $json.id }}", limit: 50 }
// SAI (gây lỗi liên tục trước đây):
{ team: {"__rl": true, "value": "...", "mode": "id"} }  // resource-locator - KHÔNG dùng cho instance này
```
- `ClickUp - Get Comments` KHÔNG tự lặp qua nhiều item — bắt buộc bọc trong `SplitInBatches(batchSize=1)`.
- Link OneDrive/Youtube trong comment ClickUp: đọc CẢ `comment[].bookmark.url` LẪN `comment[].attributes.link`
  (2 nguồn khác nhau tùy cách dán link) + regex trên `comment_text` làm fallback cuối.
- ClickUp đã đổi định dạng Task ID (số → chữ+số, vd `z908826jhz`) — luôn để cột `id` trong Postgres là
  `TEXT` không giới hạn.
- `gateway.config` là bảng key-value (`key`, `value`), KHÔNG có cột riêng `admin_chat_id` — query đúng:
  `SELECT value AS admin_chat_id FROM gateway.config WHERE key = 'admin_chat_id'`.
- Code node mặc định "Run Once for All Items" — nếu code viết theo kiểu xử lý từng item (`$json`,
  `return {json:{...}}`), PHẢI set `"mode": "runOnceForEachItem"` trong parameters, nếu không chỉ xử
  lý được 1 item dù đầu vào nhiều hơn.
- `SplitInBatches` output "done" (index 0) trả về TOÀN BỘ item gốc đã đưa vào loop (không phải 1 tín
  hiệu đơn) — nếu nối thẳng sang bước gửi Telegram sẽ lặp/dài tin nhắn, cần chèn `Limit(maxItems=1)`
  trước bước thông báo cuối cùng.

## Trạng thái hiện tại theo Phase (roadmap đầy đủ ở ARCHITECTURE.md mục 8)
| Phase | Việc | Trạng thái |
|---|---|---|
| 0-1 | Schema DB + Gateway + Error Handler | ✅ Xong (7/7 test) |
| 2 | Help Bot GPT nhận Envelope | ✅ Code xong, ⏳ chờ Workflow ID thật để gắn Gateway |
| 2b | Telebot ClickUp Reader (đọc/tìm task + /sync) | ✅ HOÀN TẤT CẢ 2 — tìm kiếm/chi tiết task VÀ /sync (chọn Folder/List, lưu clickup.sync_targets, kích hoạt Full Reconcile) đều đã xác nhận hoạt động qua Gateway; chỉ còn OneDrive view_file tạm tắt |
| 2c | SQL Sync ClickUp ↔ Postgres | ✅ HOÀN TẤT — Full Reconcile (21 node, engine sync 1 List + tự tra tên List) + Sync Scheduler (6 node, điều phối đa-List từ `clickup.sync_targets`, tách riêng để dễ theo dõi Executions) + Live Update (9 node, webhook real-time). ⚠️ Cần điền Workflow ID của Full Reconcile vào Scheduler (xem checklist) |
| 3 | Backup Postgres → OneDrive (Phương án B — SQL export thuần n8n) | Chưa bắt đầu |
| 3 | Chuyển Crawl Bot | Chưa bắt đầu |
| 4 | Cutover Gateway sang bot PROD | Chưa bắt đầu |
| — | Bot System Main (xử lý ảnh, tách từ Telebot_main.json cũ) | Chưa bắt đầu |
| — | Tính năng mới: `/sync` admin-only chọn Folder/List qua Telegram, tự lưu để auto-sync | ⏸️ TẠM TẮT khi revamp 05/09/2026 (đã xoá khỏi file đang dùng), sẽ làm lại từ đầu sau khi tìm kiếm ổn định |
| — | Rate-limit khi Full Reconcile lấy comment (nhiều task) | 🔵 Đang thiết kế (xem chat 05/09/2026) |

## ĐÃ HOÀN TẤT (07/09/2026, cuối phiên) — /sync + /help hoạt động hoàn toàn tốt
- `Telebot_Admin_System.json` (System Bot, không qua Gateway): `/task`, `/sync` (chọn Folder→List→
  Đồng bộ ngay), `/help`, `/sync_status`, `/db_status`, `chitiet_<id>` — TẤT CẢ đã test OK qua deep-link
  (không dùng inline keyboard — xem RULES.md #3).
- Đã tạo `docs/RULES.md` gộp toàn bộ quy tắc — đọc file đó trước khi sửa workflow bất kỳ.

## ⚠️ VIỆC ƯU TIÊN SỐ 1 CHO NGÀY MAI — CHƯA TEST LẠI, PHẢI LÀM TRƯỚC TIÊN

**Bối cảnh:** Chạy Full Reconcile thật (testMode off, 612 task) → phát hiện lỗi nghiêm trọng: node
`Xoá Task Links Cũ` nhận input 612 nhưng chỉ output 1 → 611 task bị rơi khỏi vòng lặp xử lý
`task_links`/comment. Nguyên nhân: tham chiếu `queryReplacement` qua 2 bước (`.first()`/`.item` giữa
2 node) không đáng tin cậy khi xử lý hàng loạt (612 item), dù đã test ổn với vài task lúc testMode bật.

**Đã sửa (commit `57a9764`):** gộp DELETE + INSERT thành **1 câu query duy nhất** (CTE
`WITH deleted AS (DELETE...) INSERT...`) trong node `Ghi Task Links Mới`, tham chiếu THẲNG từ
`Trích Xuất Task Links` chỉ 1 bước (an toàn tuyệt đối, không còn nguy cơ pairedItem bị mất). Đã xoá hẳn
node `Xoá Task Links Cũ` riêng — Full Reconcile còn 23 node.

**⚠️ CHƯA ĐƯỢC TEST LẠI VỚI DATASET THẬT (612 task) — đây là việc đầu tiên phải làm ngày mai:**
1. Import lại `SQL_ClickUp_Full_Reconcile.json` (bản mới nhất, commit `57a9764`).
2. Chạy lại Full Reconcile (Manual Trigger, testMode vẫn đang off từ hôm qua).
3. Theo dõi node `Ghi Task Links Mới` — input/output phải KHỚP NHAU (vd input 612 → output 612), không
   còn bị rơi giữa chừng.
4. Xác nhận workflow chạy hết toàn bộ, không dừng giữa chừng ở `Kiểm Tra Link Có Sẵn` hay bất kỳ đâu.
5. Sau khi chạy xong: kiểm tra `SELECT count(*) FROM clickup.task_links;` trong pgAdmin — số dòng phải
   hợp lý (không phải chỉ có dữ liệu của 1 task).

## CHECKLIST — Việc tiếp theo (cập nhật 07/09/2026 cuối phiên)

1. **(Xem mục trên)** Test lại Full Reconcile với fix mới nhất — 612 task.
2. Điền Workflow ID thật của `Full Reconcile` vào 2 node `Chạy Sync Cho List Này` +
   `Chạy Sync List Mặc Định` trong `SQL_ClickUp_Sync_Scheduler.json` — CHƯA làm.
3. Test multi-list qua `Sync Scheduler` (chuột phải → Execute Workflow).
4. Test đưa bot vào group Telegram (kiểm tra `reply_to_message_id` giữ đúng group/topic) — CHƯA test.
5. Xây lại xem file OneDrive (`view_file`, Graph API) — hiện chỉ có link phẳng.
6. Workflow ID cho Help Bot GPT → gắn Gateway.
7. Khi rảnh: Bot System Main (xử lý ảnh) + Backup Postgres → OneDrive (Phase 3).


