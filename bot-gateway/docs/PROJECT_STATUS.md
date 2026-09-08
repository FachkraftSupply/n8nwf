# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm được ngữ cảnh
> mà không cần lại lịch sử debug dài ở phiên trước.
> Lịch sử thay đổi chi tiết theo ngày: xem `docs/CHANGELOG.md`.
> Hướng dẫn vận hành chi tiết SQL ClickUp Sync (Full Reconcile + Live Update): xem `docs/GUIDE_SQL_CLICKUP_SYNC.md`.
> Checklist đổi credential khi go-live (cutover sang bot PROD): xem `docs/GO_LIVE_CHECKLIST.md`.
> Lỗi thường gặp + cách đã sửa (tra cứu nhanh): xem `docs/FAQ.md`.
> ⚠️ QUY TẮC BẮT BUỘC khi sửa workflow — ĐỌC TRƯỚC: xem `docs/RULES.md`.

## 🌙 PHIÊN HÔM NAY (Giai đoạn A — Admin backup tools) — cập nhật cuối ngày

**Đã hoàn tất trong phiên này:**
- Tạo `SQL_Backup_System.json` (workflow riêng, Manual + Schedule Chủ nhật 2h sáng + Execute Workflow
  Trigger, nhận `backupType`: 'n8n'|'db'|'both').
- `/backup_n8n` + `/backup_db` trong `Telebot_Admin_System.json` gọi sang workflow này (gọn, tách khỏi
  logic backup trực tiếp).
- Đổi từ Google Drive sang **Microsoft OneDrive** theo yêu cầu — đã sửa nhiều lỗi cấu hình thực tế:
  Azure App Registration (lỗi `unauthorized_client` — do Supported Account Types sai, đã hướng dẫn sửa),
  field `Parent ID` là ô TEXT THƯỜNG (không phải resource-locator, đã sửa từ object → string),
  `binaryDataUpload` sai tên tham số → đổi đúng `binaryData` + `binaryPropertyName`.
- Đang hướng dẫn user lấy Folder ID thật qua node OneDrive (Resource: Folder → Operation: Search).

**⚠️ PHÁT HIỆN QUAN TRỌNG — Execute Command bị chặn trên n8n instance này:**
Lỗi `Unrecognized node type: n8n-nodes-base.executeCommand` khi chạy `/backup_db` — node này bị
disable qua biến môi trường trong docker-compose (n8n dùng **Docker Hardened Image**, Alpine 3.24,
không có `apk`, chạy user thường "node" không phải root).
- **Đã fix tạm thời (đang dùng)**: bỏ hẳn `pg_dump`, backup Postgres qua 3 node Postgres SELECT
  (`clickup.tasks`, `clickup.task_links`, `clickup.sync_targets`) → gộp JSON → upload OneDrive.
  Hoạt động, nhưng KHÔNG PHẢI bản sao SQL đầy đủ (thiếu schema/index/gateway tables).

**User đã nhờ Claude Code (có quyền SSH) khảo sát VPS — kết quả:**
- Container n8n: Docker Hardened Image, không cài được `pg_dump` trực tiếp (không có apk), build custom
  image là cách DUY NHẤT để pg_dump nằm TRONG container n8n — **user từ chối build custom image**.
- Container Postgres (`postgres:16-alpine`) **đã có sẵn** `pg_dump`/`psql`.
- 3 phương án thay thế (không build image) — đã phân tích ưu/nhược:
  - **A**: mount `docker.sock` vào n8n container, Execute Command chạy `docker exec <container_postgres>
    pg_dump ...` — rủi ro bảo mật CAO (tương đương quyền root trên host nếu bị khai thác).
  - **B**: cron trên HOST (không qua n8n) chạy pg_dump, n8n chỉ đọc file qua mount read-only — an toàn
    hơn A, nhưng mất khả năng bấm Manual Trigger backup theo yêu cầu (cần thêm webhook riêng để kích
    hoạt cron ngoài lịch).
  - **C (khuyến nghị)**: dùng node **SSH có sẵn trong n8n** (KHÔNG bị chặn như Execute Command) để SSH
    vào chính VPS, chạy `docker exec n8n_stack-postgres-1 pg_dump -U n8n -d n8n -n clickup -n gateway
    > backup_file.sql` từ đó — né được cả rủi ro docker.sock lẫn việc build image.

## ✅ HOÀN TẤT (08/09/2026) — Backup Postgres qua SSH thật (Phase 3 DB backup)
- `SQL_Backup_System.json` nhánh DB đã đổi sang pg_dump SQL thật qua 4 node SSH (không còn bản
  JSON 3 bảng tạm). Đã test executeWorkflow qua MCP nhiều lần, `status: success`, file `.sql` lên
  đúng OneDrive, Telegram báo đúng link. Chi tiết đầy đủ + 3 lỗi đã gặp/đã sửa: xem CHANGELOG.md
  mục 2026-09-08.
- Credential Postgres thật đã xác nhận: `-U n8n -d n8n`, schema `clickup` + `gateway`.
- Câu hỏi còn treo (chưa quyết định): có giữ song song bản backup JSON 3 bảng cũ làm dự phòng
  không, hay bỏ hẳn như hiện tại (đã bỏ trong lần sửa này)? Hỏi lại user nếu cần.
- Việc còn lại của Phase 3: **Chuyển Crawl Bot** (chưa bắt đầu).

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
| 3 | Backup Postgres → OneDrive (Phương án C — pg_dump SQL thật qua SSH) | ✅ Xong (08/09/2026) |
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

## ⚠️ VIỆC ƯU TIÊN SỐ 1 CHO NGÀY MAI — 3 phát hiện MỚI (07/09/2026 tối, phiên sau) — CHƯA SỬA GÌ

### Phát hiện 1 — SAI hiểu về quy luật đặt tên field DKPV/PVTC (QUAN TRỌNG NHẤT)
User đã tự kiểm tra JSON thật và xác nhận: **CẢ DKPV và PVTC đều đổi tên theo năm mỗi năm** — không
phải chỉ PVTC đổi còn DKPV cố định như mình từng giả định sai. Field thật sự có dạng `DKPV 2026`,
`DKPV 2027`... và `PVTC 2026`, `PVTC 2027`... — CẢ HAI ĐỀU CẦN REGEX theo năm, không được hardcode
"dkpv" cố định như code hiện tại.

**Cần sửa (chưa làm):** node `Trích Xuất Task Links` trong `SQL_ClickUp_Full_Reconcile.json` — đổi
đoạn nhận diện DKPV từ so khớp CHÍNH XÁC `'dkpv'` sang REGEX giống PVTC: `/^DKPV\s+(\d{4})$/i`, lưu
thêm cột `dkpv_year` tương tự `pvtc_year` (có thể cần `ALTER TABLE clickup.task_links ADD COLUMN
dkpv_year INT` trong Ensure Schema).

**Ví dụ JSON thật user gửi** (custom_field type list_relationship), lưu lại tham khảo:
```json
{
  "field_inverted_name": "DKPV 2026",
  "subcategory_inverted_name": "Đơn Hàng",
  "subcategory_id": "901805909357",
  "value": [
    { "id": "86ex3um7r", "name": "Bad Reichenhall | MKG...", "status": "đi xin visa",
      "team_id": "9018351620", "url": "https://app.clickup.com/t/86ex3um7r" }
  ]
}
```
(Cấu trúc `value[]` giống hệt PVTC — mỗi phần tử có `id`, `name`, `status` — code hiện tại đọc đúng
cấu trúc này, chỉ sai ở phần NHẬN DIỆN TÊN FIELD.)

### Phát hiện 2 — Lỗi 612→1 output VẪN XẢY RA ở lần chạy không filter (trước khi fix mới nhất được áp dụng?)
User báo: chạy Full Reconcile không filter theo status → vẫn bị dừng ở đúng vị trí cũ (`Kiểm Tra Link
Có Sẵn`), input/output 612→1 y hệt lần trước. **Cần làm rõ ngày mai:** đây là do đang chạy BẢN CŨ
(trước commit `57a9764` gộp DELETE+INSERT), hay fix đó VẪN CHƯA đủ? Cần xác nhận đã import đúng bản
mới nhất trước khi kết luận.

### Phát hiện 3 — Lỗi MỚI khi lọc theo status: duplicate key trong `Ghi Task Links Mới`
Khi chạy CÓ filter theo status (tiến xa hơn lần trước), gặp lỗi:
```
duplicate key value violates unique constraint "task_links_pkey"
Key (student_task_id, order_task_id, link_type)=(86ey2brv5, 86et18bg0, pvtc) already exists.
```
**Nguyên nhân khả dĩ (liên quan trực tiếp Phát hiện 1):** vì 1 task học sinh có thể có NHIỀU field
PVTC theo năm khác nhau (`PVTC 2025`, `PVTC 2026`...) cùng trỏ tới CÙNG 1 đơn hàng — khi gộp thành
mảng `linksJson` để INSERT, 2 dòng có key trùng nhau `(student_task_id, order_task_id, 'pvtc')` vì
PRIMARY KEY hiện tại KHÔNG có `pvtc_year` — 1 câu INSERT không thể tự ghi đè lên chính nó trong CÙNG
batch (khác với `ON CONFLICT` giữa các lần chạy khác nhau).

**User tự đề xuất:** "có thể ở đây chúng ta phải dùng upsert?" — ĐÚNG HƯỚNG nhưng chưa đủ, vì
`ON CONFLICT DO UPDATE` cũng lỗi "cannot affect row a second time" nếu 2 dòng trong CÙNG 1 câu INSERT
đụng cùng key. **Hướng sửa cần bàn kỹ ngày mai** (chưa quyết định, cần thảo luận với user trước khi
làm), 2 lựa chọn khả dĩ:
- (A) Thêm `dkpv_year`/`pvtc_year` vào PRIMARY KEY (`student_task_id, order_task_id, link_type,
  COALESCE(pvtc_year,0), COALESCE(dkpv_year,0)`) — giữ lại lịch sử nhiều năm nếu 1 đơn hàng thật sự
  liên quan tới nhiều năm khác nhau.
- (B) Dedupe trong `linksJson` TRƯỚC khi insert (Code node lọc theo `order_task_id + link_type`, chỉ
  giữ dòng của NĂM MỚI NHẤT) — coi field năm cũ là dữ liệu lịch sử không cần lưu, chỉ quan tâm năm
  hiện tại.
**Cần hỏi rõ user ngày mai: đơn hàng bị trùng giữa 2 năm PVTC có phải là dữ liệu thật hợp lệ (học sinh
apply lại năm sau cùng 1 đơn hàng), hay là lỗi/rác cần loại bỏ?** — quyết định này ảnh hưởng chọn (A)
hay (B).

## VẤN ĐỀ CŨ (ưu tiên thấp hơn 3 phát hiện trên) — chưa test lại

## CHECKLIST — Việc tiếp theo (cập nhật 08/09/2026)

### ✅ Đã xong (xác nhận 08/09/2026)
1. ~~Test lại Full Reconcile với fix DKPV/PVTC theo năm~~ — XONG.
2. ~~Điền Workflow ID thật của `Full Reconcile` vào `SQL_ClickUp_Sync_Scheduler.json`~~ — XONG.
3. ~~Test multi-list qua `Sync Scheduler`~~ — XONG.
4. ~~Test đưa bot vào group Telegram (`reply_to_message_id` đúng group/topic)~~ — XONG.
7. ~~Backup Postgres/Credentials/Config → OneDrive (Phase 3)~~ — XONG (xem CHANGELOG 08/09/2026).

### ⏸️ Tạm hoãn (chưa cần thiết)
5. Xây lại xem file OneDrive (`view_file`, Graph API) — hiện chỉ có link phẳng, user xác nhận
   CHƯA CẦN làm ngay, giữ nguyên hiện trạng.

### 🔵 Đang làm (08/09/2026)
- **Sub-workflow xử lý ảnh mới** — nhận ảnh gửi qua Telegram, đọc lệnh trong caption:
  - `/xoanen` — xóa nền ảnh
  - `/tomtat` — tóm tắt nội dung ảnh (mô tả/OCR + tóm tắt)
  - Đây chính là hạng mục "Bot System Main (xử lý ảnh)" trong roadmap — bắt đầu triển khai.
  - Tham khảo logic xử lý ảnh cũ: `workflows/new_architecture/sub_workflows_modernized/Telebot_main.json`
    (giữ lại chỉ để tham khảo, KHÔNG dùng trực tiếp — xem ghi chú trong cấu trúc repo ở trên).

### ⚪ Còn treo, chưa ưu tiên
6. Workflow ID cho Help Bot GPT → gắn Gateway.

## VẬN HÀNH — Công cụ hỗ trợ
- `bot-gateway/scripts/restore.sh` — khôi phục Postgres/Credentials/Workflows khi VPS sập.
  **CHƯA test thật** trên production, cần test trên n8n instance rỗng trước khi tin dùng.


