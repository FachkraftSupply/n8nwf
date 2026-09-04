# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Dán file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm đủ ngữ cảnh
> mà không cần đọc lại lịch sử debug dài ở phiên trước.

## Repo
`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua Composio (OAuth, không dùng token).

## Cấu trúc repo hiện tại
```
bot-gateway/
├── README.md
├── sql/01_gateway_schema.sql
├── workflows/
│   ├── original/                          5 workflow production NGUYÊN BẢN
│   └── new_architecture/
│       ├── GW_Gateway_Telegram.json       workflow Gateway (đang chạy trên n8n)
│       ├── GW_Error_Handler.json
│       └── sub_workflows_modernized/      5 workflow đã nâng n8n 2.37.7 + dual storage
└── docs/ (ARCHITECTURE, BOT_INVENTORY, GUIDE_DEPLOY_DATABASE, SETUP_PHASE_0_1, PROJECT_STATUS)
```

## Đã HOÀN THÀNH (Giai đoạn 0–1)
- Schema `gateway` (4 bảng) đã tạo trên CẢ Postgres Docker (`n8n_stack-postgres-1`, db `n8n`)
  và Supabase (project "Telegram authentication DB", ref `nlgmkfqtmarsdcqismzz`).
- Admin ID đúng: **`975005174`**, đồng bộ 2 DB + workflow.
- Đã import + gắn credential đủ (`Telegram Dev Bot`, `Telegram System Bot`, `Supabase Postgres`).
- Đã sửa lỗi cú pháp `queryReplacement` (phải dùng dạng mảng `={{ [$json.a, $json.b] }}`,
  không phải `={{ $json.a }},{{ $json.b }}`) ở 4 node Postgres đa tham số.
- Đã sửa lỗi Telegram "can't parse entities": node "Báo admin duyệt user" chèn username/text
  tự do của user vào tin nhắn có parse_mode Markdown mặc định -> ký tự _ * [ ] trong nội dung
  user gõ làm Telegram từ chối gửi. Đã set parse_mode='' (None) cho node này trên GitHub
  (commit cb1207f) — CẦN ANH TỰ SỬA field tương ứng trong n8n UI nếu workflow đang chạy
  chưa đồng bộ lại từ repo (Additional Fields -> Parse Mode -> None).
- Test #1 (admin route đúng) PASS.

## Đang làm dở — 7 test nghiệm thu (`docs/SETUP_PHASE_0_1.md`)
| # | Test | Trạng thái |
|---|---|---|
| 1 | Admin route đúng | PASS |
| 2 | User lạ -> chờ duyệt + admin nhận nút | PASS (sau fix parse_mode) |
| 3 | Admin bấm approve -> cả 2 bên nhận thông báo | PASS (sau fix chat_id + fix data Postgres phía admin) |
| 4 | User được duyệt dùng lệnh | Chưa test |
| 5 | User chưa có quyền bị chặn đúng cách | Chưa test |
| 6 | Log ghi đủ cả 2 DB | Chưa verify lại |
| 7 | Non-admin bấm nút approve bị chặn | Chưa test |

## Bot inventory (chi tiết: docs/BOT_INVENTORY.md)
- @elite_n8n_test_bot -> Gateway DEV (đang dùng)
- @Elite_clickup_bot -> Gateway PROD (Giai đoạn 4 - cutover)
- @elite_n8n_system_bot -> kênh Error Handler
- @Elite_system_bot (backup_data) -> output crawl_bot + BACKUP N8N
- @elite_tele_help_bot -> nghỉ hưu dần, gộp vào Gateway (bot_key: help_bot)

## VIỆC TIẾP THEO — Giai đoạn 2
Chuyển Elite Help Bot GPT (đã có bản modernized trong
workflows/new_architecture/sub_workflows_modernized/Elite_Help_Bot_GPT.json) thành sub-workflow:
1. ✅ XONG — Đã nối "When Executed by Another Workflow" (đã có sẵn trong file, trước đó bị bỏ trơ,
   nối thẳng qua node phân tích intent bỏ qua toàn bộ logic) qua node Code mới "Envelope → Legacy Shape"
   rồi mới vào "SET ENV" → Code1 (giữ 100% luồng cũ). Node adapter chỉ map field Envelope (mục 3
   ARCHITECTURE.md: text/chat_id/user_id/username) thành object `message.{text,chat.id,from.id,from.username}`
   mà Code1 đang parse, đồng thời spread nguyên envelope gốc (request_id, platform, auth, bot_key, route,
   callback, raw...) ra root để không mất Correlation ID khi đi tiếp xuống AI Agent.
   Commit: https://github.com/FachkraftSupply/n8nwf/commit/9262e2d6f50fbacac69ba8cb33b050059f71f395
2. ✅ Giữ nguyên 100% logic AI Agent / Notion / Switch (Intent) bên trong — không đụng.
3. ⏳ ĐANG CHỜ — Gắn workflow ID thật vào node "→ Sub: Help Bot" trong Gateway (đang placeholder
   REPLACE_HELP_BOT_ID). CẦN anh cung cấp workflow ID (hoặc URL) thật của "Elite Help Bot GPT" trên n8n live
   — Claude không có tool truy vấn n8n API trực tiếp trong phiên này (chỉ có Composio GitHub + Supabase MCP),
   không tự suy ra được ID.
4. Production Elite Help Bot GPT (trigger cũ, Telegram Trigger1 / Telegram Trigger PROD) vẫn chạy song song,
   không tắt — chưa động tới, chỉ thêm nhánh mới.

## Quy tắc làm việc để tránh phình context
- KHÔNG dán lại toàn bộ nội dung file JSON lớn vào chat để sửa 1-2 trường.
- Cách hiệu quả đã kiểm chứng: dùng Composio remote workbench (run_composio_tool trong
  COMPOSIO_REMOTE_WORKBENCH) để GET file từ GitHub -> sửa bằng Python trong sandbox ->
  COMMIT lại, tất cả không đi qua context chính của chat.
- File > 60KB cần thêm mới (chưa có trên GitHub) thì đóng gói zip, để user tự kéo-thả upload
  qua GitHub web UI thay vì dán vào chat.
- Credential Postgres docker: `Postgres account` (id iNVsYeDUnMl6pq4M).
  Credential Supabase: `Supabase Postgres`.


## LẦN SỬA MỚI NHẤT (sau lần cutover thử nghiệm)
- Lỗi "chat_id is empty" ở node "Bỏ qua (không phải admin)": nguyên nhân là node Postgres
  "Check admin" phía trước GHI ĐÈ toàn bộ $json bằng kết quả SQL (chỉ còn cột `role`), làm
  mất chat_id gốc. ĐÃ SỬA: chatId giờ đọc từ `{{ $('GW-01 Envelope').first().json.chat_id }}`
  thay vì `{{ $json.chat_id }}`. Đã rà toàn bộ workflow, không còn node nào khác mắc lỗi
  tương tự (mọi node khác đều đi qua Code node trung gian giữ nguyên envelope).
- Bài học chung: BẤT KỲ lúc nào thêm node Postgres/DB query vào giữa luồng, node theo SAU nó
  không được đọc thẳng $json cho các field gốc (chat_id, user_id...) — phải tham chiếu ngược
  về node Envelope hoặc Merge Auth bằng $('TênNode').first().json.field.


## Fix bổ sung (đã xong)
- "Bỏ qua (không phải admin)" từng báo sai admin không phải admin do dữ liệu Postgres
  (không phải lỗi workflow) — user đã tự sửa trực tiếp trên DB, đã hoạt động đúng.

## ĐỔI ƯU TIÊN (04/09/2026) — ClickUp (Telebot Main) làm trước Help Bot
Theo yêu cầu: ưu tiên hoàn thiện sub-workflow ClickUp (Telebot Main) trước, Help Bot GPT tạm gác lại
sau bước 1-2 (đã xong phần code, chỉ còn thiếu workflow ID thật để gắn vào Gateway — xem mục phía trên).

### Telebot Main (ClickUp bot) — tiến độ
File `Telebot_main.json` PHỨC TẠP HƠN Help Bot: 71 node, đã có sẵn hạ tầng làm dở từ trước:
- Node `sub workflow` (Execute Workflow Trigger, inputSource=passthrough) — đã có sẵn, không cần thêm.
- Node `Code` — logic tính route y hệt `Phân tích lệnh` gốc nhưng đọc thẳng `$input` (không phụ thuộc
  node `Trigger Prod`) — TRƯỚC ĐÓ bị `disabled: true` và output nối vào chỗ trống, không dùng được.
- Node `zalo code` — thử nghiệm dở cho Zalo, đọc sai shape (`body.message`), chỉ phủ 1/8 nhánh Switch
  qua node `If` — KHÔNG ĐỤNG TỚI, để nguyên cho việc khác.
- Node `Phân tích lệnh` gốc: hard-code `$('Trigger Prod').item.json` → KHÔNG dùng được khi gọi qua
  sub-workflow (Trigger Prod chưa chạy trong execution đó → lỗi "Referenced node is not part of input").

✅ ĐÃ SỬA (commit https://github.com/FachkraftSupply/n8nwf/commit/f1644e822edc5184ac113f3149c9d32678925970):
1. Thêm node mới "Envelope → Legacy Shape": nhận Message Envelope (spec mục 3 ARCHITECTURE.md), dựng lại
   `message.{text,chat.id,message_id,from.id,from.username}` hoặc `callback_query.{id,data,message.chat.id,
   message.message_id}` tùy `kind`, spread nguyên envelope gốc ra root để giữ request_id/platform/auth/
   bot_key trong `originalData` phục vụ debug.
2. Bật lại node `Code` (xoá `disabled: true`).
3. Nối lại: `sub workflow` → `Envelope → Legacy Shape` → `Code` → `Switch` (đúng đích mà `Phân tích lệnh`
   đang nối tới) — tái sử dụng 100% pipeline `task`/`stat`/`help`/`chitiet`/`taotask_td`/`taotask_tc` phía
   sau, không viết lại gì. Nhánh `zalo code` giữ nguyên, không đụng.

⚠️ LƯU Ý AN TOÀN khi test: route `taotask_td`/`taotask_tc` gọi thẳng node `cr_task_hs`/`cr_task_dh`
(n8n-nodes-base.clickUp) — TẠO TASK THẬT trên ClickUp List ID `901805909593` (hoặc list liên quan).
Khi nghiệm thu qua Gateway, nên test theo thứ tự: `/help` → `/task <id có sẵn>` → `/stat` → `chitiet_<id>`
TRƯỚC, để `/taotask` cuối cùng và xoá/dọn task test sau khi xong.

### Việc tiếp theo — CẦN TỪ ANH
1. CẦN workflow ID (hoặc link) thật của "Telebot main" trên n8n live → gắn vào node "→ Sub: Telebot Main"
   trong Gateway (đang placeholder REPLACE_TELEBOT_MAIN_ID).
2. CẦN workflow ID thật của "Elite Help Bot GPT" (đang gác lại, xem mục Giai đoạn 2 phía trên) — có thể
   gửi cùng lúc.
3. Sau khi có ID: Claude gắn cả 2 vào Gateway, commit, anh import lại Gateway trên n8n live rồi test
   theo checklist (xem chat) cho từng sub-workflow riêng.

## Việc tiếp theo khi mở chat mới
1. Test #4, #5, #6, #7 còn lại (xem docs/SETUP_PHASE_0_1.md mục Test nghiệm thu) — nếu chưa làm.
2. Giai đoạn 2 đang ưu tiên ClickUp (Telebot Main) — xem mục "ĐỔI ƯU TIÊN" phía trên để biết đang chờ gì.
3. Help Bot GPT: code đã xong bước 1-2, chỉ còn thiếu workflow ID thật (mục Giai đoạn 2 phía trên).


## ĐẬP ĐI LÀM LẠI (04/09/2026) — Telebot Main → "Telebot ClickUp Reader"
Quyết định: KHÔNG dùng `Telebot_main.json` (72 node, chưa từng import lên n8n live) nữa. Dựng file
hoàn toàn mới, gọn hơn, chỉ tập trung đọc dữ liệu + tìm/tải file OneDrive.

### File mới: `sub_workflows_modernized/Telebot_ClickUp_Reader.json`
Commit: https://github.com/FachkraftSupply/n8nwf/commit/10ac87bf3f6594760593b9c63048e1920c79010f
26 node (giảm từ 72). Kiến trúc:
```
sub workflow (Execute Workflow Trigger, passthrough)
  -> Phân tích lệnh (Code, đọc Envelope trực tiếp, tự tính route)
  -> Switch: help / task / chitiet / view_file / taotask / (fallback: unknown)
```
- help: text hướng dẫn mới (bỏ mô tả /taotask cũ, thêm ghi chú "đang xây lại bằng AI")
- task: y hệt luồng cũ (Prepare Search -> PostgreSQL search tasks -> Code1 scoring -> Beautify full ->
  Telegram) — ĐÃ SỬA 1 lỗi trong query gốc: ts_rank hard-code chữ 'hnd' thay vì dùng $1, giờ dùng đúng $1.
  ĐÃ BỎ nhánh Discord/Zalo đi kèm (Gộp dữ liệu, Merge2, Execute Workflow gọi "ZALO BOT DEV", Beautify unfull1).
- chitiet: task_detail_sql -> extract output -> Beautify_detail (ĐÃ SỬA lỗi cú pháp thừa dấu } ở link
  OneDrive trong code gốc) -> If1 (có onedrive_link?) -> Telegram thường / telegram inline (nút "Xem file"
  callback_data=view_file:<taskId>, bỏ nút "Upload File" cũ)
- view_file (MỚI, callback từ nút "Xem file"): task_detail_sql (dùng chung) -> Encode Share URL (encode
  OneDrive share link theo chuẩn Microsoft Graph u!<base64url>) -> HTTP Request tới
  graph.microsoft.com/v1.0/shares/{id}/driveItem?$expand=children -> Beautify File List (dựng nút bấm tải
  từng file bằng @microsoft.graph.downloadUrl, KHÔNG qua Telegram upload nên không bị giới hạn 50MB) ->
  Telegram (File List).
  ⚠️ CHƯA TEST ĐƯỢC field name response Graph API thật (không chạy được n8n live trong phiên này) — cần anh
  test kỹ, field @microsoft.graph.downloadUrl có thể khác tùy loại tài khoản OneDrive (personal vs
  SharePoint/business) hoặc cần thêm $select.
- taotask: placeholder — trả lời "đang xây dựng lại bằng AI, chưa khả dụng", KHÔNG gọi ClickUp — an toàn
  100%, không tạo task thật.

### ĐÃ BỎ khỏi workflow (không xóa, giữ trong Telebot_main.json cũ làm tham khảo)
- /taotask thật (cr_task_hs, cr_task_dh, tt_dk, Validate code, toàn bộ chuỗi upload OneDrive)
- zalo code (thử nghiệm dở, đọc sai shape)
- Xử lý ảnh (xóa nền/nén trang/chèn logo) — CẦN CHUYỂN SANG "Bot System Main" khi build workflow đó. Logic
  gốc nằm trong Telebot_main.json (giữ nguyên, KHÔNG XÓA), các node liên quan: Edit Fields1, Check if Photo,
  check caption, nocaption, Get a file xoa nen, Get a file1 nen trang, Get a file chen logo,
  HTTP Request xoa nen(1), HTTP Request nen trang, Extract from File, gui file nen trang, Send a document(1),
  Send a photo message2.
- MySQL cũ (MySQL2, task_detail_sql bản MySQL — đã có bản Postgres thay thế, node MySQL là thừa)

### Việc tiếp theo — CẦN TỪ ANH
1. Import Telebot_ClickUp_Reader.json vào n8n (workflow MỚI, chưa từng có trên live, không rủi ro ghi đè).
2. Test kỹ nhánh view_file trước tiên (rủi ro cao nhất vì chưa test được Graph API response thật).
3. Lấy Workflow ID, gắn vào Gateway node "→ Sub: Telebot Main".
4. Khi nào làm "Bot System Main", quay lại lấy cụm node xử lý ảnh trong Telebot_main.json.


## SQL SYNC + BACKUP (04/09/2026) — Có data thật để test Telebot ClickUp Reader
Vấn đề: anh đã deploy xong Telebot_ClickUp_Reader.json nhưng chưa có data trong `clickup.tasks` để test.

### Workflow mới: `SQL_ClickUp_to_Postgres_Sync.json`
Commit: https://github.com/FachkraftSupply/n8nwf/commit/6ddac314ffc6827de990563ba5cc172633e3e72a
File schema: `sql/02_clickup_tasks_schema.sql`
10 node, config-driven (node "⚙️ Config" — điền list ID + tên custom field, KHÔNG cần sửa code khác):
```
Manual Trigger / Schedule (15 phút) -> ⚙️ Config
  -> Ensure Schema (idempotent, CREATE TABLE IF NOT EXISTS clickup.tasks)
  -> Split Out Lists -> Loop Over Lists -> ClickUp - Get Tasks -> Map Task -> Row -> Upsert Postgres -> (quay lại Loop)
  -> khi xong: Notify Done (Telegram)
```
- Đọc custom field theo TÊN (không phải ID) qua hàm `getCF()` — tránh phải biết ID field, chỉ cần đúng tên
  hiển thị trong ClickUp.
- ⚠️ ClickUp MCP trong phiên chat này bị "No approval received" khi Claude thử gọi `clickup_get_custom_fields`
  để lấy tên field thật — KHÔNG lấy được data live. Tên field trong node Config hiện là PHỎNG ĐOÁN dựa theo
  tên cột đã dùng trong code Telebot cũ (`Phụ trách`, `DKPV`, `PVTC`, `VFS`, `Plan bay`, `Ngày bay`, `Youtube`,
  `OneDrive`, `Link khác`, `Color`) — CẦN ANH KIỂM TRA LẠI cho khớp tên thật trong ClickUp trước khi chạy.
- List ID đã điền sẵ n: List 2025 (`901805909593`), Orders (`901805909357`). Cần điền thêm List 2026 + 3 công
  ty (ELMC/ELHZ/ELHT) nếu muốn đồng bộ đủ.
- Node `ClickUp - Get Tasks` dùng native ClickUp node (`resource: task, operation: getAll`) — CHƯA TEST được
  param chính xác (không chạy được n8n live trong phiên này), có thể cần chỉnh lại qua dropdown sau khi import.

### Backup Postgres hàng ngày → OneDrive — ĐANG CHỜ ANH CHỌN PHƯƠNG ÁN
Đã đề xuất 2 phương án (xem chat):
- **A — pg_dump qua SSH**: đầy đủ nhất (phục hồi bằng `pg_restore` 1 lệnh), cần SSH credential trỏ Mac Mini.
- **B — SQL export thuần n8n**: không cần hạ tầng thêm, export JSON/CSV qua Postgres node + nén zip + upload
  OneDrive, phục hồi cần insert lại thủ công.
Khuyến nghị: làm B trước (nhanh, không rủi ro hạ tầng), nâng cấp A sau nếu cần. QUYẾT ĐỊNH (04/09/2026): làm Phương án B, nhưng DỜI sang Phase 3 (sau khi Phase 2c — SQL Sync có data thật — xong trước). Hiện đang ở Phase 2c: import & chạy thử SQL Sync.

### Việc tiếp theo — CẦN TỪ ANH
1. Kiểm tra/sửa tên custom field trong node "⚙️ Config" của SQL_ClickUp_to_Postgres_Sync.json cho khớp thật.
2. Import + chạy thử (Manual Trigger) — kiểm tra `clickup.tasks` có data.
3. Test lại Telebot ClickUp Reader với data thật.
4. Chọn phương án backup A/B để Claude build.
