# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để nắm được trạng thái hiện tại mà
> không cần đọc lại lịch sử debug dài của các phiên trước — file này chỉ giữ TRẠNG THÁI HIỆN TẠI,
> không giữ tường thuật quá trình (tường thuật đầy đủ nằm ở `docs/CHANGELOG.md`, mới nhất lên trên).

## ✅ SỬA XONG, CHỜ USER XÁC NHẬN (11/09/2026, phiên tiếp 37) — Bug thật: nút "🏷️ Nhóm mention" không hiện nút

User báo sau khi `/user_list` → bấm "🏷️ Nhóm mention", chỉ nhận được 1 tin nhắn có tiêu đề, KHÔNG có
nút nào cả — đúng y hệt rủi ro CHƯA XÁC NHẬN đã cảnh báo trước ở phiên tiếp 20 (xem RULES.md #21):
`inlineKeyboard` với SỐ NÚT ĐỘNG (tùy số nhóm mention đã tạo) đặt bằng 1 expression động cho CẢ field
(`inlineKeyboard: "={{ { rows: $json.rows } }}"`) — `test_workflow` từng báo logic đúng nhưng KHÔNG
xác nhận được hiển thị thật (Postgres/Telegram bị pin khi test), và giờ xác nhận THẬT qua Telegram:
nút không hiện.

**Đã sửa triệt để theo đúng mặc định của dự án (RULES.md #3 — deep-link dạng text thay vì inline
keyboard)**, KHÔNG cố sửa tiếp cách dùng inline keyboard động (đã 2 lần chứng minh không đáng tin cho
số nút thay đổi):
- `Build Mention Menu`: đổi hẳn từ xây `rows` (inlineKeyboard) sang xây TEXT với deep-link
  `<a href="https://t.me/elite_n8n_system_bot?start=mgt_<uid>_<groupId>">✅/➕ Tên nhóm</a>` cho mỗi
  nhóm, kèm `<a href="...?start=um_<uid>">⬅️ Quay lại</a>` ở cuối.
- `Send Mention Menu`: bỏ hẳn `replyMarkup: inlineKeyboard` + field `inlineKeyboard`, chuyển về
  `replyMarkup: none` (tin nhắn text thuần, link bấm được nhờ `parse_mode: HTML`).
- `Admin Extras Router`: thêm nhận diện `/start mgt_<uid>_<groupId>` → route `mention_toggle` (y hệt
  callback `mgt:<uid>:<groupId>` cũ, tái dùng nguyên `Toggle Mention Membership` + luồng refresh panel
  có sẵn) và `/start mmenu_<uid>` → route `mention_menu`, theo đúng pattern đã có sẵn cho `um_<uid>`.

Verify bằng `node -c` (cả 2 Code node parse sạch) + `get_workflow_details` (routing/connections không
đổi, node count vẫn 120), publish lại (`activeVersionId: 7b411b06-1be5-408f-99aa-016723317e12`).
KHÔNG test được qua MCP (Telegram Trigger không hỗ trợ `execute_workflow` trực tiếp).

**Việc cần user làm**: vào `/user_list` → chọn 1 user → bấm "🏷️ Nhóm mention" → xác nhận thấy DANH
SÁCH LINK (không phải nút) với đúng số nhóm mention đã tạo, bấm thử 1 link → xác nhận toggle đúng
(icon ✅/➕ đổi) và panel refresh lại đúng trạng thái mới.

**✅ Audit độc lập PASS** (subagent thứ 2) — đọc lại JSON thật, xác nhận: thứ tự điều kiện trong
`Admin Extras Router` không bị 1 điều kiện chung chung nào chặn nhầm route mới; `Build Mention Menu`
escape HTML đúng cho `label` (dữ liệu do admin gõ qua `/tao_group`, tránh lặp lại bug "Unsupported
start tag" đã gặp trước); giá trị `?start=` chỉ gồm chữ số (uid + serial id), không chứa ký tự cấm;
connections + node count (120) không đổi. **1 finding nhỏ tìm được + đã sửa ngay**: node `Send Mention
Menu` dùng `$json` trần thay vì tham chiếu tường minh (Rule #2) — không sai ở hiện tại (chỉ 1 node
đứng trước) nhưng là rủi ro âm thầm nếu sau này có ai chèn thêm node vào giữa. Đã đổi sang
`$('Build Mention Menu').first().json...`, verify + publish lại (`activeVersionId:
a749356c-eb34-4d7d-bb5c-16df9048b4a6`).

## ✅ SỬA XONG, CHỜ USER XÁC NHẬN (11/09/2026, phiên tiếp 35) — Bug thật: `/help` (Admin) mất phản hồi hoàn toàn

User báo "menu help của admin lại biến mất". Tra execution log thật (`2064`, `2065`, `2066` — user tự
gõ `/help`, `/tao_group` liên tiếp lúc debug) ra đúng nguyên nhân gốc: node `Nội dung lệnh help`
(`Telebot Admin System`) bị **SyntaxError** khi chạy — dòng text mới thêm ở phiên trước (mục "Nhóm
mention") có 2 dấu backtick (`` ` ``) THỪA nằm ngay TRONG chuỗi template literal bao ngoài
(`` helpText = `...` ``): `` (`<code>@@all</code>` = tất cả...) `` — backtick lạc làm JS hiểu nhầm là
kết thúc chuỗi sớm, phần còn lại phá vỡ cú pháp → node lỗi ngay, KHÔNG có tin nhắn nào được gửi (giống
hệt hiện tượng "bot im lặng" — không phải nút/route sai, mà lệnh `/help` chưa từng chạy được tới bước
gửi tin từ lúc phiên trước thêm đoạn text này).

**Đã sửa**: bỏ 2 dấu backtick thừa, giữ nguyên `<code>@@all</code>` dạng HTML tag bình thường (không
cần backtick ở đây — nhầm lẫn cú pháp Markdown vào code JS/HTML). Verify bằng `node -c` xác nhận file
JS parse được, verify lại qua `get_workflow_details` xác nhận đúng nội dung + connections
(`Switch`→`Nội dung lệnh help`→`help`) không đổi, publish lại (`activeVersionId:
5ecf1ab4-2a73-46be-8620-5c821d9dd76d`). KHÔNG test được qua MCP (Telegram Trigger không hỗ trợ
`execute_workflow` trực tiếp) — cần user gõ lại `/help` qua Telegram để xác nhận.

**Việc cần user làm**: gõ `/help` trên bot Admin (`Telebot Admin System`) xác nhận đã trả lời bình
thường (bao gồm cả đoạn "Nhóm mention" mới).

## ✅ BUILD XONG + TEST THẬT MỘT PHẦN (11/09/2026, phiên tiếp 34) — Fix knowledge base cho `/error_logs`

Yêu cầu user: khi 1 lỗi được sửa xong, ghi lại vào Postgres kèm link execution + nội dung lỗi + cách
sửa, để lần sau agent (Claude Code) đọc lại được thay vì debug lại từ đầu.

**Workflow mới `GW Error Knowledge`** (`GSz6ZluGT5jCgdEc`, đã publish) — Webhook POST
`https://n8n.toididuhoc.net/webhook/gw-error-knowledge`, 2 action:
- `{action:"search", keyword}` → SELECT lỗi ĐÃ TỪNG `status='fixed'` khớp từ khóa (workflow_name/
  node_name/error_message/fix_description), trả về `fix_description` đã lưu.
- `{action:"log_fix", id, fixDescription, fixedBy}` → UPDATE dòng `error_logs` đó `status='fixed'`
  + lưu `fix_description`/`fixed_at`/`fixed_by`.

Gọi qua n8n MCP `execute_workflow` (`triggerNodeName:"From Webhook"`) hoặc HTTP POST trực tiếp.
**Lưu ý kỹ thuật quan trọng phát hiện khi build**: dự định ban đầu dùng `executeWorkflowTrigger` (như
`GW Mention Resolver`) nhưng tool `execute_workflow` của n8n MCP KHÔNG hỗ trợ gọi trực tiếp loại
trigger này (chỉ hỗ trợ Schedule/Webhook/Form/Chat) — đã đổi sang Webhook trigger giữa chừng, xác
nhận hoạt động qua 1 execution thật (`2023`, DDL 3 cột mới chạy thật, routing đúng).

**Mở rộng `/error_logs`+`/error_log_now`** (`Telebot Admin System`) — SQL bọc thêm CTE thống kê
(✅ đã sửa / 🔓 còn mở / Σ tổng, 7 ngày qua) + trả thêm cột `id` từng dòng để agent biết log_fix vào
đâu. Prompt Claude Code nhúng sẵn trong tin nhắn giờ có thêm 2 bước: TRƯỚC khi sửa → gọi
`action:"search"` tra cứu; SAU khi sửa xong → gọi `action:"log_fix"` lưu lại. Không thay thế
CHANGELOG.md/PROJECT_STATUS.md, chỉ bổ sung tra cứu nhanh bằng SQL.

**Chưa test được** (không tự làm tiếp được, cần dùng thật qua ít nhất 1 chu kỳ sửa lỗi): action
`log_fix` mới verify đúng SQL bằng mắt, CHƯA chạy thật lần nào (test bằng `action:"search"` an toàn
hơn nên chỉ test nhánh đó) — lần đầu `/error_logs` chạy ra 1 lỗi thật và Claude Code phiên sau làm
theo đúng prompt mới (gọi `log_fix` sau khi sửa) sẽ là lần xác nhận đầu tiên toàn bộ vòng lặp hoạt
động đúng.

**✅ Audit độc lập PASS + tìm ra 1 bug thật, đã sửa**: subagent đọc lại JSON thật cả 2 workflow xác
nhận toàn bộ wiring/SQL/JS đúng thiết kế (routing Switch cả 2 workflow đúng, `Switch (Admin Extras)`
17 route + `Send Detail Panel` không bị ảnh hưởng, code JS không còn tham chiếu node cũ đã xóa). Bug
tìm được: `Errors: Query Recent`/`Errors: Mark Reported` thiếu `alwaysOutputData: true` → khi 0 lỗi
trong 7 ngày, `CROSS JOIN` với CTE thống kê ra 0 dòng → node bị skip hoàn toàn → tin "✅ Không có lỗi
nào" không bao giờ gửi được. Đã sửa + publish lại (`activeVersionId: 13e755f0-dfd7-40ea-ae86-fc3eec9e0c42`).
Hạn chế nêu trong audit: không có tool để tự xác nhận `ALTER TABLE` đã chạy thật trên Postgres thật
(chỉ có Supabase MCP, không phải Docker Postgres chính của dự án) — dựa vào kết quả execution `2023`
đã chạy thật thành công (DDL không báo lỗi) làm bằng chứng.

**Rủi ro bảo mật đã cân nhắc**: webhook `GW Error Knowledge` KHÔNG có xác thực (authentication:
none) — công khai trên internet nếu ai đó đoán đúng URL. Chấp nhận vì dữ liệu chỉ là mô tả lỗi/cách
sửa nội bộ (không PII, không tài chính), rủi ro cao nhất là spam dòng rác vào `error_logs` (dễ dọn).
Nếu muốn siết lại, có thể thêm `headerAuth` credential sau.

## ⏳ Chờ user tắt Privacy Mode trên BotFather — `/tomtat` (11/09/2026, phiên tiếp 23)

User báo gõ `/tomtat` (ảnh kèm caption) trong nhóm "Elite Nhà cửa" không có phản hồi gì. Đọc log
thật + ảnh chụp danh sách thành viên nhóm xác nhận nguyên nhân gốc: bot `ClickupElite`
(`@Elite_clickup_bot`, workflow `GW Gateway - Telegram (DEV)`) đang **Privacy Mode BẬT** trên
BotFather → Telegram KHÔNG chuyển tiếp ảnh-kèm-caption-lệnh cho bot này (chỉ chuyển tin nhắn CHỮ
thường bắt đầu bằng `/`), khớp đúng badge "has no access to messages" trong ảnh user gửi, và khớp
việc Gateway không có execution nào ở đúng thời điểm đó.

**Đã sửa trước ở phía workflow** (node `GW-01 Envelope`): thêm chặn sớm — trong group/supergroup,
tin nhắn KHÔNG phải lệnh (`/xxx`, kiểm tra cả `text` lẫn `caption`) thì bỏ qua hoàn toàn, không
chạy auth-check/audit-log/reply gì cả. Bước này BẮT BUỘC phải làm TRƯỚC khi tắt Privacy Mode, vì
nếu không, sau khi tắt Privacy Mode bot sẽ nhận mọi tin nhắn trong nhóm → mọi thành viên CHƯA được
cấp quyền sẽ bị bot trả lời công khai "bạn chưa có quyền..." NGAY TRONG GROUP mỗi khi họ nhắn bất kỳ
câu gì (bug tiềm ẩn nghiêm trọng, tự phát hiện qua đọc code trước khi user gặp phải).

**Việc còn lại CẦN USER làm thủ công qua BotFather** (không tự động hóa được, thao tác ngoài n8n):
mở `@BotFather` → `/mybots` → chọn bot `ClickupElite` → *Bot Settings* → *Group Privacy* →
**Turn off**. Sau đó `/tomtat`/`/xoanen` gửi kèm ảnh trong group sẽ hoạt động bình thường.

## ✅ Fix help text bot user (11/09/2026, phiên tiếp 22)

User báo `/help` bên bot chính (user, `Telebot ClickUp Reader`, node "Nội dung lệnh help") "chưa chia
nhóm để hướng dẫn và chưa có tiếng việt". Kiểm tra ra 2 lỗi thật: (1) toàn bộ chữ Việt viết KHÔNG DẤU
("Danh sach lenh" thay vì "Danh sách lệnh"); (2) emoji bị viết sai thành escape kiểu Python
`\U0001F4D8` (không phải cú pháp unicode hợp lệ trong JS) → khi gửi thật, user thấy chữ thô
"U0001F4D8..." thay vì icon 📘/👉/💬 — text nhìn rất lộn xộn, giải thích đúng cảm nhận "chưa có tiếng
việt" của user. Đã viết lại toàn bộ: emoji UTF-8 thật nhúng trực tiếp, có dấu đầy đủ, chia 5 mục rõ
ràng (1️⃣ Tìm task, 2️⃣ Lịch sử chat, 3️⃣ Mention nhóm — MỚI THÊM vì user thường cũng gõ được
`@@all`/`@@<nhóm>`, chưa từng được ghi trong help cũ, 4️⃣ Upload OneDrive, 5️⃣ Sau khi forward). Giữ
nguyên toàn bộ placeholder dạng `&lt;...&gt;` (escape HTML) để không dính lại đúng bug "Unsupported
start tag" vừa fix ở mục dưới. Đối chiếu: help bên bot Admin (`Telebot Admin System`) không bị lỗi
này (emoji/dấu đều ổn từ trước), chỉ bot user bị. Publish xong, verify `versionId`==`activeVersionId`.

## ✅ FIX BUG THẬT + MỞ RỘNG tính năng Mention Group (11/09/2026, phiên tiếp 21)

User test thật qua Telegram phát hiện đúng rủi ro đã cảnh báo ở phiên trước ("🏷️ Nhóm mention" —
dynamic keyboard chưa test thật) là BUG THẬT, không phải chỉ "chưa xác nhận". Đọc execution log lỗi
thật (`eWtu7Qs85Hes0HuP`, execution #1882) ra 2 lỗi:

1. **`Send Mention Menu` gửi thất bại 100%**: Telegram trả lỗi "Bad Request: can't parse entities:
   Unsupported start tag "tên"" — do text gợi ý "Dùng /tao_group **&lt;tên&gt;** để tạo mới" có dấu
   `<>` thật, bị Telegram hiểu là HTML tag lạ (vì message gửi `parse_mode: HTML`). Fix: đổi thành
   "ten_nhom" (không dấu ngoặc).
2. **`inlineKeyboard.rows` không dynamic được** — phiên trước thử 2 cách (a) để cả field `inlineKeyboard`
   thành 1 string expression, và (b) chỉ để riêng field con `rows` thành string expression trong khi
   `inlineKeyboard` vẫn là object. Cách (b) được chọn dùng (vì validator ít phàn nàn hơn) và **publish
   rồi** — nhưng log lỗi thật cho thấy node vẫn resolve ra đúng cấu trúc CŨ (17 hàng rỗng tĩnh từ lúc
   scaffold ban đầu), tức cách (b) KHÔNG hoạt động ở runtime dù save/validate không báo lỗi gì bất
   thường. Đây là bằng chứng thật đầu tiên trong dự án này cho biết: field con kiểu `array` (như
   `rows`) NẰM TRONG 1 fixedCollection object KHÔNG được resolve expression đúng — phải để CẢ field
   cha (`inlineKeyboard`) thành 1 string expression (cách a) thì mới chạy đúng. Đã đổi lại về cách
   (a): `inlineKeyboard: "={{ { rows: $json.rows } }}"`, verify lại bằng `get_workflow_details` xác
   nhận đã lưu đúng dạng string (không bị nested-path bug của Rule #16), publish lại
   (`activeVersionId: 8e5a8a0c-d8cc-4844-b5e8-82dd452b9174`).
   - **Phát hiện phụ quan trọng**: lúc đọc lại workflow để debug, thấy `versionId` (draft) khác
     `activeVersionId` (live) — nghĩa là ít nhất 1 lần ở phiên trước, sửa xong QUÊN publish (hoặc bị
     phiên khác/song song ghi đè draft sau khi publish). Từ nay: LUÔN diff `versionId` vs
     `activeVersionId` sau mỗi `get_workflow_details`, không chỉ tin `publish_workflow` trả
     `success:true` một lần là xong.
3. **Trả lời câu hỏi user "chỉ mention người bot ghi nhận thôi phải không?"** — ĐÚNG, đây là thiết kế
   có chủ đích từ đầu (không phải bug): Bot Telegram thường không có quyền lấy full member list của
   group lớn, nên `@@all`/`@@<nhóm>` chỉ mention được người đã có ít nhất 1 dòng trong
   `gateway.group_chat_log` (tức đã từng nhắn chữ trong group đó) — thành viên im lặng chưa từng nhắn
   sẽ không bị mention được. Đã giải thích lại cho user, không có gì để fix.
4. **Trả lời câu hỏi "/tao_group + /user_list chỉ bot Admin dùng được đúng không?"** — ĐÚNG, toàn bộ
   quản lý nhóm mention (tạo nhóm, thêm/xóa thành viên) đi qua `Admin Extras Router` /
   `Switch (Admin Extras)` trong `Telebot Admin System`, chỉ Telegram Trigger của bot Admin (System
   Bot) mới bắn vào router này — bot chính (user) không có route nào tới các lệnh này. Ngược lại,
   việc GÕ `@@<nhóm>`/`@@all` để KÍCH HOẠT mention là ở group chat thường, qua `GW Crawl Bot - Group
   Capture` (không qua router Admin) — ai gõ trong group cũng kích hoạt được, không cần quyền admin.
5. **Ý tưởng mới của user: nhóm mention "universal" (dùng chung mọi group) nhưng chỉ mention người
   THỰC TẾ có mặt trong group đang gõ lệnh** — đánh giá KHẢ THI, đã tự triển khai draft để user đánh
   giá: sửa `Resolve Mention Users` trong `GW Mention Resolver` (nhánh named-group) thêm điều kiện
   `EXISTS (SELECT 1 FROM gateway.group_chat_log gcl WHERE gcl.chat_id=$1 AND gcl.user_id=bu.user_id)`
   — tái dùng đúng tín hiệu "đã từng nhắn trong group này" mà `@@all` đang dùng, thay vì lấy toàn bộ
   thành viên global của nhóm mention. Publish rồi (`activeVersionId: 4be88e1a-72ac-49d0-a72a-e1877b2df209`).
   **Giới hạn cố hữu (không tránh được)**: vẫn chỉ nhận diện được người ĐÃ NHẮN chữ trong group đó ít
   nhất 1 lần — không phải danh sách member Telegram thật (Bot API không cho lấy đầy đủ member list
   nhóm lớn mà không cần quyền admin đặc biệt). Nếu user join nhóm nhưng chưa từng nhắn gì, sẽ không
   được mention dù có trong nhóm mention và đang ở trong group đó thật.

**Cần user test lại thật qua Telegram** (lần trước không test được vì bug #1/#2 chặn ngay từ đầu):
bấm lại "🏷️ Nhóm mention" trong `/user_list` xem nút toggle hiện đúng chưa, và gõ `@@<tên nhóm>`
trong 1 group có/không có thành viên nhóm đó từng nhắn để xác nhận filter mới hoạt động đúng.

**⏳ User chủ động dời việc test này lại ~1 tuần** (hẹn 18/09/2026) để có đủ dữ liệu chat thật trong
nhóm trước khi test filter "chỉ mention người đã từng nhắn trong đúng group" — KHÔNG phải do bug hay
vướng mắc, chỉ là chờ đủ data. Phiên sau nhắc lại đúng 3 việc cần test ở trên nếu user quên.

## ✅ BUILD XONG, CHỜ AUDIT + TEST THẬT (10/09/2026, phiên tiếp 20) — Tính năng Mention Group (`@@nhóm`/`@@all`)

**Đã build + publish TOÀN BỘ 5 stage** (schema, `GW Mention Resolver`, hook Crawl Bot, `/tao_group`,
mở rộng `/user_list`) — tự làm tới giới hạn tối đa có thể mà không cần người thật, đúng yêu cầu user.
CHƯA đóng hẳn: đang chờ kết quả audit subagent + user test thật qua Telegram (xem "Điểm dừng cần
NGƯỜI THẬT" ở cuối mục này).

**Yêu cầu user**: admin tạo "nhóm mention" (danh sách user đặt tên) qua `/tao_group`; gán/gỡ user vào
nhóm qua mở rộng `/user_list` có sẵn; user thường gõ `@@<tên nhóm>` trong 1 nhóm Telegram → bot
mention tất cả user trong nhóm mention đó; `@@all` → mention tất cả user đã từng nhắn trong group đó.
User yêu cầu tách hẳn logic xử lý mention sang 1 SUB-WORKFLOW riêng để nhẹ, tối ưu, tự làm tới khi
cần người thật can thiệp.

**Thiết kế đã chốt** (dựa trên research thật qua subagent đọc live workflow, không đoán):
- **2 bảng mới**: `gateway.mention_groups` (id, group_key UNIQUE, label, created_by, created_at),
  `gateway.mention_group_members` (group_id FK, user_id, PK kép). KHÔNG dual-write Supabase (đã biết
  dual-write hiện đang trỏ nhầm cùng credential Docker, vô nghĩa — bỏ hẳn cho gọn, đúng tinh thần
  "tối ưu nhẹ nhất" user yêu cầu).
- **`/tao_group <tên>`** (Admin System, bot System, KHÔNG qua Gateway) — lệnh 1 phát ăn ngay, KHÔNG
  cần multi-turn hỏi-đáp (tránh phải build thêm bảng pending_state chỉ cho 1 lệnh admin ít dùng).
- **Mở rộng `/user_list`**: thêm nút "🏷️ Nhóm mention" vào panel chi tiết user có sẵn (`Send Detail
  Panel`) → mở panel MỚI liệt kê tất cả mention_groups dạng nút toggle (✅ đã có / ➕ chưa có), bấm
  1 nút = INSERT/DELETE luôn (1 câu SQL kiểu CTE delete-if-exists-else-insert, "đi nhờ" 1 round-trip
  theo đúng Rule #11) rồi refresh lại panel — TÁI SỬ DỤNG NGUYÊN VẸN pattern "toggle rồi refresh
  panel tại chỗ" đã có sẵn cho phần cấp/xóa quyền bot (`ga:`/`rv:`), không phát minh lại UI mới.
- **Sub-workflow MỚI `GW Mention Resolver`** (Execute Workflow Trigger, gọi từ `GW Crawl Bot - Group
  Capture`): nhận `{chatId, messageId, messageThreadId, tokens}` → tách `all` vs tên nhóm cụ thể →
  query đúng bảng tương ứng → build danh sách mention (ưu tiên `@username`, fallback `tg://user?id=`
  cho user không có username) → gửi reply bằng CHÍNH credential `Elite Crawl Bot` (bot này đã có mặt
  sẵn trong nhóm, Privacy Mode đã tắt sẵn — xác nhận qua research, không cần bot mới/đổi quyền gì).
  **`@@all` = mention mọi user ĐÃ TỪNG nhắn tin trong group đó** (lấy từ `gateway.group_chat_log`,
  KHÔNG phải member list thật của Telegram — Bot API không cho bot thường lấy danh sách member đầy
  đủ của group lớn, đây là cách khả thi duy nhất không cần quyền admin group).
- **Hook phát hiện trong `GW Crawl Bot - Group Capture`**: `Build Envelope (Crawl) + Filter Group`
  thêm regex tách token `@@\w+` từ `message_text` (không đổi hành vi ghi log hiện có) → nếu có token
  → gọi `GW Mention Resolver` qua Execute Workflow (fire-and-forget, `waitForSubWorkflow: false`,
  đúng pattern đã dùng cho backup/reconcile) SONG SONG với việc ghi log bình thường, không chặn nhau.
  Token `@@xxx` KHÔNG khớp nhóm nào đã tạo → im lặng bỏ qua (không spam báo lỗi cho gõ nhầm/tình cờ).
- **KHÔNG cần sửa Gateway** (`GW Gateway - Telegram`) — cả `/tao_group` (bot System, own trigger) lẫn
  detect `@@` (bot Crawl, own trigger) đều KHÔNG đi qua Gateway/COMMAND_MAP, xác nhận qua research.

### Stage đã xong:
- ✅ **`GW Mention Resolver`** — workflow MỚI, id `ESbedUROf4udAkY6`, đã publish
  (`activeVersionId: ee49bc44-62b0-4408-9347-f44bbeb0a797`). 7 node: `From Crawl Bot`
  (`executeWorkflowTrigger`, input `{chatId, messageId, messageThreadId, tokens}`) → `Ensure Mention
  Tables` (DDL 2 bảng) → `Parse Mention Tokens` (tách `all` vs tên nhóm) → `Resolve Mention Users`
  (1 câu SQL UNION ALL: nhánh `@@all` lấy từ `group_chat_log` — vì user chỉ nhắn trong group có thể
  KHÔNG có trong `bot_users`; nhánh tên nhóm cụ thể lấy từ `bot_users` JOIN `mention_group_members` —
  vì thành viên nhóm do admin chọn qua `/user_list`, chắc chắn đã có trong `bot_users`) →
  `Build Mention Text` (escape HTML, `@username` hoặc fallback `tg://user?id=`, giới hạn 50
  mention/tin) → IF `Has Users To Mention?` → gửi bằng credential **Elite Crawl Bot** (bot này đã có
  mặt sẵn trong nhóm, Privacy Mode tắt sẵn — xác nhận qua research, không cần bot/quyền mới).
  Đã build xong node `setNodeParameter` cho trigger bị lỗi lồng sai vị trí đúng như RULES.md #16 cảnh
  báo trước — tự phát hiện qua `get_workflow_details`, sửa bằng `removeNode`+`addNode`.
  **Đã test bằng `test_workflow`+pin data 2 kịch bản**: (1) `@@all` với 2 user giả (có/không có
  username) → text mention đúng cả 2 dạng; (2) tên nhóm không tồn tại + 0 kết quả → đúng như thiết
  kế, KHÔNG gửi gì (nhánh false của IF), im lặng bỏ qua.
- ✅ **Hook `@@` vào `GW Crawl Bot - Group Capture`** — publish `activeVersionId:
  c15976cb-142b-4f34-b981-37c10f227976`. `Build Envelope` thêm `mentionTokens` (regex `@@(\w+)`,
  lowercase, dedupe), KHÔNG đổi field ghi log cũ. Fan-out song song: ghi log (như cũ) + IF
  `Has Mention Tokens?` → `Trigger Mention Resolver` (Execute Workflow, `waitForSubWorkflow:false`,
  `onError:continueRegularOutput` — lỗi ở resolver KHÔNG làm hỏng việc ghi log chính). Verify wiring
  đầy đủ qua `get_workflow_details` trước khi publish.

**⚠️ Rủi ro CHƯA kiểm chứng được** (như RULES.md #21 — `test_workflow` pin hết node Postgres/Telegram
nên KHÔNG chạy câu SQL thật, Telegram Trigger cũng không execute được qua MCP): câu SQL
`Resolve Mention Users` (UNION ALL + DISTINCT ON + `ANY($2::text[])`) và toàn bộ chuỗi `@@all` CHƯA
chạy thật lần nào — cú pháp đã rà kỹ bằng tay, tự tin đúng, nhưng **CẦN 1 tin nhắn `@@all` thật gõ
trong nhóm Telegram có Elite Crawl Bot để xác nhận** — đây là điểm dừng cần người thật. Sẽ build tiếp
2 stage còn lại (không cần test thật ngay) trước khi báo điểm dừng này cho user.

- ✅ **`/tao_group` (Telebot Admin System)** — publish `activeVersionId: d2081f91-30c7-46c0-af04-3eb1dc639beb`.
  `Admin Extras Router` thêm route `create_group` (parse `/tao_group <tên>`), `mention_menu`
  (`mmenu:<uid>`), `mention_toggle` (`mgt:<uid>:<groupId>`) — giữ nguyên TOÀN BỘ 18 route cũ.
  `Switch (Admin Extras)` từ 14 output (không có fallback) → 17 output, verify lại đủ 14 kết nối cũ
  + 3 kết nối mới (14→`Ensure Mention Tables (Admin)`, 15→`Mention Menu Query`,
  16→`Toggle Mention Membership`) qua `get_workflow_details`. Chuỗi mới: DDL → `Slug Group Name`
  (slugify tên → group_key, chặn tên rỗng) → IF hợp lệ → INSERT `ON CONFLICT DO NOTHING RETURNING`
  (báo "đã tồn tại" nếu trùng) → reply.
- ✅ **Mở rộng `/user_list` (Telebot Admin System)** — cùng đợt publish trên. `Send Detail Panel`
  thêm nút thứ 4 "🏷️ Nhóm mention" (giữ nguyên 6 nút cũ). Panel mới `Mention Menu Query` →
  `Build Mention Menu` → `Send Mention Menu`: liệt kê TẤT CẢ mention_groups dạng nút toggle
  (✅ đã có / ➕ chưa có), bấm 1 nút = `Toggle Mention Membership` (1 câu SQL CTE delete-if-exists-
  else-insert, đúng Rule #11) rồi quay lại `Mention Menu Query` refresh tại chỗ — TÁI SỬ DỤNG
  nguyên request "toggle rồi refresh" đã dùng cho quyền bot, tham chiếu `uid` tường minh qua
  `$('Admin Extras Router').first().json.extraUid` (không dùng `$json.uid` vì 1 trong 2 nguồn vào
  là `Toggle Mention Membership` không có field `uid`).
- ✅ **Đã cập nhật `/help` (Admin)** thêm `/tao_group` + giải thích `@@nhóm`/`@@all`.
- **✅ Audit PASS (10/09/2026)** — subagent độc lập đọc lại JSON thật cả 3 workflow, xác nhận PASS
  toàn bộ ~15 điểm kiểm tra (SQL syntax, mode Code node, escape HTML trước khi build link, cap 50
  mention, IF false-branch im lặng đúng thiết kế, ghi log cũ không bị ảnh hưởng, 2 nhánh song song
  không phụ thuộc nhau, `Admin Extras Router` giữ nguyên đủ 18 route cũ, `Switch (Admin Extras)`
  đúng cả 17/17 output, `Send Detail Panel` giữ nguyên đủ 6 nút cũ, chuỗi `/tao_group` và mention-menu
  đúng thiết kế, `/help` giữ nguyên đủ nội dung cũ). **Không tìm thấy bug mới nào.** Rủi ro
  `Send Mention Menu` (bàn phím số nút động) được xác nhận là điểm DUY NHẤT chưa chắc chắn — mọi thứ
  khác đã verify xong bằng JSON thật, không cần đoán.

**⚠️ 1 rủi ro KHÔNG THỂ tự xác nhận, đã CHẤP NHẬN chờ test thật** (đúng tinh thần RULES.md #21, mở
rộng từ "loại replyMarkup" sang "số lượng nút biến động"): node `Send Mention Menu` cần hiện SỐ
LƯỢNG nút KHÁC NHAU tùy số nhóm mention đã tạo (nút toggle) — đây là bàn phím Telegram ĐẦU TIÊN
trong cả dự án có SỐ NÚT không cố định (mọi bàn phím khác từ trước tới giờ đều số nút cố định).
Đã thử 2 cách viết `inlineKeyboard.rows` dạng expression, cả 2 đều bị validator tĩnh của
`update_workflow` báo sai kiểu (`expected array, got string`) dù đã lưu được và publish thành công
(giống các cảnh báo validator "false-positive" đã gặp trước — nhưng đây liên quan trực tiếp tới
render nút, KHÔNG thể tự tin như trường hợp Switch fallback trước đó). **CHƯA xác nhận được nút có
hiện đúng hay không — bắt buộc cần bấm thử "🏷️ Nhóm mention" qua Telegram thật.**

### Điểm dừng cần NGƯỜI THẬT (đã làm tới đây, không tự làm tiếp được nữa):
1. Gõ `@@all` thật trong 1 nhóm Telegram có Elite Crawl Bot → xác nhận bot mention đúng người, xác
   nhận câu SQL UNION ALL ở `GW Mention Resolver` chạy thật không lỗi.
2. Gõ `/tao_group <tên>` thật trên bot Admin → xác nhận tạo nhóm thành công, thử gõ `@@<tên nhóm>`
   trong 1 nhóm Telegram (SAU KHI đã thêm ít nhất 1 user vào nhóm qua bước 3) → xác nhận đúng người
   được mention.
3. Vào `/user_list` → chọn 1 user → bấm "🏷️ Nhóm mention" → **XÁC NHẬN NÚT TOGGLE CÓ HIỆN RA ĐÚNG SỐ
   LƯỢNG KHÔNG** (rủi ro chưa xác nhận ở trên) → bấm thử toggle 1 nhóm → xác nhận panel refresh đúng
   trạng thái ✅/➕.

## 🔖 Bàn giao cuối phiên (10/09/2026, phiên tiếp 19) — dừng ở đây, mai làm tiếp

Tất cả thay đổi trong ngày đã publish + commit/push GitHub đầy đủ, không có việc dở dang giữa chừng.
**Việc cần user test khi rảnh** (xem chi tiết ở mục "phiên tiếp 19"/"18" ngay bên dưới):
1. `/lichsu` (bot Admin) — xác nhận tin tóm tắt vẫn có link + nút chọn ngày khác; `/error_log_now` —
   xác nhận KHÔNG còn dính nút ngày nữa (vừa fix bug thật, publish rồi nhưng chưa có user xác nhận).
2. `/timkiem <từ khóa>` (không cần chat_id) cả 2 bot — đã fix + tự verify qua execution log, chưa có
   user xác nhận trực tiếp qua Telegram.
3. Tính năng xóa file OneDrive/thu hồi forward (phiên tiếp 14) — vẫn đang chờ user dán token Zalo
   thật vào node `OD Delfwd: Announce Zalo Deleted` + test thật (xem mục phiên tiếp 14 nếu quên chi
   tiết).

**Chưa có quyết định** (không phải bug, chỉ đang chờ user chốt hướng, KHÔNG tự làm nếu chưa được OK):
- Refactor `Telebot ClickUp Reader` thành sub-workflow nhỏ hơn.
- 3 ý tưởng roadmap mới: mention `@@group`/`@@all`, quản lý nhóm mention qua `/tao_group`+`/user_list`,
  AI đọc tin nhắn visa/vé máy bay để tự update ClickUp (xem mục "phiên tiếp 16" để nhớ lại chi tiết).
- Chuyển bảng `gateway.notify_targets` sang tính năng Data Table của n8n (đã tư vấn pro/cons, chưa
  quyết).

Phiên sau: đọc mục "🔖 Bàn giao" này trước, rồi đọc tiếp các mục bên dưới theo thứ tự nếu cần chi
tiết kỹ thuật.

## ⚙️ QUY TRÌNH BẮT BUỘC khi build/sửa workflow (áp dụng MỌI phiên, không có ngoại lệ)

Đúc kết sau nhiều lần dính lỗi im lặng (xem RULES.md, hiện 19 mục) — quy trình dưới đây tồn tại vì
LÝ DO CỤ THỂ, không phải thủ tục hình thức. Bỏ qua bước nào cũng từng gây hậu quả thật (có lần sập
toàn bộ bot cho mọi user).

**Trước khi sửa:**
1. Đọc `docs/RULES.md` (toàn bộ, không chỉ lướt tiêu đề) + `docs/FAQ.md` — đặc biệt các mục liên
   quan trực tiếp tới loại thay đổi sắp làm (thêm node mới → mục 18; sửa node cũ → mục 16; thêm cột
   dữ liệu đi qua nhiều workflow → mục 19; sửa inline keyboard → mục 14).
2. Gọi **n8n skill** phù hợp trước khi viết code/thiết kế node (dùng tool `Skill`, KHÔNG tự đoán
   cú pháp/pattern từ trí nhớ) — tối thiểu 1 trong số: `n8n-workflow-patterns` (chọn đúng pattern
   trước khi build), `n8n-node-configuration` (tham số chính xác của node cụ thể), `n8n-validation-expert`
   (đọc hiểu lỗi validate), `n8n-code-javascript` (viết Code node đúng chuẩn), `n8n-subworkflows`
   (khi động tới ranh giới Gateway ↔ sub-workflow), `n8n-expression-syntax`, `n8n-error-handling`.
3. Nếu tính năng đi qua ranh giới Gateway ↔ sub-workflow, hoặc thêm 1 cột dữ liệu mới — liệt kê rõ
   TẤT CẢ điểm đọc + ghi liên quan (RULES.md #19) trước khi bắt đầu sửa, không sửa xong rồi mới nhớ ra.

**Trong lúc sửa:**
4. Node mới (DDL/gọi API ngoài) → `setNodeSettings` (`alwaysOutputData`/`onError`) TRONG CÙNG batch
   `update_workflow` với `addNode` (RULES.md #18) — không tách 2 lần gọi.
5. Sửa tham số/credential của node ĐÃ TỒN TẠI → ưu tiên `updateNodeParameters`/`setNodeParameter`,
   nhưng KHÔNG tin ngay — xem bước 6.

**Sau khi sửa, TRƯỚC khi publish:**
6. `get_workflow_details` đọc lại workflow, xác nhận ĐÚNG giá trị mới có mặt ở ĐÚNG vị trí — không
   tin `appliedOperations` khớp số lượng nghĩa là đã áp dụng đúng (RULES.md #16). Nếu sai/thiếu →
   `removeNode` + `addNode` lại (đã xác nhận hoạt động 100%), không thử lại y hệt thao tác cũ.
7. Nếu trigger không execute trực tiếp qua MCP được (Telegram Trigger, `executeWorkflowTrigger`) —
   dùng `prepare_workflow_pin_data` + `test_workflow` mô phỏng input thật (Code/IF/Switch chạy logic
   thật, Postgres/Telegram/HTTP tự động bị pin nên an toàn không gửi tin/ghi DB thật) để xác nhận
   OUTPUT đúng trước khi để user tự test qua Telegram thật.
8. `publish_workflow` — BẮT BUỘC ngay sau mỗi lần update workflow đang active (RULES.md #12).

**Sau khi publish, trước khi báo "xong" cho user:**
9. Với thay đổi vừa/lớn (≥3 node bị sửa, hoặc đụng ranh giới Gateway↔sub-workflow, hoặc thêm cột dữ
   liệu mới) — dùng tool `Agent` (subagent_type mặc định, chạy độc lập/background) giao nhiệm vụ
   AUDIT LẠI: đọc RULES.md/FAQ.md mới nhất, đọc lại CHÍNH workflow vừa sửa qua `get_workflow_details`
   (không tin mô tả của phiên chính, tự tra JSON thật), đối chiếu từng thay đổi có đúng ý định không,
   báo PASS/FAIL kèm bằng chứng cụ thể (tên node + giá trị field). Đây là lớp kiểm tra ĐỘC LẬP thứ 2,
   không phải lặp lại bước 6 — subagent không có ngữ cảnh "tin tưởng sẵn" vào các bước trước.
10. Cập nhật `PROJECT_STATUS.md` (mục mới lên đầu) + `CHANGELOG.md` ngay, dù user chưa test xong —
    ghi rõ "ĐÃ BUILD, CHƯA TEST THẬT" nếu chưa có xác nhận qua Telegram thật.

> Tài liệu khác: `docs/ARCHITECTURE.md` (thiết kế hệ thống, mục 4b tính năng Upload OneDrive/Zalo,
> mục 9 nợ kỹ thuật/refactor), `docs/GUIDE_SQL_CLICKUP_SYNC.md` (vận hành sync), `docs/GO_LIVE_CHECKLIST.md`,
> `docs/FEATURE_CATALOG.md` (bảng đầy đủ tính năng theo từng bot), `docs/FAQ.md`, `docs/RULES.md`
> (19 mục, cập nhật liên tục — đọc TRƯỚC bước 1 ở trên, không phải đọc lướt qua).
>
> **⚠️ Rủi ro đã xảy ra thật**: 2 phiên chat khác nhau từng sửa CÙNG 1 workflow song song mà không
> biết về nhau, gây lệch dữ liệu (xem CHANGELOG 09/09/2026). Nếu thấy `nodeCount`/`connections` khác
> con số bạn nhớ — ĐỪNG cho là mình nhớ nhầm, hãy đọc lại file này (bản mới nhất trên GitHub, không
> tin bộ nhớ hội thoại) trước khi sửa tiếp.

## ✅ SỬA XONG (10/09/2026, phiên tiếp 19) — Bug thật: nút ngày dính nhầm tin không liên quan (Admin)

User báo 2 việc: "admin /lichsu không có link" + "nhầm lẫn /error_log_now khi bấm nút ngày". Tra
execution log: **link `/lichsu` thật ra VẪN CÓ** (xác nhận `text_link` entity đúng URL trong tin tóm
tắt) — user nhiều khả năng nhìn nhầm sang tin "danh sách nhóm" hoặc tin `/error_log_now` (các tin đó
đúng là không có link vì không phải nội dung tóm tắt).

**Bug thật tìm được**: node `Lichsu: Send` (Admin System) dùng CHUNG cho 5 nguồn khác nhau (group
list, summary text, `/error_logs`, `/error_log_now`, `/timkiem`) nhưng gắn CỨNG bộ nút "1/3/5/7 ngày
+ Hủy" cho MỌI tin gửi qua nó — kể cả tin hoàn toàn không liên quan. Bấm nút ngày dính trên tin
`/error_log_now` vẫn kích hoạt route `lichsu_day` → đúng hiện tượng "nhầm lẫn" user báo.

**Đã sửa**: tách `Lichsu: Send` (bỏ nút, dùng cho Errors×2 + Timkiem) và node mới `Lichsu: Send With
Day Picker` (giữ nút, chỉ dùng cho Group List/Summary Text) — đúng pattern Rule #21. Publish, verify
qua `get_workflow_details` xác nhận đúng 5 nguồn phân đúng 2 nhánh.

**Việc cần user làm**: test lại `/lichsu` (bấm nút ngày) và `/error_log_now` — xác nhận tin
error_log_now KHÔNG còn nút ngày đính kèm, và tin tóm tắt `/lichsu` vẫn có link + vẫn có nút chọn
lại ngày khác.

## ✅ SỬA XONG (10/09/2026, phiên tiếp 18) — Sửa logic `/timkiem` + đồng bộ help text đầy đủ

User báo `/timkiem việt thương` không ra kết quả (do gõ sai cú pháp cũ, xem execution `1812` — chạy
bằng code CŨ vì user test đúng lúc tôi đang sửa dở, không phải bug ở bản mới) và báo lỗi
"Circular reference detected" khi gõ `/timkiem` trống.

**Nguyên nhân thật tìm được khi tra kỹ**: nhánh "hiện danh sách nhóm" (`Show List?` true) và nhánh
"tìm kiếm" (`Search`) đang **CHẠY SONG SONG** thay vì loại trừ nhau — cả 2 đều nối trực tiếp từ
`Parse Params`, không đi qua đúng 2 nhánh của IF `Show List?`. Khi gõ `/timkiem` trống, CẢ 2 tin nhắn
đều bắn ra cùng lúc (dù nhánh Search có guard trả 0 kết quả) — không tìm được execution lỗi thật
khớp với "Circular reference" (có thể là lỗi UI n8n editor khi user tự test node, không phải lỗi bot
thật qua Telegram) nhưng hành vi song song này CHẮC CHẮN sai, đã sửa triệt để.

**Đã sửa** (cả `Telebot ClickUp Reader` lẫn `Telebot Admin System`):
1. **Đổi cú pháp `/timkiem`**: giờ `/timkiem <từ khóa>` (không cần chat_id) mặc định tìm trong TẤT CẢ
   nhóm user tham gia (bản admin: tất cả nhóm không giới hạn) — vẫn giữ `/timkiem <chat_id> <từ khóa>`
   nếu muốn giới hạn 1 nhóm. Nhận diện chat_id bằng regex `/^-?\d+$/` ở từ đầu tiên.
2. **Tách bạch 2 nhánh**: `Parse Params` → `Show List?` (IF) → true: hiện danh sách nhóm (kèm hướng
   dẫn cú pháp rõ ràng, có dòng "❌ Bạn cần nhập từ khóa" khi gọi trống) / false: mới chạy `Search`.
   KHÔNG còn chạy song song.
3. **Guard SQL** `$N <> ''` chặn trường hợp từ khóa rỗng vô tình khớp TẤT CẢ tin nhắn (rủi ro tôi tự
   phát hiện lúc build, không phải bug thật đã xảy ra nhưng đã chặn trước).
4. **Cập nhật `/help`** cả 2 bot: user — cú pháp `/timkiem` mới; admin — thêm nhãn 🔒 phân biệt rõ
   lệnh CHỈ CÓ trên bot Admin (user_list, error_logs, sync, backup, version) vs lệnh dùng chung với
   bot chính (/task, /lichsu, /timkiem, /cancel).

Đã verify wiring qua `get_workflow_details` + publish cả 4 lần update (2 workflow × 2 thay đổi).
**Việc cần user làm**: test lại `/timkiem <từ khóa>` (không cần chat_id) và `/timkiem` trống (phải chỉ
ra 1 tin nhắn hướng dẫn, không phải 2 tin/lỗi).

## ✅ SỬA XONG (10/09/2026, phiên tiếp 17) — Cập nhật `/help` thiếu 2 nút xóa file + link timkiem

Task được đẩy qua từ 1 phiên chat khác (không có quyền truy cập thư mục dự án/n8n MCP tools) nhờ xử
lý hộ. Node `Nội dung lệnh help` (`Telebot ClickUp Reader`) đã thiếu 2 nút xóa file (build phiên tiếp
14) và chưa nhắc link "Xem gốc" mới ở `/timkiem` (phiên tiếp 16). Đã cập nhật đầy đủ text, publish
(`activeVersionId: 069b1f99-3e1e-4b9b-9054-f7a65fdc030e`), verify wiring `Switch → Nội dung lệnh help
→ help` không đổi.

## ✅ BUILD XONG + CHỜ AUDIT (10/09/2026, phiên tiếp 16) — Link tin nhắn gốc trong `/lichsu`/`/timkiem` + bỏ capture media

**Yêu cầu user**: (1) lưu link tới tin nhắn gốc để `/lichsu` hiện link chủ đề bắt đầu, `/timkiem` hiện
link từng kết quả; (2) không capture ảnh/file media; (3) tối ưu token prompt AI; (4) đồng bộ CẢ bản
admin (xem mọi nhóm) lẫn bản user (chỉ xem nhóm mình tham gia).

**Quyết định thiết kế**: KHÔNG thêm cột `message_link` mới — `chat_id`+`message_id` (đã có sẵn) đủ để
tự dựng link bất cứ lúc nào cần (`https://t.me/c/<chat_id bỏ tiền tố -100>/<message_id>`), tránh lưu
thừa dữ liệu.

**4 workflow đã sửa + publish**:
1. `GW Crawl Bot - Group Capture` (`SNNrXneenXVnLHh6`): `Build Envelope (Crawl)` bỏ qua HOÀN TOÀN tin
   nhắn có photo/video/document/audio/voice/sticker/poll/contact/location/venue (kể cả có caption),
   chỉ giữ `m.text` thuần.
2. `GW Daily Chat Summary` (`ElSGQgdHPMtrzwME`): transcript gửi AI thêm `#message_id` đầu mỗi dòng.
   Prompt rút gọn (tối đa 6 dòng, trước 8), yêu cầu AI ghi `[#id]` sau mỗi chủ đề thay vì tự bịa link
   (tiết kiệm token, tránh AI viết sai URL). Node mới `Linkify Summary` (chèn giữa AI và `Upsert Daily
   Summary`): escape HTML text AI trả về rồi thay `[#id]` → `<a href="link thật">🔗</a>`, lưu thẳng
   vào `summary_text` (đã an toàn HTML sẵn, không escape 2 lần).
3. `Telebot ClickUp Reader` (`9JJRrh36H2rLwtnu`, bản USER — lọc theo nhóm user có tham gia):
   `Lichsu(U)`/`Sum(U): Build Summary Text` bỏ `escapeHtml()` (vì đã escape sẵn ở bước 2). `Timkiem(U):
   Search` thêm `message_id` vào SELECT, `Build Results` in kèm link "🔗 Xem gốc" mỗi kết quả.
4. `Telebot Admin System` (`eWtu7Qs85Hes0HuP`, bản ADMIN — KHÔNG lọc, xem mọi nhóm): y hệt thay đổi
   #3 cho `Lichsu:`/`Timkiem:` tương ứng.

**3 lỗi kết nối tự phát hiện + tự sửa trong lúc build** (đúng bài học Rule #16 — `removeNode`+
`addNode` xóa hết connection cũ, dễ quên nối lại 1 chiều): `Timkiem(U): Build Results` mất input do
`removeNode` lần 2 xóa mất connection vừa thêm cùng batch; `Sum(U): Build Summary Text` và
`Timkiem: Build Results` (bản admin) mất hẳn output — phát hiện qua `get_workflow_details` đọc lại
thấy `connections` rỗng, suy luận đúng node dùng chung (`Lichsu(U): Send`/`Lichsu: Send` — cùng shape
`{chatId,text,parse_mode}`, giống pattern `Timkiem(U): Send List` đã dùng chung cho 2 nhánh) và nối
lại, verify lại lần nữa trước khi publish.

**Đã xác nhận THẬT**: chạy `execute_workflow` thật `GW Daily Chat Summary` — AI trích `[#id]` đúng,
`Linkify Summary` render ra link thật dạng `<a href="https://t.me/c/2768213220/50082">🔗</a>`, ghi
DB thành công.

**✅ Audit PASS (10/09/2026)** — subagent độc lập đọc lại JSON thật cả 4 workflow, xác nhận PASS toàn
bộ, RIÊNG tìm ra **1 bug thật**: node `Linkify Summary` viết code kiểu xử lý từng item nhưng THIẾU
`mode: "runOnceForEachItem"` — chạy đúng khi chỉ 1 nhóm/ngày (đúng lúc tôi test lần đầu, nên không lộ
ra), nhưng SẼ lỗi/lẫn dữ liệu giữa các nhóm khi có ≥2 nhóm cùng ngày (do Code node mặc định "Run Once
for All Items", `$json`/`.item` không còn đúng nghĩa "item hiện tại"). **Đã sửa ngay**: thêm
`mode: "runOnceForEachItem"`, đổi `.item` → `.itemMatching($itemIndex)` để đảm bảo đúng cặp item qua
ranh giới node LangChain. **Đã verify lại thật với đúng 3 nhóm cùng lúc** (execution `1807`) — xác
nhận mỗi nhóm giờ lấy đúng `chat_id` của chính nó, không còn lẫn lộn. 3 dòng ghi thành công vào DB.

**Việc cần user làm**: thử `/lichsu` và `/timkiem <chat_id> <từ khóa>` qua Telegram thật (cả bot
chính lẫn bot admin nếu có quyền) để xác nhận link bấm vào nhảy đúng tới tin nhắn.

**Phụ**: đã tạo doc ClickUp "📖 Hướng dẫn dùng Bot Telegram"
(https://app.clickup.com/9018351620/docs/8crj804-4598) liệt kê đầy đủ lệnh cho user tra cứu. Phát
hiện `/help` text trong bot (node `Nội dung lệnh help`) CHƯA nhắc 2 nút xóa file (build ở phiên tiếp
14) — đã tạo task nền riêng để sửa, không lẫn vào phiên này.

**Roadmap mới user đề xuất (CHƯA BUILD, chỉ ghi lại)**: (a) tính năng `@@<nhóm>`/`@@all` mention
thành viên trong ClickUp bot; (b) `/tao_group` (admin tạo nhóm mention) + `/user_list` mở rộng thêm
chức năng thêm/xóa user khỏi nhóm mention qua callback, kèm nút Hủy/Dừng; (c) AI đọc tin nhắn user gửi
(vd ảnh visa, vé máy bay) để tự động update status/custom field tương ứng trong ClickUp. Cần thiết kế
kỹ trước khi build — độ phức tạp cao hơn hẳn các tính năng trước.

## ✅ SỬA XONG + XÁC NHẬN THẬT (10/09/2026, phiên tiếp 15) — Fix `GW Daily Chat Summary` không bao giờ chạy ra kết quả

User yêu cầu kiểm tra xem `GW Crawl Bot - Group Capture` đã capture được dữ liệu thật chưa, rồi tiếp
tục phát triển `GW Daily Chat Summary`. Kiểm tra execution thật xác nhận **Crawl Bot ĐANG hoạt động
đúng** (tin nhắn thật đã ghi vào `gateway.group_chat_log`) — nhưng `GW Daily Chat Summary` (chạy 1
lần/ngày, tóm tắt AI cho `/lichsu`/`/sum`) từ lúc build (09/09) tới giờ **CHƯA BAO GIỜ ra kết quả**,
dù có dữ liệu thật.

**Bug 1 — lệch múi giờ (root cause chính)**: node `Query Groups Aggregated` so `ts::date = (now() -
interval '1 day')::date` — nhưng lịch chạy job đặt "1h sáng" theo giờ Việt Nam (Asia/Ho_Chi_Minh,
UTC+7), trong khi `now()` trên Postgres server trả về theo UTC. Job chạy lúc 01:00 giờ VN = 18:00 UTC
NGÀY HÔM TRƯỚC — nên `now() - 1 ngày` (tính theo UTC) luôn lệch mất 1 ngày so với ý định thật, làm
điều kiện lọc không bao giờ khớp dữ liệu thật (đã tự tay tính tay + verify bằng execution `1534`:
0 nhóm dù có tin nhắn thật từ execution `1398` cùng ngày). **Đã sửa**: quy đổi cả `ts` lẫn `now()` về
`Asia/Ho_Chi_Minh` trước khi lấy `::date`, áp dụng cho cả node `Query Groups Aggregated` (điều kiện
lọc) lẫn `Upsert Daily Summary` (giá trị `summary_date` ghi vào DB) — đảm bảo lọc và ghi cùng 1 mốc
ngày nhất quán.

**Bug 2 — `queryBatching` mặc định không an toàn cho nhiều item (phát hiện khi chạy test thật)**:
chạy thật lần 1 (execution `1748`, 3 nhóm có dữ liệu) → n8n tự cảnh báo `"Inserts were batched for
performance... đổi 'Query batching' sang 'Independent'"` ở node `Upsert Daily Summary` — mặc định
`queryBatching: 'single'` gộp nhiều item thành 1 lần gọi query, có rủi ro sai lệch tham số giữa các
item khi query có `$1..$N` tham chiếu riêng từng item (đúng loại lỗi âm thầm dự án đã dính nhiều
lần). **Đã sửa**: set `queryBatching: 'independently'` — mỗi item chạy 1 query riêng, đảm bảo đúng
cặp tham số. Verify bằng execution `1749`: `pairedItem` giờ tách riêng từng item (trước là gộp
chung), không còn cảnh báo.

**Đã xác nhận THẬT (không phải giả lập)**: chạy `execute_workflow` thật 2 lần (`1748`, `1749`) —
tìm đúng 3 nhóm có dữ liệu ngày hôm trước ("Elite Xử lý hồ sơ", "01 (K CHAT) HỢP ĐỒNG/TÀI LIỆU/GIẤY
TỜ", "Đơn hàng 86"), DeepSeek tóm tắt đúng nội dung, ghi thành công vào `gateway.daily_chat_summary`.
Tính năng `GW Daily Chat Summary` giờ **hoạt động thật, không chỉ "build xong chưa test"** như trước.

**Việc cần user làm tiếp**: thử lệnh `/lichsu` hoặc `/sum` trong Telegram để xem tóm tắt AI có hiển
thị đúng nội dung 3 nhóm trên không (chưa test đường đọc lại từ phía user-facing command, chỉ mới
xác nhận phần ghi dữ liệu ở trên).

**Dọn dẹp phụ**: đổi tên file `bot-gateway/sql/08_upload_notify_queue_delete.sql` →
`09_upload_notify_queue_delete.sql` vì trùng số với `08_gateway_group_chat_capture.sql` đã có sẵn từ
trước (lỗi đặt tên của phiên trước, không phải lỗi chức năng).

## ✅ BUILD XONG + AUDIT PASS (09/09/2026, phiên tiếp 14) — Xóa file OneDrive vừa upload + thu hồi tin forward

Build xong cả 4 stage, publish, audit độc lập PASS toàn bộ. **CHỈ CÒN CHỜ user**: (1) dán token Zalo
thật + (2) test qua Telegram thật (xem "Việc cần user làm" ở cuối mục này) — chưa test thật nên
chưa đóng hẳn mục này, nhưng về mặt kỹ thuật đã hoàn tất, không cần build/sửa gì thêm trừ khi test
thật phát hiện vấn đề (khả năng cao nhất nằm ở rủi ro #1 dưới — shape response Telegram).

**Yêu cầu user (nguyên văn ý)**: 2 nút mới —
1. Trên tin nhắn kết quả upload (`Send Upload Result`, chat riêng, TRƯỚC khi forward): nút
   "🗑️ Xóa file vừa upload" → xóa file OneDrive.
2. Trên tin nhắn "bản lưu riêng" (`Send Forward Copy To User`, SAU khi đã forward): nút
   "🗑️ Xóa & thu hồi" → xóa file OneDrive + xóa tin đã forward trong nhóm Telegram + (Zalo không có
   API xóa/thu hồi theo tài liệu chính thức → gửi tin mới báo "đã xóa" vào đúng nhóm Zalo thay vì
   thử gọi API không có thật).

**Thiết kế** (đã trình bày cho user, user đã OK "bắt đầu build cho tôi nhé"):
- Callback mới: `od_del_<queueId>` (xóa trước forward), `od_delfwd_<queueId>` (xóa sau forward) —
  CỐ Ý bắt đầu bằng `od_` để tự khớp whitelist Gateway có sẵn (`resolveBotKeyForCallback` đã check
  `startsWith('od_')`) → KHÔNG cần sửa `GW Gateway - Telegram` (`xmEKeIUnzxm2F7dF`).
- 6 cột mới trên `clickup.upload_notify_queue`: `drive_id`, `item_id` (lưu lúc upload, vì lúc xóa là
  1 execution KHÁC hẳn, không còn truy cập node cũ), `fwd_chat_id`, `fwd_message_id` (lưu lúc forward
  thành công, để sau xóa đúng tin trong nhóm), `zalo_chat_id_used` (để biết gửi tin báo xóa vào đúng
  nhóm Zalo nào), `deleted_at` (chặn bấm xóa 2 lần + chặn forward 1 file đã xóa).
- Guard quan trọng: `Build Forward Message` sẽ được sửa để từ chối forward nếu `deleted_at` đã có
  giá trị (báo "File đã bị xóa, không thể forward").
- Xóa OneDrive/Telegram/Zalo đều dùng `onError: continueRegularOutput` — thiết kế "best-effort":
  1 bước lỗi (vd file đã bị xóa tay trước đó trên OneDrive) không chặn các bước dọn dẹp còn lại.

### Stage đã xong (KHÔNG làm lại):
- ✅ **Stage 1/4** (publish `activeVersionId: c51dd030-5884-4593-bc88-1f81e78cce1d`): ALTER 6 cột
  mới vào `clickup.upload_notify_queue` (node `Ensure Notify Queue Columns`, đã giữ nguyên
  `alwaysOutputData`/`onError` cũ). `Queue Upload Notify` INSERT thêm `drive_id`/`item_id` lấy từ
  `$('Upload To OneDrive').item.json.parentReference.driveId` / `.id`. `Send Upload Result` thêm
  hàng nút thứ 5 "🗑️ Xóa file vừa upload" → `od_del_{{ $json.id }}`. **Callback này CHƯA có handler
  — bấm vào lúc này sẽ rơi vào "Lệnh không hợp lệ" (bình thường, do stage 3-4 chưa build) — KHÔNG
  phải bug, đừng test nút này cho tới khi thấy dòng "Stage 4/4 XONG" ở dưới.**

### Stage CHƯA làm (làm tiếp theo đúng thứ tự):
- ✅ **Stage 2/4 XONG** (publish `activeVersionId: bd48c9cd-6dfb-44a0-8b4c-534c2b0e4ddc`):
  `Build Forward Message` trả thêm `queueId` + từ chối forward nếu `deleted_at` đã có. Chèn
  `OD Fwd: Extract Send Result` (Code, đọc `message_id`/`chat.id` từ response `Send Forward Message`,
  có fallback đọc `result.message_id` phòng n8n trả khác shape — **CHƯA xác nhận được shape thật**
  vì `test_workflow` pin node Telegram, phải chờ user test thật, xem log/execution nếu
  `fwd_chat_id`/`fwd_message_id` bị NULL sau khi forward) → `OD Fwd: Save Message Info` (Postgres
  UPDATE `fwd_chat_id`/`fwd_message_id`/`zalo_chat_id_used`, có `alwaysOutputData`+`onError`) — chèn
  GIỮA `Send Forward Message` và `Confirm Forward Sent`. `Send Forward Copy To User` đã có nút
  "🗑️ Xóa & thu hồi" → `od_delfwd_{{ $json.queueId }}` (`replyMarkup` TĨNH, đúng Rule #21). Có 1 lỗi
  nhỏ tự phát hiện qua `validationWarnings` (`removeNode` xoá mất connection ĐẦU VÀO của `Build
  Forward Message`, chỉ nối lại được đầu ra ở lần gọi đầu) — đã fix ngay, verify lại connections đầy
  đủ trước khi publish. **Callback `od_delfwd_` vẫn CHƯA có handler — bình thường tới hết Stage 3.**
- ✅ **Stage 3/4 XONG** (publish `activeVersionId: 8f861731-ecc9-4220-9dfd-61c92e15c155`):
  `Phân tích lệnh` parse thêm `od_del_(\d+)` → route `od_del`, `od_delfwd_(\d+)` → route `od_delfwd`
  (check TRƯỚC `unknown_command`, không đụng logic cũ). `Switch` (router chính) thêm 2 rule mới
  `od_del`/`od_delfwd` — đúng như dự đoán, thêm 2 rule đã ĐẨY index fallback (`extra`) từ 17 lên 19,
  đã nối lại đủ 17 output gốc (0-16, giữ nguyên target) + fallback ở vị trí MỚI (19 → `Reply Unknown
  Command`). Output 17 (`od_del`)/18 (`od_delfwd`) ĐANG ĐỂ TRỐNG có chủ đích — sẽ nối vào node xử lý
  thật ở Stage 4. **Lưu ý cho subagent audit / phiên sau**: response `update_workflow` báo 1 warning
  `SWITCH_FALLBACK_OUTPUT_DISABLED` dù `options.fallbackOutput` đã đúng là `"extra"` — đã tự
  `get_workflow_details` đọc lại JSON THẬT ngay sau đó và xác nhận cấu hình + toàn bộ 20 connection
  (index 0-16 đúng target cũ, 17/18 null, 19→Reply Unknown Command) đều ĐÚNG — kết luận đây là
  validator false-positive tại thời điểm response (có thể do check chạy giữa lúc áp connection),
  KHÔNG phải lỗi thật. Vẫn nên audit lại 1 lần nữa cho chắc khi Stage 4 xong.
- ✅ **Stage 4/4 XONG** (publish `activeVersionId: 183a916e-3b81-4668-953d-c2f4a5d0902e`, TOÀN BỘ
  4 stage đã publish): Build xong cả 2 chuỗi `od_del` (7 node) và `od_delfwd` (10 node) đúng thiết kế
  đã mô tả, nối đúng vào Switch output 17/18. Credential Graph API + Postgres đã verify đúng qua
  `get_workflow_details` (lần đầu addNode HTTP DELETE bị thiếu `credentials`, đã tự phát hiện qua
  `note` trong response và fix ngay bằng removeNode+addNode kèm credential). URL Zalo dùng đúng
  placeholder `PASTE_YOUR_ZALO_BOT_TOKEN_HERE` (Rule #17) — **user cần tự vào n8n UI node
  `OD Delfwd: Announce Zalo Deleted` dán token Zalo thật vào (giống token đang dùng ở node
  `Send Zalo Notify` cùng workflow) thì tính năng báo-xóa-Zalo mới hoạt động**, nếu không thì
  nhánh Zalo sẽ lỗi (nhưng nhờ `onError: continueRegularOutput` nên KHÔNG chặn phần xóa
  OneDrive/Telegram, chỉ riêng phần báo Zalo không gửi được).
  **✅ Audit PASS (09/09/2026)**: subagent độc lập đọc lại toàn bộ JSON thật của cả 2 workflow
  (`9JJRrh36H2rLwtnu` + `xmEKeIUnzxm2F7dF`), xác nhận PASS cả 8 mục build + 4 mục thiết kế (schema,
  2 nút, guard `deleted_at`, Gateway whitelist không cần sửa, Switch fallback KHÔNG bị lỗi thật —
  `SWITCH_FALLBACK_OUTPUT_DISABLED` xác nhận đúng là false-positive, cả 2 chuỗi `od_del`/`od_delfwd`,
  cách xử lý Zalo (gửi tin mới, không gọi API xóa không có thật), `onError`/`alwaysOutputData` đúng
  vị trí, không có `replyMarkup` động, `final_name` được escape HTML đúng chỗ). Không tìm thấy bug
  thật nào. Góp ý style nhỏ đã được sửa (10/09/2026, publish `activeVersionId:
  8fa4f989-af67-488c-81af-7d75ba27cd30`): `OD Del: Reply Error`/`OD Delfwd: Reply Error` đổi từ
  `$json.chatId` trần sang tham chiếu tường minh `$('...Build Result').item.json.chatId` cho nhất
  quán với các node Reply Success — chỉ là polish, không đổi hành vi (bản cũ vẫn đúng vì IF không
  biến đổi data).
  **Kiểm tra execution thật (10/09/2026)**: đã xem log execution hôm nay — user mới upload thử 2
  file (`Genehmigung der HWK.pdf`), CHƯA bấm nút forward hay nút xóa nào — tính năng xóa/thu hồi
  VẪN CHƯA được test thật.
  **2 rủi ro CHƯA kiểm chứng được bằng test giả lập (RULES.md #21 mở rộng)**, chỉ xác nhận được qua
  Telegram thật:
  1. `OD Fwd: Extract Send Result` giả định response của node Telegram `Send Forward Message` có
     `message_id`/`chat.id` ở top-level (có fallback đọc `.result.message_id` phòng khác shape) — nếu
     forward xong mà bấm "Xóa & thu hồi" báo lỗi/không xóa được tin nhóm, khả năng cao do giả định
     sai shape này, cần sửa lại `OD Fwd: Extract Send Result`.
  2. Chưa test thật flow xóa (cả trước và sau forward) qua Telegram — `test_workflow` không gọi API
     thật (Postgres/Telegram/HTTP đều bị pin) nên không xác nhận được OneDrive/Telegram/Zalo có thực
     sự bị xóa/gửi đúng hay không, chỉ xác nhận logic routing.
  **Việc cần user làm để hoàn tất**: (1) dán token Zalo thật vào node `OD Delfwd: Announce Zalo
  Deleted`, (2) test thật: upload 1 file thử → bấm "🗑️ Xóa file vừa upload" (chưa forward) → xác nhận
  file biến mất khỏi OneDrive; upload 1 file khác → forward vào 1 nhóm → bấm "🗑️ Xóa & thu hồi" ở tin
  nhắn lưu riêng → xác nhận file OneDrive bị xóa + tin nhóm Telegram biến mất + (nếu nhóm đó có mirror
  Zalo) tin báo xóa xuất hiện trong nhóm Zalo.
  **TODO còn lại (không khẩn cấp)**: thêm file SQL lịch sử `bot-gateway/sql/08_upload_notify_queue_delete.sql`
  ghi lại 6 cột mới, giống style `04_gateway_notify_targets.sql`.

## ✅ BUILD MỚI (09/09/2026, phiên tiếp 13) — Gửi bản lưu riêng vào chat cá nhân khi forward tin nhắn

User xác nhận fix "❓ Trợ giúp" (phiên tiếp 12) đã hoạt động ("ok đã hoạt động rồi"). Yêu cầu mới:
mỗi khi bot forward tin nhắn thông báo upload OneDrive vào 1 nhóm Telegram (qua nút Kammer/BAV,
Hóa đơn, Giấy tờ khác), cũng gửi CÙNG NỘI DUNG đó vào chat riêng (private) của chính user đã upload,
để họ lưu lại làm hồ sơ cá nhân.

**Đã build** trong `Telebot ClickUp Reader` (`9JJRrh36H2rLwtnu`):
- Node mới `Send Forward Copy To User` (Telegram, id `send-forward-copy-to-user`), `chatId: ={{
  $json.adminChatId }}`, `text` = tiền tố "📋 (Bản lưu riêng cho bạn)" + nguyên văn `{{ $json.text }}`
  (đã được `Build Forward Message` escape HTML sẵn, không escape lại 2 lần), dùng credential
  `Elite Clickupbot` (giống hệt node `Send Forward Message` — không bị auto-assign nhầm bot).
- Nối thêm 1 connection từ output TRUE (index 0) của node IF `Forward OK?` sang node mới — chạy
  SONG SONG với 2 connection có sẵn (`Send Forward Message`, `Has Zalo Target?`), không đụng/xoá
  connection nào cũ.
- Không cần sửa Gateway (`xmEKeIUnzxm2F7dF`): tính năng này không tạo/đổi callback_data nào, chỉ là
  1 side-effect tự động của nhánh IF đã tồn tại sẵn — nên KHÔNG dính bug loại "quên cập nhật
  whitelist" như phiên tiếp 12.
- Sau audit độc lập (subagent, PASS toàn bộ 6 mục kiểm tra + 1 gợi ý hardening), đã thêm
  `onError: continueRegularOutput` cho node mới — nếu gửi tin nhắn riêng lỗi (VD: user đã chặn bot)
  thì không ảnh hưởng tới việc forward vào nhóm/Zalo (đã publish, `activeVersionId`
  `48441cac-286f-41f9-ba4f-7c40d5b02ff0`).

**Trạng thái**: ĐÃ BUILD + ĐÃ AUDIT (PASS) + ĐÃ PUBLISH, **CHƯA TEST THẬT** qua Telegram — cần user
thử upload + forward 1 lần để xác nhận tin nhắn riêng xuất hiện đúng trong chat cá nhân.

**Đề xuất chưa build (chờ user quyết định)**: tính năng "xoá file OneDrive vừa upload" (phòng trường
hợp chọn nhầm file) — đã tư vấn hướng triển khai (lưu `drive_id`+`item_id` vào
`clickup.upload_notify_queue`, UI xác nhận 2 bước kiểu "Xoá hoàn toàn user", gọi Graph API
`DELETE /drives/{driveId}/items/{itemId}`, nhớ thêm prefix callback mới VD `oddel_` vào whitelist
Gateway theo đúng bài học phiên tiếp 12), độ khó ước tính Thấp-Trung bình. Chưa build, chờ user chốt.

## 🔴 SỬA (09/09/2026, phiên tiếp 12) — Bug THẬT SỰ ở Gateway: quên cập nhật whitelist callback

User test qua Telegram thật, xác nhận: bấm "❓ Trợ giúp" → **stuck, không có phản hồi gì**. Tra
execution thật (Gateway `1528`/`1529`) lộ ra: `GW-03 Router` tính `route: "help_bot"` thay vì
`"telebot_main"` — callback rơi vào `→ Sub: Help Bot`, một sub-workflow **ĐANG BỊ DISABLE** (chưa có
Workflow ID thật), nên im lặng không phản hồi gì — không phải lỗi ClickUp Reader (workflow đó thậm
chí KHÔNG CÓ execution mới nào sau khi user bấm, xác nhận callback chưa từng tới được đó).

**Nguyên nhân**: hàm `resolveBotKeyForCallback` trong `GW-03 Router` (`xmEKeIUnzxm2F7dF`) check
`data === 'odhelp'` (SO KHỚP TUYỆT ĐỐI) — nhưng nút đã đổi callback_data thành `odhelp_<queueId>`
(mang theo id) ở "phiên tiếp 10". Chuỗi mới không khớp `=== 'odhelp'` VÀ cũng không khớp
`startsWith('od_')` (ký tự thứ 3 là 'h' không phải '_') → rơi xuống `DEFAULT_BOT` = `help_bot`.
**Đây là bug ĐÚNG LOẠI mà chính comment trong code đã tự cảnh báo** ("đã gây bug im lặng 1 lần
trước đó" — về `odfwd_`/`odhelp` không khớp `od_`) — tôi lặp lại loại lỗi này lần 2 vì đổi FORMAT
của 1 callback_data đã có (từ tĩnh sang có tham số) mà quên rà lại whitelist Gateway, dù chính tay
tôi đã thêm dòng comment cảnh báo này trước đó trong cùng phiên.

**Đã sửa**: đổi `data === 'odhelp'` → `data.startsWith('odhelp')` (khớp cả 2 dạng cũ/mới). Verify +
publish. **Việc cần user làm**: test lại nút "❓ Trợ giúp" 1 lần nữa qua Telegram thật.

**Bài học bổ sung cho RULES.md #1** (đã làm ngay dưới đây): quy tắc "đổi COMMAND_MAP khi thêm lệnh
mới" cần mở rộng thành "đổi/thêm CALLBACK_DATA FORMAT (không chỉ lệnh gõ tay) cũng phải rà lại
whitelist callback ở Gateway `GW-03 Router`" — đặc biệt khi ĐỔI FORMAT của 1 callback_data ĐÃ CÓ
SẴN (không phải thêm mới), vì dễ quên hơn thêm mới (thêm mới thì phải nghĩ tới whitelist, đổi format
1 cái cũ thì dễ quên vì "tưởng đã có trong whitelist rồi").

## ✅ QUY TRÌNH MỚI ĐÃ CHỨNG MINH HOẠT ĐỘNG (09/09/2026, phiên tiếp 11) — Subagent audit bắt đúng 1 bug thật mà tự test bỏ sót

Lần ĐẦU TIÊN áp dụng bước 9 của quy trình mới (spawn subagent độc lập audit sau khi publish) — và nó
bắt được đúng 1 bug thật trong chính fix "Trợ giúp" vừa làm ở "phiên tiếp 10":

**Bug bị bắt**: node `Send Help Text` dùng `replyMarkup`/`inlineKeyboard` bằng EXPRESSION ĐỘNG
(`={{ $json.hasKeyboard ? 'inlineKeyboard' : 'none' }}`) — ĐÚNG bẫy đã từng gặp và tưởng đã hiểu rõ
(RULES.md #14), nhưng lần này lặp lại vì tôi lầm tưởng node `Send OD Menu` (nhìn thấy dùng pattern
tương tự) là "đã proven hoạt động" — thực ra pattern THẬT SỰ đã fix và đang chạy ổn định là
`Has OD Menu Keyboard?` (IF) → 2 nhánh TĨNH (`Send OD Menu (Keyboard)` có `replyMarkup` là chuỗi CỐ
ĐỊNH `"inlineKeyboard"`, KHÔNG phải expression) — tôi đã đọc nhầm/không kiểm tra kỹ node liên quan
trước khi tái sử dụng "pattern tưởng đã đúng".

**⚠️ Bài học quan trọng nhất**: `test_workflow` (bước 7 trong quy trình) **KHÔNG PHÁT HIỆN ĐƯỢC lỗi
này** dù đã chạy và báo "success" — vì node Telegram bị "pin" (giả lập) nên không thực sự gọi API
Telegram để biết reply_markup có render đúng hay không; `test_workflow` chỉ xác nhận DỮ LIỆU đưa vào
node đúng, không xác nhận Telegram có HIỂN THỊ đúng nút hay không. Chỉ có (a) đọc kỹ cấu trúc node so
với 1 pattern ĐÃ CHỨNG MINH hoạt động thật trong CHÍNH workflow đó, hoặc (b) subagent audit đọc lại
JSON thật đối chiếu FAQ.md, mới bắt được loại lỗi này.

**Đã sửa đúng theo pattern đã proven** (`Has OD Menu Keyboard?`/`Send OD Menu (Keyboard)`): thêm IF
`Has OD Help Keyboard?` → 2 nhánh tĩnh (`Send Help Text (Keyboard)` với `replyMarkup: "inlineKeyboard"`
cố định + `inlineKeyboard` là object tĩnh, các nút Kammer/BAV=1/Hóa đơn=2/Giấy tờ khác=3 hardcode y
hệt `Send Upload Result`) / (`Send Help Text` không có `replyMarkup` cho trường hợp không có
`queueId`). Verify + test lại bằng `test_workflow` (giờ true branch được gọi đúng, dữ liệu `queueId`
đi đúng) rồi mới publish. Cũng phát hiện thêm lỗi phụ: `addNode` tự gán NHẦM credential
(`@csfsintbot` thay vì `Elite Clickupbot`) cho node Telegram mới — đã sửa bằng `setNodeCredential`.

**Cập nhật RULES.md/FAQ.md cần làm tiếp** (chưa làm ở dòng này, cần làm ngay sau): ghi rõ giới hạn
của `test_workflow` — không phát hiện được lỗi render UI (inline keyboard) vì Telegram node bị pin,
chỉ xác nhận đúng LOGIC/DỮ LIỆU, không xác nhận đúng HIỂN THỊ. Trước khi dùng pattern
`replyMarkup`/`inlineKeyboard` động, LUÔN tìm 1 node THẬT trong CHÍNH workflow đã publish + có
execution thật gần đây dùng ĐÚNG pattern đó và xem `reply_to_message` phía callback tiếp theo có
`reply_markup.inline_keyboard` thật hay không — không suy luận từ tên node giống nhau.

## ✅ SỬA (09/09/2026, phiên tiếp 10) — Nút "❓ Trợ giúp" giờ có nút forward, đã test trước khi publish

User báo: bấm "❓ Trợ giúp" trên tin upload OneDrive → hiện hướng dẫn nhưng KHÔNG có nút nào để bấm
tiếp, phải quay lại tin gốc mới forward được.

**Nguyên nhân**: nút "❓ Trợ giúp" có `callback_data` TĨNH `"odhelp"`, không mang theo `queueId` —
nên khi bấm vào, bot không biết đây là hướng dẫn cho lượt upload nào, không thể tự dựng lại đúng 3
nút `odfwd_<queueId>_<targetId>`.

**Đã sửa** (`Telebot ClickUp Reader`, `9JJRrh36H2rLwtnu`): đổi nút thành `odhelp_{{ $json.id }}`
(mang theo queueId, giống pattern 3 nút forward) → `Phân tích lệnh` parse thêm regex `odhelp_(\d+)`
→ `OD Help: Query Targets` thêm cột `id` vào SELECT → `Build Help Text` dựng lại đúng 3 nút forward
+ nút ❌ Hủy → `Send Help Text` dùng pattern `replyMarkup` động đã proven (`Send OD Menu`).

**Đã test bằng `prepare_workflow_pin_data`+`test_workflow` TRƯỚC KHI publish** (đúng quy trình mới ở
đầu file) — xác nhận `Build Help Text` dựng đúng cả text lẫn 3 nút với `queueId` giữ nguyên
(`odfwd_999_1`/`odfwd_999_2`/`odfwd_999_3`), không cần đợi user test qua Telegram thật mới biết
đúng/sai. Verify param qua `get_workflow_details` xong mới publish.

**Đã lập quy trình chính thức** (xem mục "⚙️ QUY TRÌNH BẮT BUỘC" đầu file — user yêu cầu 09/09/2026):
mọi lần build/sửa lớn từ nay LUÔN gọi n8n skill trước khi code, đọc RULES.md/FAQ.md trước khi sửa,
verify + test trước khi publish, và với thay đổi vừa/lớn — spawn 1 Agent độc lập audit lại toàn bộ
so với RULES.md/FAQ.md sau khi publish (không phải tự mình tự chấm điểm mình). Đã chạy thử ngay
trong phiên này cho đúng fix "Trợ giúp" ở trên — kết quả audit: xem CHANGELOG/lần chạy kế tiếp khi
subagent trả lời (job chạy nền, chưa có kết quả tại thời điểm ghi dòng này).

## ✅ (09/09/2026, phiên tiếp 9) — Luồng ổn định, sửa nốt "Học sinh: Không rõ" + đổi hashtag

User xác nhận luồng Upload OneDrive → forward giờ CHẠY ỔN ĐỊNH, chỉ còn tin nhắn hiện
"🎓 Học sinh: Không rõ" thay vì đúng tên.

**Nguyên nhân**: khi nối dữ liệu `student_name`/`task_url` xuyên workflow (phiên tiếp 6), tôi CHỈ sửa
bảng `pending_uploads` + `upload_notify_queue` bên `Telebot ClickUp Reader`, **quên mất bước Gateway
đọc lại `pending_uploads`** (`GW-04 Check Pending Upload` trong `xmEKeIUnzxm2F7dF`) — query đó vẫn
chỉ SELECT các cột cũ (`task_id, filename, mode, onedrive_link`), nên `pendingUpload.student_name`
luôn `undefined` khi tới bước build tin nhắn, hiển thị "Không rõ". Đã thêm `student_name, task_url`
vào SELECT đó, verify + publish.

**Đổi hashtag theo yêu cầu**: bỏ hẳn `#UploadOneDrive`, giữ `#CapNhatHoSo`, thêm hashtag theo loại
giấy tờ đã chọn — lấy từ phần chữ trước dấu `" - "` trong tên file cuối cùng, so khớp với 5 preset
(`BAV/Kammer/EZB/Schulbestätigung/Spateinstieg`, bỏ dấu để so sánh) → ra đúng `#BAV`/`#EZB`/...;
nếu là tên tùy chỉnh hoặc giữ tên gốc (không khớp preset nào) → fallback `#GIAYTOKHAC`.

**Bài học lặp lại (đã có ở "phiên tiếp 8")**: mỗi khi thêm 1 cột dữ liệu mới cần "đi nhờ" qua nhiều
workflow, phải liệt kê ĐỦ MỌI ĐIỂM đọc/ghi cột đó trước khi coi là xong — lần này bỏ sót đúng 1 điểm
đọc (Gateway) dù đã nhớ sửa đủ 2 điểm ghi (2 bảng ở ClickUp Reader). Nên cân nhắc: mỗi khi thêm cột
mới, `grep` tên cột đó xuyên suốt code TRƯỚC khi publish, không chỉ dựa vào trí nhớ danh sách các
chỗ cần sửa.

**Việc cần user làm**: test lại 1 lượt upload+forward mới, xác nhận tên học sinh hiện đúng và
hashtag đúng loại giấy tờ đã chọn.

## 🔴 (09/09/2026, phiên tiếp 8) — Lỗi THẬT SỰ khác: quên thêm cột vào `pending_uploads`

User báo tiếp tục bị "xóa tin cũ nhanh hơn hiện tin mới", đề xuất thử thêm node Wait 10s. Tra lại
execution thật (1474, 1480 — SAU khi publish fix "phiên tiếp 7") lộ ra **đây KHÔNG PHẢI race
condition/timing** — là lỗi Postgres THẬT: `column "student_name" of relation "pending_uploads"
does not exist`. Ở "phiên tiếp 6" (thêm tin nhắn forward chi tiết hơn), tôi có thêm cột
`student_name`/`task_url` vào `clickup.upload_notify_queue` (qua node `Ensure Notify Queue
Columns`) nhưng **QUÊN làm y hệt cho bảng `clickup.pending_uploads`** — trong khi cả 2 node
`Upsert Pending Upload (Pick)` và `(Custom Prompt)` đều ghi vào ĐÚNG 2 cột đó của bảng này. Kết quả:
`Delete Old Message (Reader)` xóa tin cũ THÀNH CÔNG → bước Upsert ngay sau đó LỖI THẬT (không phải
0-row) → toàn luồng dừng → không tin nhắn mới nào được gửi. Wait 10s sẽ KHÔNG sửa được lỗi này (đây
là lỗi cứng, không phải chậm).

**Đã sửa**: thêm node `Ensure Pending Upload Columns` (ALTER TABLE `pending_uploads` ADD COLUMN IF
NOT EXISTS `student_name`/`task_url`) chèn giữa `Switch` (3 output od_start/od_pick/od_custom_prompt)
→ `OD Task Lookup` — vị trí này AN TOÀN vì `OD Task Lookup` không phụ thuộc `$json` của node liền
trước (chỉ dùng `$('Phân tích lệnh').first().json.taskId`), nên chèn node DDL vào giữa không làm
mất dữ liệu task row cho các bước sau. Đã set `alwaysOutputData`/`onError` NGAY TRONG CÙNG BATCH
(đúng RULES.md #18 mới thêm) và verify bằng `get_workflow_details` trước khi publish. Đã publish.

**Bài học thêm cho RULES.md #18**: mỗi khi thêm cột mới cho 1 tính năng, phải rà lại XEM CÓ BAO
NHIÊU BẢNG cùng cần cột đó — phiên trước chỉ nhớ sửa 1/2 bảng (`upload_notify_queue`), quên bảng
kia (`pending_uploads`) dù cả 2 đều dùng chung tên cột `student_name`/`task_url`. Nên grep toàn bộ
workflow tìm tên cột mới trước khi coi là "đã xong" việc thêm cột.

## 🔴 (09/09/2026, phiên tiếp 7) — LẶP LẠI lỗi RULES.md #16 lần thứ 3, làm gãy bước cuối Upload OneDrive

User báo: sau khi làm tin nhắn forward chi tiết hơn (mục "phiên tiếp 6"), luồng Upload OneDrive bị
"xóa hết tin cũ nhưng chưa chuyển sang tin nhắn mới". Nguyên nhân: node MỚI thêm vào lúc đó
(`Ensure Notify Queue Columns`, chèn giữa `Clear Pending Upload` → `Queue Upload Notify`) được tạo
qua `addNode` **THIẾU `alwaysOutputData`/`onError`** — ĐÚNG lỗi đã ghi trong RULES.md #16 (addNode
âm thầm bỏ qua 2 field này), lần thứ 3 trong dự án dính lỗi này (2 lần trước: Gateway pending-check
gây sập toàn bộ bot 08/09; và OD Task Lookup/Resolve/Upload HTTP nodes cùng ngày). Node ALTER TABLE
không có `RETURNING` → trả về 0 dòng → không có `alwaysOutputData` → toàn bộ chuỗi sau đó (bao gồm
`Queue Upload Notify` và tin nhắn "✅ Đã upload..." kèm nút forward) **không chạy** — trong khi các
bước xóa tin nhắn cũ trước đó (điều hướng menu chọn tên) vẫn chạy bình thường → đúng triệu chứng
"xóa hết tin cũ, không thấy tin mới" user mô tả.

**Đã sửa bằng `setNodeSettings`** (không phải sửa lại `addNode`), verify lại bằng
`get_workflow_details` xác nhận `alwaysOutputData:true`/`onError:"continueRegularOutput"` đã có
thật trước khi publish. Đã publish.

**⚠️ Cần 1 quy trình CHẮC CHẮN hơn để không lặp lại lần thứ 4** — đề xuất thêm vào RULES.md #16:
BẤT KỲ lúc nào dùng `addNode` để thêm 1 node Postgres/HTTP loại "ensure"/"DDL"/gọi API ngoài (không
có `RETURNING` hoặc phụ thuộc external service có thể lỗi) VÀO GIỮA 1 chuỗi đang chạy sống — PHẢI
LUÔN kèm `setNodeSettings` (`alwaysOutputData:true` cho DDL, `onError:"continueRegularOutput"` cho
gọi API ngoài) làm operation NGAY SAU trong CÙNG 1 batch `update_workflow`, không tách làm 2 lần gọi
riêng (dễ quên lần thêm mới, đã quên tới lần thứ 3). Xem RULES.md #16 đã cập nhật.

## 🟡 (09/09/2026, phiên tiếp 6) — Tin nhắn forward chi tiết hơn (người upload, học sinh, giờ, link)

User xác nhận đã tự test full luồng Upload OneDrive → forward, thành công cả Telegram lẫn Zalo (mục
"phiên tiếp 5" bên dưới). Sau đó yêu cầu nâng cấp nội dung tin nhắn forward — đã build xong, CHƯA
test thật (cần user thử lại 1 lượt upload+forward mới để thấy format mới, vì phiên trước đã test
xong với format cũ).

**Format mới** (giống nhau cho Telegram + Zalo, chỉ khác cách hiển thị tên học sinh):
```
📢 Thông báo cập nhật hồ sơ

👤 Người upload: <tên hiển thị Telegram của người thao tác>
📁 Tên file: <tên file đã đặt lúc upload>
🎓 Học sinh: <tên học sinh — HYPERLINK>
🕒 Thời gian: <giờ upload, định dạng vi-VN, timezone Asia/Ho_Chi_Minh>
🔗 Link: <link OneDrive>

#UploadOneDrive #CapNhatHoSo
```
- **Hyperlink tên học sinh KHÁC NHAU theo nền tảng** (đúng yêu cầu user): bản Telegram trỏ tới
  deep-link `chitiet_<taskId>` (mở lại chi tiết task ngay trong bot); bản Zalo trỏ tới **link
  ClickUp** (`task.url`) — vì hyperlink chỉ áp dụng cho HTML gửi qua node Telegram, Zalo dùng link
  khác theo đúng yêu cầu "nếu Zalo hỗ trợ hyperlink thì cho link ClickUp".
- ⚠️ **CHƯA XÁC NHẬN Zalo có thực sự RENDER `<a href>` thành link bấm được hay không** — tài liệu
  Zalo chỉ nói `parse_mode: html` được hỗ trợ, không có ví dụ cụ thể về thẻ `<a>`. Cần user tự nhìn
  tin nhắn Zalo thật sau khi test để xác nhận: nếu tên học sinh hiện ra ĐÃ GẠCH CHÂN/BẤM ĐƯỢC → OK;
  nếu hiện nguyên văn thẻ HTML (`<a href="...">...</a>`) hoặc bot báo lỗi gửi → cần đổi sang gửi
  plain text kèm link riêng 1 dòng thay vì hyperlink cho bản Zalo.
- **Dữ liệu mới phải "đi nhờ" xuyên suốt** từ lúc mở chi tiết task tới lúc forward (đúng RULES.md
  #11): thêm cột `student_name`, `task_url` vào `clickup.pending_uploads`; thêm cột `uploader_name`,
  `student_name`, `task_url` vào `clickup.upload_notify_queue` (tự tạo qua node mới `Ensure Notify
  Queue Columns`, chèn giữa `Clear Pending Upload` → `Queue Upload Notify`). `uploader_name` lấy từ
  `display_name` trong envelope Gateway (đã có sẵn, giờ mới expose ra trong node `Phân tích lệnh`).
- Đã verify TOÀN BỘ node param bằng `get_workflow_details` trước khi publish (đúng RULES.md #16),
  không lặp lại lỗi "báo thành công nhưng không áp dụng" của phiên trước.
- **Việc cần user làm**: test lại 1 lượt Upload OneDrive → forward mới, xác nhận: (1) tin nhắn có
  đủ 5 trường đúng dữ liệu thật (tên mình, tên học sinh đúng task, giờ đúng, link đúng); (2) bấm thử
  tên học sinh trên Telegram có mở lại đúng chi tiết task không; (3) xem tin Zalo có hyperlink bấm
  được không hay chỉ là chữ thường/lỗi thẻ HTML.

## ✅ (09/09/2026, phiên tiếp 5) — Mirror OneDrive forward sang Zalo: TEST THẬT OK, hoạt động

Đã test thật qua `execute_workflow` (chạy thật, không phải giả lập) trên `Zalo API - Webhook Test`:
1. **Webhook production đã đăng ký thành công** — `Call Zalo setWebhook` trả về
   `{"ok":true,"result":{"url":"https://n8n.toididuhoc.net/webhook/zalo-test","verification":{"ok":true,"outcome":"webhook.ok"}}}`.
   Trước đó Zalo đang trỏ vào URL **test** (chỉ sống khi mở editor bấm Listen) — user tự phát hiện
   và hỏi, đã xác nhận đúng là rủi ro thật rồi sửa lại URL production ngay.
2. **`chat_id` nhóm Zalo thật** lấy từ execution `1438`: `zgr-891bfa57540ebd50e41f` (`chat_type:
   "GROUP"`, khác `"PRIVATE"` của chat 1-1). Đã `UPDATE gateway.notify_targets SET zalo_chat_id =
   'zgr-891bfa57540ebd50e41f'` cho CẢ 3 category (`od_kammer_bav`, `od_hoadon`, `od_giayto`) — user
   xác nhận Zalo chỉ có 1 nhóm, không chia topic, nên dùng chung 1 chat_id là đúng.
3. **Gửi tin nhắn thật vào nhóm Zalo — THÀNH CÔNG**, user tự xác nhận đã nhận được trong nhóm.
   `sendMessage` trả `{"ok":true,"result":{"message_id":"...","date":...}}`.
4. Tính năng "Mirror thông báo forward sang Zalo" (`Send Zalo Notify` trong `Telebot ClickUp
   Reader`) giờ **CÓ ĐỦ ĐIỀU KIỆN HOẠT ĐỘNG THẬT** khi user thực hiện 1 lượt Upload OneDrive →
   forward vào nhóm Telegram → tự động mirror sang Zalo. **CHƯA test qua đúng luồng Telegram thật**
   (chỉ mới test isolate cuộc gọi Zalo trực tiếp) — cần user tự đi hết luồng thật 1 lần: Upload
   OneDrive 1 file → bấm forward vào 1 trong 3 category → xác nhận tin nhắn đến CẢ Telegram VÀ Zalo.

**Ghi chú kỹ thuật phát sinh trong lúc test (đã thêm RULES.md #16 mở rộng)**: sửa `jsonBody` thêm
`secret_token` qua `setNodeParameter` rồi `updateNodeParameters(replace:true)` ĐỀU báo thành công
nhưng **không hề áp dụng** — chỉ `removeNode`+`addNode` mới thực sự sửa được. Đã dọn sạch 4 node
tạm (`TEMP ...`) dùng để verify qua `execute_workflow` (nodes có credential — Postgres, Telegram —
bị "pinned"/giả lập khi dùng `test_workflow`, phải dùng `execute_workflow` với
`executionMode:"manual"` mới chạy thật kể cả gọi external API/DB thật).

## 🔴 (09/09/2026, phiên tiếp 4) — `secret_token` KHÔNG hề được áp dụng 2 lần liên tiếp

User báo "không thấy dòng secret_token ở đâu" sau khi phiên trước báo đã sửa xong — kiểm tra lại
`get_workflow_details` xác nhận ĐÚNG: cả 2 lần sửa trước (`setNodeParameter` rồi
`updateNodeParameters replace:true`) đều báo `appliedOperations` thành công nhưng **thực tế không
áp dụng gì cả** — đây là lỗi CÙNG LOẠI với RULES.md #16 (trước chỉ biết xảy ra với `credentials`,
giờ xác nhận xảy ra cả với tham số thường như `jsonBody`). Đã cập nhật RULES.md #16 mở rộng phạm vi
cảnh báo. **Đã sửa dứt điểm bằng `removeNode`+`addNode`** (cách duy nhất xác nhận hoạt động), verify
lại bằng `get_workflow_details` TRƯỚC khi publish lần này — xác nhận đúng, đã publish.

Node `Call Zalo setWebhook` giờ gửi `secret_token: "Haianhtran89"` đúng thật (dạng expression
`={{ {...} }}` thay vì object tĩnh, để tránh nghi ngờ object tĩnh là nguyên nhân — chưa rõ nguyên
nhân gốc của bug này, chỉ biết cách né).

**Việc tiếp theo cho user**: bấm lại "Register Webhook Trigger" → `Call Zalo setWebhook` 1 lần nữa
(lần này chắc chắn có secret_token) → xác nhận `ok:true` → thêm bot vào 1 nhóm Zalo, nhắn thử → lấy
`chat_id` dạng nhóm gửi cho tôi.

## 🟡 (09/09/2026, phiên tiếp 3) — Đã xác nhận schema payload Zalo thật qua execution

User đã hardcode token Zalo vào workflow (xong). Đọc lại 2 execution thật của `Zalo API - Webhook
Test` (`eFH2UIbQirfXSH1b`) — execution `1428` và `1432` — phát hiện:

1. **Schema payload webhook Zalo thật** (execution 1428, tin nhắn 1-1 test):
   ```json
   {"event_name":"message.text.received","message":{"chat":{"chat_type":"PRIVATE","id":"ca7abe8023cfca9193de"},"from":{"id":"ca7abe8023cfca9193de","display_name":"Hải Anh"},"text":"té"}}
   ```
   `chat_id` là CHUỖI CHỮ+SỐ dài (KHÔNG phải số như Telegram), nằm ở `body.message.chat.id`. Nhóm
   sẽ có `chat_type: "GROUP"` thay vì `"PRIVATE"` — **CHƯA có mẫu thật của 1 nhóm**, cần user thêm
   bot vào 1 nhóm Zalo + nhắn thử để xác nhận field `id` tương tự.
2. **`setWebhook` API của Zalo BẮT BUỘC phải kèm `secret_token`** trong body (khác Telegram — ở đó
   optional). Execution 1432 báo lỗi `"Bad request: The secret_token must not be empty"` khi gọi
   thiếu field này. Đồng thời header tin nhắn đến (`x-bot-api-secret-token: Haianhtran89`) cho thấy
   trước đó ĐÃ CÓ 1 lượt đăng ký thành công với secret này (trỏ về URL **test**, chỉ sống khi mở
   editor bấm Listen — chưa phải URL production).
   - **Đã sửa**: node `Call Zalo setWebhook` giờ gửi kèm `{"url": "https://n8n.toididuhoc.net/webhook/zalo-test", "secret_token": "Haianhtran89"}`, đã publish. User cần bấm lại
     "Register Webhook Trigger" → nhánh `Call Zalo setWebhook` 1 lần nữa để webhook trỏ đúng về URL
     PRODUCTION (workflow đã active nên URL này giờ sống thật, không cần mở editor).
   - ⚠️ Việc còn treo: CHƯA thêm bước xác thực header `x-bot-api-secret-token` ở phía node nhận
     (`Zalo Webhook Test`) để chặn request giả mạo không có đúng secret — nên làm khi dọn tính năng
     này để dùng thật lâu dài (không gấp cho việc lấy chat_id nhóm).
3. **Việc tiếp theo (đang chờ user)**: sau khi đăng ký lại webhook vào URL production, thêm bot Zalo
   vào 1 NHÓM thật, nhắn thử 1 tin trong nhóm đó → đọc tin Telegram báo về (hoặc query
   `gateway.zalo_webhook_test_log`) để lấy đúng `chat_id` dạng nhóm (`chat_type: "GROUP"`) → gửi
   cho tôi để điền vào `gateway.notify_targets.zalo_chat_id`.

## 🟡 (09/09/2026, phiên tiếp 2) — Cách nạp token Zalo (Community, không dùng env var) + workflow test riêng

User dùng n8n **Community**, không tiện set biến môi trường qua docker-compose. Đã đổi cách tiếp
cận: **hardcode token trực tiếp vào tham số node trong n8n UI** (user tự dán, Claude không thấy giá
trị thật) thay vì `{{ $env.ZALO_BOT_TOKEN }}`. Node `Send Zalo Notify` (`Telebot ClickUp Reader`,
`9JJRrh36H2rLwtnu`) hiện có URL dạng:
`https://bot-api.zaloplatforms.com/botPASTE_YOUR_ZALO_BOT_TOKEN_HERE/sendMessage` — user cần tự mở
node trong n8n, thay `PASTE_YOUR_ZALO_BOT_TOKEN_HERE` bằng token thật.

**⚠️ Đã thêm RULES.md mục 17** (đọc trước khi commit bất kỳ workflow nào chứa cách hardcode này):
vì repo git public, TRƯỚC KHI commit file export JSON của workflow có node dạng này, PHẢI kiểm tra
lại xem đoạn token trong file có phải vẫn là placeholder `PASTE_YOUR_..._TOKEN_HERE` hay không —
nếu user đã điền thật rồi export ra, phải thay lại thành placeholder trước khi add/commit. Danh
sách node đang dùng cách này: xem RULES.md mục 17 (2 workflow, cập nhật khi thêm mới).

**Workflow mới**: `Zalo API - Webhook Test` (n8n ID `eFH2UIbQirfXSH1b`, project cá nhân
"Hai Anh Tran <haianhtran89@live.de>") — dựng riêng để khám phá format payload thật của Zalo
webhook (tài liệu `bot.zapps.me/docs` không liệt kê đầy đủ schema `getUpdates`/webhook), đặc biệt
là tìm đúng field chứa `chat_id` của 1 GROUP Zalo (khác với chat 1-1). Gồm 2 nhánh:
- **Nhánh Webhook** (`Zalo Webhook Test`, path `/webhook/zalo-test`, POST, `responseMode: onReceived`
  tự trả 200 ngay): mọi update Zalo gửi tới đây được ghi vào bảng mới `gateway.zalo_webhook_test_log`
  (cột `payload JSONB`, tự tạo bảng qua node `Ensure Zalo Log Table`) VÀ báo cho admin qua Telegram
  System Bot kèm preview payload (cắt 600 ký tự đầu) + câu SQL sẵn để xem đầy đủ.
- **Nhánh Manual Trigger** (`Register Webhook Trigger`, bấm tay trong n8n): 2 nhánh song song —
  `Call Zalo getMe` (kiểm tra token còn sống, trả về username/id bot) và `Call Zalo setWebhook`
  (đăng ký `https://n8n.toididuhoc.net/webhook/zalo-test` làm webhook nhận update cho bot Zalo).
- Có sticky note hướng dẫn 5 bước ngay trong workflow (điền token → test getMe → đăng ký webhook →
  thêm bot vào nhóm Zalo + nhắn thử → đọc payload thật để tìm field chat_id → điền vào
  `gateway.notify_targets.zalo_chat_id`).
- **CHƯA test được gì cả** — vẫn đang chờ đúng 1 thứ: token Zalo thật do user điền vào 2 node
  `Call Zalo setWebhook`/`Call Zalo getMe` trong workflow test này VÀ node `Send Zalo Notify` trong
  ClickUp Reader (3 chỗ, cùng 1 token — xem RULES.md #17 để không nhầm chỗ nào).
- ⚠️ Lưu ý: URL webhook `/webhook/zalo-test` chỉ hoạt động ở chế độ **production** (workflow phải
  active/published) — n8n cũng có URL `/webhook-test/zalo-test` riêng chỉ sống khi đang mở editor
  bấm "Listen for test event", KHÔNG dùng URL đó để `setWebhook` (sẽ chết ngay khi đóng editor).

## 🟡 (09/09/2026, phiên tiếp 1) — Mirror thông báo Upload OneDrive sang nhóm Zalo

Đã đọc tài liệu `https://bot.zapps.me/docs` — API Bot Zalo có cấu trúc gần giống hệt Telegram Bot
API: `POST https://bot-api.zaloplatforms.com/bot<BOT_TOKEN>/sendMessage`, body
`{chat_id, text, parse_mode: "markdown"|"html"}`, token nằm ngay trong URL (không phải header).

**Đã build xong (workflow `Telebot ClickUp Reader`, `9JJRrh36H2rLwtnu`)**: khi admin bấm nút forward
thông báo Upload OneDrive vào 1 trong 3 nhóm Telegram (🏛️ Kammer/BAV, 🧾 Hóa đơn, 📄 Giấy tờ khác),
workflow giờ CŨNG gửi thêm cùng nội dung đó sang 1 nhóm Zalo tương ứng (nếu có cấu hình) — cơ chế
best-effort, không chặn luồng chính nếu gọi Zalo lỗi.
- Bảng `gateway.notify_targets` có thêm cột `zalo_chat_id` (tự tạo qua node "Ensure Zalo Notify
  Column", cũng có ghi lại ở `sql/07_gateway_notify_targets_zalo.sql`).
- Node mới: `Has Zalo Target?` (IF, chỉ chạy tiếp nếu `zalo_chat_id` có giá trị) → `Send Zalo
  Notify` (HTTP Request, `onError: continueRegularOutput`).
- **CHƯA thể test/hoạt động thật vì thiếu 2 thứ, cần user cung cấp:**
  1. **Zalo Bot Token** — tạo bot qua Zalo Bot Creator (`bot.zapps.me`) rồi lấy token.
     ⚠️ **ĐÃ ĐỔI CÁCH LÀM** (xem mục "phiên tiếp 2" ngay bên trên — user dùng n8n Community, không
     tiện set biến môi trường): KHÔNG còn dùng `{{ $env.ZALO_BOT_TOKEN }}` nữa. Giờ user tự hardcode
     token thẳng vào URL của node `Send Zalo Notify` ngay trong n8n UI (thay đoạn
     `PASTE_YOUR_ZALO_BOT_TOKEN_HERE`). Xem RULES.md #17 về việc redact trước khi commit workflow
     này lên git.
  2. **Zalo group chat_id** cho từng category (Kammer/BAV, Hóa đơn, Giấy tờ khác) — sau khi thêm
     bot vào nhóm Zalo và nhắn thử 1 tin, có thể lấy chat_id qua Zalo Bot Creator dashboard hoặc
     gọi `getUpdates`. Cho tôi biết chat_id (không phải bí mật, có thể gửi thẳng trong chat) để
     tôi `UPDATE gateway.notify_targets SET zalo_chat_id = '...' WHERE target_key = '...'` — xem
     câu lệnh mẫu trong `sql/07_gateway_notify_targets_zalo.sql`. Có thể dùng CHUNG 1 chat_id cho
     cả 3 category nếu chỉ có 1 nhóm Zalo, hoặc chat_id riêng từng nhóm nếu có nhiều nhóm.
- Việc còn lại sau khi có đủ 2 thứ trên: điền `zalo_chat_id`, gửi thử 1 lượt forward thật, xác nhận
  tin nhắn tới đúng nhóm Zalo với format hiển thị đúng (thẻ `<b>` HTML — cần xác nhận Zalo render
  đúng, tài liệu ghi hỗ trợ `parse_mode: html` nhưng chưa test thật).

## Trạng thái theo bot / workflow (09/09/2026)

| Bot / Workflow | Trạng thái | Ghi chú |
|---|---|---|
| **Gateway** (`GW Gateway - Telegram`, `xmEKeIUnzxm2F7dF`) | ✅ Hoạt động, PROD (`@Elite_clickup_bot`) | Auth, router, callback whitelist (`od_`, `odfwd_`, `odhelp`, `chitiet_`, `sync_`) |
| **Telebot ClickUp Reader** (`9JJRrh36H2rLwtnu`, chạy qua Gateway, `bot_key: telebot_main`) | ✅ Hoạt động đầy đủ · ✅ Mirror Zalo đủ điều kiện chạy thật (test isolate OK, chưa test full luồng Telegram) | `/task`, chi tiết task, Upload OneDrive (chọn tên/preset/tùy chỉnh/giữ gốc, forward thông báo vào nhóm Telegram, `/cancel`) — TẤT CẢ đã user xác nhận chạy thật. Mirror thông báo forward sang nhóm Zalo — token đã hardcode, `zalo_chat_id` đã điền cho cả 3 category, gửi thử trực tiếp tới Zalo THÀNH CÔNG (xem mục "phiên tiếp 5" ở trên) — còn thiếu 1 lượt test qua ĐÚNG luồng Upload OneDrive → forward Telegram thật |
| **Bot Xử Lý Ảnh** (`6I4MnJiJCiv2JOIr`, qua Gateway, `bot_key: image_bot`) | ✅ `/xoanen`, `/tomtat` hoạt động OK · ⏸️ AI xoá nền/upscale TẠM DEACTIVATE | Tính năng 🤖 AI xoá nền / 🔍 Upscale đã build xong nhưng đang **tạm tắt** (2 node `Call OpenRouter (...)` set `disabled`, 2 nút bấm đã gỡ khỏi tin nhắn kết quả) theo yêu cầu 09/09/2026 — chờ user tạo credential rồi bật lại. Xem mục checklist |
| **Telebot Admin System** (`eWtu7Qs85Hes0HuP`, bot riêng `@elite_n8n_system_bot`) | ✅ Hoạt động đầy đủ | `/task`, `/sync`, `/sync_status`, `/db_status`, `/backup_n8n`, `/backup_db`, `/version`, `/cancel`, `/user_list` (danh sách + panel quản lý quyền đầy đủ 13 route) |
| **SQL - ClickUp Full Reconcile** (`G1R0okF0rUziySu9`) | ✅ Hoạt động, đã fix DKPV/PVTC | Xem mục "DKPV/PVTC" bên dưới |
| **SQL - ClickUp Sync Scheduler** (`loCm8Tg8Sqfj7ygy`) | ✅ Hoạt động | Điều phối đa-List theo `clickup.sync_targets`, chạy mỗi 5 ngày |
| **SQL - ClickUp Live Update (Webhook)** (`uqTqjtHYieotPZuc`) | ✅ Hoạt động, đã fix 2 lỗi | Ghi đè Postgres real-time khi sửa trên ClickUp; thông báo → nhóm topic 2 |
| **SQL - Backup System** (`iVtOA9LEtjpLDkln`) | ✅ Hoạt động | `/backup_*` trả lời trực tiếp admin; chạy tự động (Chủ nhật 2h sáng) báo vào nhóm topic 6 |
| **GW Error Handler** (`34ccboHpyoY2r691`) | ✅ Hoạt động | Báo lỗi vào nhóm topic 4 + ghi `gateway.error_logs` |
| **GW Weekly Error Report** (`ZJvP7L2aVPpeCGGW`, MỚI) | 🟡 Đã build, CHƯA test thật | Thứ 2 8h sáng, DM admin — xem checklist |
| **Help Bot GPT** | ⏳ Code xong, CHƯA gắn Gateway | Chờ Workflow ID thật (placeholder `REPLACE_HELP_BOT_ID`) |
| ~~Crawl Bot (khái niệm lệnh `/crawl`)~~ | ❌ Lệnh đã bỏ hẳn (09/09/2026) | `/crawl` không còn tồn tại. Nhưng Ý TƯỞNG "bot lắng nghe + ghi Postgres" đã tách thành workflow riêng `GW Crawl Bot - Group Capture` (dùng credential `Elite Crawl Bot`) — xem dòng "Nhóm chat capture" bên dưới |
| **Nhóm chat capture + tóm tắt AI** | 🟡 Điều kiện tiên quyết ĐÃ XONG (Privacy Mode tắt + bot đã vào nhóm) — CHƯA test qua Telegram thật | Ghi log giờ do workflow RIÊNG `GW Crawl Bot - Group Capture` (`SNNrXneenXVnLHh6`, bot `Elite Crawl Bot`) đảm nhiệm — nhánh ghi log cũ trong Gateway (bot Elite Clickupbot) đã bị `disabled` để tránh ghi trùng 2 lần/tin nhắn. Tóm tắt hàng đêm (`GW Daily Chat Summary`, DeepSeek) + retention tự động (raw message giữ 14 ngày, bảng tóm tắt giữ 365 ngày). `/lichsu`/`/timkiem` dạng bấm nút 3 bước (Admin System = mọi nhóm; ClickUp Reader = filtered theo user) + `/sum` (chỉ ClickUp Reader). **Phiên sau: chạy tiếp Bước 1-4 trong mục "🧪 Hướng dẫn test" bên dưới** (test ghi log thật → tóm tắt đêm → `/lichsu` admin → `/lichsu`/`/timkiem`/`/sum` user có lọc) |

## ✅ Đã xác nhận SỬA XONG — Phương án A cho DKPV/PVTC (quyết định 09/09/2026)

Kiểm tra trực tiếp Postgres xác nhận **đã được triển khai đúng, không cần sửa gì thêm**:
- Khóa chính `clickup.task_links` hiện là `(student_task_id, order_task_id, link_type, year)` —
  cho phép 1 đơn hàng xuất hiện ở NHIỀU năm khác nhau (học sinh apply lại) mà không bị lỗi
  "duplicate key" như trước.
- Node `Trích Xuất Task Links` (trong `SQL_ClickUp_Full_Reconcile.json`) nhận diện CẢ `DKPV <năm>`
  lẫn `PVTC <năm>` bằng regex tự động, không hardcode tên field theo năm.
- Đã xác nhận 0 dòng trùng lặp thật trong bảng.

## 🔴 Việc còn tồn đọng thật sự (đã lọc bỏ mục đã xong/lỗi thời)

0. **⏸️ Tính năng AI xoá nền/upscale (Bot Xử Lý Ảnh) — TẠM DEACTIVATE 09/09/2026, chờ user rảnh
   quay lại.** Đã build xong node gọi OpenRouter Image API (`https://openrouter.ai/api/v1/images`,
   model `google/gemini-2.5-flash-image`, ~$0.0003/ảnh input + ~$0.00003/ảnh output — giá tra trực
   tiếp từ API OpenRouter, không đoán), nhưng 2 node `Call OpenRouter (AI Bỏ Xoá Nền)` và
   `Call OpenRouter (Upscale)` trong workflow `Bot Xử Lý Ảnh` (`6I4MnJiJCiv2JOIr`) đang bị
   `disabled: true` và 2 nút bấm dẫn tới chúng đã bị gỡ khỏi tin nhắn kết quả `/xoanen` (cả 2
   trường hợp thành công và remove.bg lỗi) — để tránh user bấm phải nút dẫn tới lỗi. **Lý do tạm
   dừng**: node HTTP Request gọi endpoint này CẦN 1 credential (Claude không tự tạo credential
   chứa API key được), và đã thử phương án dùng credential OpenRouter có sẵn (đang gán cho node
   model LangChain) qua `predefinedCredentialType` để đỡ phải tạo credential mới — **n8n từ chối
   thẳng**, vì credential loại `openRouterApi` chỉ đăng ký cho node LangChain, không dùng chung
   được với HTTP Request thường (xem CHANGELOG "tiếp 15"). Cũng đã xác nhận rõ **không thể** thay
   bằng cặp node `chainLlm` + `lmChatOpenRouter` (đầu ra của cặp node đó luôn là text, không có
   khả năng trả về binary ảnh — đã tra schema thật của n8n để xác nhận, không phải suy đoán).
   **Để làm tiếp khi rảnh**: (a) tạo 1 credential loại "Simplified Custom Auth"
   (`httpTemplatedCustomAuth`) tên gợi ý "OpenRouter HTTP", Auth Template
   `{"headers":{"Authorization":"Bearer {{api_key}}"}}`, dán OpenRouter API key vào ô secret;
   (b) gán credential đó vào ĐÚNG 2 node trên trong n8n UI; (c) bỏ `disabled: true` ở 2 node đó;
   (d) thêm lại 2 nút "🤖 Xoá nền bằng AI" / "🔍 Upscale cho sắc nét" vào 2 tin nhắn
   `Gửi Ảnh Đã Xóa Nền` và `Báo Lỗi Remove.bg` (cấu trúc nút cũ xem CHANGELOG "tiếp 14" hoặc git
   history workflow). **CHƯA test thật** lượt nào (trigger callback không execute được qua MCP).
1. **Nhóm chat capture + tóm tắt AI** — đã build xong toàn bộ 3 phần (ghi log, tóm tắt đêm, lệnh
   xem lại có bấm nút cho cả admin lẫn user thường) nhưng **CHƯA test qua Telegram thật lượt nào**.
   Xem mục "🧪 Hướng dẫn test" ngay bên dưới để biết chính xác cách test và các điểm rủi ro cần
   để ý (đặc biệt bộ lọc theo user, tránh lộ chat nhóm khác).
2. **`GW Weekly Error Report`** (mới tạo 09/09/2026) — chưa test thật qua Telegram (chạy thử sẽ gửi
   tin nhắn thật cho admin nên chưa tự chạy). Cần user tự bấm "Execute workflow" trong n8n để xem
   trước, hoặc đợi tới Thứ 2 tới. **Bổ sung 09/09/2026**: giờ có thể test tương đương ngay lập tức
   qua `/error_logs` (xem, không đổi DB) hoặc `/error_log_now` (xem + đánh dấu `status='reported'`)
   ở Admin System — không cần đợi Thứ 2 hay vào n8n UI nữa. Cả 2 lệnh đều kèm sẵn 1 prompt copy
   thẳng vào Claude Code để bắt đầu sửa lỗi ngay (có context repo + docs cần đọc trước, không cần
   dò lại toàn bộ dự án). **CHƯA test qua Telegram thật lượt nào** (cùng lý do: Trigger không
   execute được qua MCP).
3. **Help Bot GPT** — code đã viết, chưa gắn vào Gateway vì chưa có Workflow ID thật.
4. **`restore.sh`** (script khôi phục thảm họa) — chưa test trên 1 n8n instance trống thật sự.

> **Đã đóng hẳn 09/09/2026** (không còn theo dõi):
> - "Nền trắng"/"chèn logo" cho Bot Xử Lý Ảnh — user xác nhận không cần thiết ở thời điểm này,
>   chưa từng build gì nên không cần dọn workflow.
> - **Crawl Bot** — user xác nhận ý tưởng ban đầu của nó (bot lắng nghe tin nhắn nhóm/topic + lưu
>   Postgres) **chính là** tính năng "Nhóm chat capture" ở mục 1 — không phải 2 việc khác nhau.
>   Việc capture đã chạy ngay trong `GW Gateway - Telegram` (nhánh `Là Tin Nhắn Nhóm?` → `Ghi Log
>   Tin Nhắn Nhóm`, áp dụng cho MỌI nhóm bot có mặt, không cần sub-workflow riêng) — nên không cần
>   xây gì thêm. Đã dọn: bỏ `sum`/`crawl` khỏi `COMMAND_MAP` và bỏ `crawl_bot` khỏi
>   `AVAILABLE_BOTS` (2 lệnh này trước đó route vào node `→ Sub: Crawl Bot` đang bị disabled →
>   im lặng không phản hồi gì, một bug nhỏ chưa ai báo — giờ sẽ trả lời "❓ Lệnh không hợp lệ" tử
>   tế thay vì im lặng). Node `→ Sub: Crawl Bot` giữ nguyên (đã disabled từ trước, vô hại, không
>   xoá để tránh động vào `Switch (Route bot?)` không cần thiết.

> Đã bỏ hẳn (không còn theo dõi): ý tưởng "nền trắng"/"chèn logo" cho Bot Xử Lý Ảnh — user xác
> nhận 09/09/2026 là không cần thiết ở thời điểm này, chưa từng build gì nên không cần dọn workflow.

## 🧪 Hướng dẫn test tính năng MỚI (09/09/2026) — Nhóm chat capture + `/lichsu` + `/timkiem`

Tính năng này gồm 3 phần liên kết: (1) ghi log tin nhắn nhóm, (2) tóm tắt AI hàng đêm, (3) lệnh
xem lại có bấm nút. Cả 3 đã publish nhưng **chưa ai test qua Telegram thật** — Trigger không
execute được qua MCP nên phần này bắt buộc phải test tay. Làm đúng thứ tự dưới đây.

### Bước 0 — Điều kiện tiên quyết (bắt buộc, làm trước tất cả) — ✅ ĐÃ XONG (09/09/2026)

1. ✅ Đã tắt Privacy Mode qua @BotFather cho bot **`Elite Crawl Bot`** (KHÔNG PHẢI Elite Clickupbot
   — từ 09/09/2026 việc ghi log đã tách sang bot riêng này, xem CHANGELOG "tiếp 21").
2. ✅ Đã thêm `Elite Crawl Bot` vào các nhóm/supergroup cần ghi log.

**Việc còn lại cho phiên sau (chưa làm)**: Bước 1-4 bên dưới (test ghi log thật, test tóm tắt AI
đêm, test `/lichsu` bản Admin, test `/lichsu`+`/timkiem`+`/sum` bản User có lọc theo user) — vẫn
CHƯA test qua Telegram thật lượt nào, chỉ mới xong phần điều kiện tiên quyết.

### Bước 1 — Test ghi log tin nhắn nhóm

1. Nhắn vài tin nhắn thường (không phải lệnh) trong 1 nhóm có bot.
2. Kiểm tra trong Postgres:
   ```sql
   SELECT chat_id, chat_title, user_id, message_text, ts
   FROM gateway.group_chat_log ORDER BY ts DESC LIMIT 20;
   ```
3. Nếu bảng trống → khả năng cao Privacy Mode chưa tắt đúng bot (Bước 0.1), hoặc bot chưa thực sự
   là admin/thành viên nhóm đó.

### Bước 2 — Test tóm tắt AI hàng đêm (`GW Daily Chat Summary`, id `ElSGQgdHPMtrzwME`)

Workflow này chạy tự động 1h sáng. Để test ngay không cần đợi:
1. Mở workflow trong n8n UI → bấm "Execute workflow" thủ công (hoặc dùng `test_workflow` qua MCP
   với `method: "prepared"` nếu instance hỗ trợ MCP server nội bộ).
2. Kiểm tra bảng:
   ```sql
   SELECT chat_id, chat_title, summary_date, message_count, summary_text
   FROM gateway.daily_chat_summary ORDER BY summary_date DESC;
   ```
   **Lưu ý (09/09/2026)**: workflow này giờ chạy thêm 2 job dọn dẹp song song mỗi lần chạy (kể cả
   chạy tay) — xóa `gateway.group_chat_log` cũ hơn 14 ngày và `gateway.daily_chat_summary` cũ hơn
   365 ngày. Vô hại lúc mới test (chưa đủ dữ liệu cũ để xóa) nhưng cần nhớ về sau: `/timkiem`
   (tìm nội dung tin nhắn gốc) sẽ KHÔNG còn tìm thấy gì cũ hơn 14 ngày.
3. Nếu không có dòng nào cho nhóm đã nhắn tin ở Bước 1 → kiểm tra credential DeepSeek
   (`lmChatDeepSeek`, id `F7tLItIIVtzpZGqS`) còn hợp lệ không, và `gateway.group_chat_log` có dữ
   liệu của NGÀY HÔM ĐÓ hay không (query nhóm theo `message_count > 0`).

### Bước 3 — Test `/lichsu` (bản Admin — mọi nhóm)

1. Nhắn `/lichsu` cho **System Bot** (`@elite_n8n_system_bot`, chat riêng với admin).
2. Kỳ vọng: hiện 4 nút số ngày (1/3/5/7) + nút ❌ Hủy.
3. Bấm 1 nút ngày → kỳ vọng: hiện danh sách nhóm dạng link (bấm được) + "🌐 Tất cả nhóm" + nút Hủy.
4. Bấm 1 link nhóm (hoặc "Tất cả nhóm") → kỳ vọng: nhận tóm tắt đúng nhóm/khoảng ngày đã chọn.
5. Test nút ❌ Hủy ở cả bước 2 và 3 → kỳ vọng: nhận "❌ Đã hủy" (dùng chung reply với `/cancel`).
6. (Tùy chọn) Test cú pháp gõ tay cũ vẫn hoạt động: `/lichsu 7` (tất cả nhóm) và
   `/lichsu 7 <chat_id>` (1 nhóm cụ thể, lấy `chat_id` từ bước 3).
7. Test `/timkiem` không tham số → kỳ vọng: liệt kê nhóm (dạng `<code>` để copy `chat_id`) + nút
   Hủy. Sau đó gõ `/timkiem <chat_id> <từ khóa>` → kỳ vọng: trả về các tin nhắn gốc chứa từ khóa.

### Bước 4 — Test `/lichsu` + `/timkiem` (bản User thường — CÓ LỌC, quan trọng nhất)

Đây là phần rủi ro cao nhất vì liên quan bảo mật dữ liệu chat.

1. Dùng **2 tài khoản Telegram khác nhau** (User A và User B), cả 2 đều đã được cấp quyền
   `telebot_main` qua `/user_list`.
2. User A nhắn vài tin trong Nhóm X (bot có mặt). User B KHÔNG nhắn gì trong Nhóm X, chỉ nhắn
   trong Nhóm Y.
3. Đợi qua đêm (hoặc chạy tay `GW Daily Chat Summary` như Bước 2) để có tóm tắt cho cả 2 nhóm.
4. User A nhắn `/lichsu` cho **Elite Clickupbot** (bot chính) → bấm 1 số ngày → **kỳ vọng: chỉ
   thấy Nhóm X trong danh sách chọn nhóm, KHÔNG thấy Nhóm Y**.
5. User B lặp lại tương tự → **kỳ vọng: chỉ thấy Nhóm Y, KHÔNG thấy Nhóm X**.
6. **Test cố tình vượt rào**: User B tự gõ tay `/timkiem <chat_id_của_Nhóm_X> việc` (dùng đúng
   `chat_id` thật của Nhóm X mà họ không tham gia) → **kỳ vọng: trả về "Không tìm thấy" (0 dòng)**,
   KHÔNG được trả nội dung thật của Nhóm X. Đây là test quan trọng nhất — nếu User B nhìn thấy nội
   dung Nhóm X là có lỗ hổng lộ dữ liệu, cần báo ngay để vá (xem cách lọc trong CHANGELOG
   09/09/2026 "tiếp 14" — dùng `EXISTS` join `gateway.group_chat_log` theo `user_id`).
7. Kiểm tra `/help` của Elite Clickupbot có liệt kê đúng `/lichsu` + `/timkiem` cho user.

### Nếu có lỗi khi test

- Không thấy nút nào cả (tin nhắn gửi ra nhưng trơn) → kiểm tra lại đúng bẫy RULES.md #14
  (inlineKeyboard set bằng 1 expression động cho cả field).
- Bấm nút không phản hồi gì (không có execution mới trong n8n) → khả năng callback prefix chưa có
  trong whitelist của `GW-03 Router` (với bot User) hoặc route chưa khớp trong `Phân tích lệnh`/
  `Switch` (cả 2 bot) — xem RULES.md #13/#15 về batch rollback và `sourceIndex`/`targetIndex`.
- `/lichsu`/`/timkiem` báo "Lệnh không hợp lệ" ngay từ bot User → kiểm tra `COMMAND_MAP` trong
  node `⚙️ Config` của `GW Gateway - Telegram` có đủ `lichsu`/`timkiem` không (lỗi này đã xảy ra
  1 lần trong lúc build, đã fix — xem CHANGELOG).

## 📇 Index thay đổi/lỗi đã fix gần đây (đọc CHANGELOG.md để biết chi tiết đầy đủ từng mục)

Danh sách tra nhanh — mỗi dòng trỏ tới mục tương ứng trong `CHANGELOG.md` (tìm theo ngày/tiêu đề):

- **09/09/2026 (tiếp 14)**: button hóa `/lichsu` (3 bước: chọn ngày → chọn nhóm → xem tóm tắt,
  dùng deep-link hyperlink cho danh sách nhóm thay vì inline keyboard động — tránh bẫy RULES.md
  #14) · mở `/lichsu` + `/timkiem` cho user thường qua `Telebot ClickUp Reader`, có lọc theo
  `user_id` (chỉ thấy/tìm được nhóm mình từng nhắn tin, kể cả khi cố gõ tay `chat_id` khác) · phát
  hiện + fix Gateway thiếu `lichsu`/`timkiem` trong `COMMAND_MAP` (lệnh sẽ báo "không hợp lệ" nếu
  thiếu) · thêm whitelist callback `ulchs_` vào `GW-03 Router`.
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
