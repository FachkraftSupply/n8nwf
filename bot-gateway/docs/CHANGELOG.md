# CHANGELOG — Bot Gateway (bàn giao sang phiên chat mới đọc `docs/PROJECT_STATUS.md`)

Ghi theo ngày, mới nhất lên trên. Chỉ ghi thay đổi có ý nghĩa (workflow/schema/kiến trúc),
không ghi từng lần sửa lỗi vặt trong 1 phiên debug — xem chi tiết trong PROJECT_STATUS.md
nếu cần.

## 2026-09-11 (tiếp 36) — Audit độc lập PASS + thêm comment SQL cho 1 caveat MVCC nhỏ

Audit subagent thứ 2 (kiểm tra lại toàn bộ `GW Error Knowledge` + `Telebot Admin System` sau 2 lần sửa
liên tiếp) PASS toàn bộ, không tìm bug mới nào đang xảy ra thật. Ghi chú duy nhất: `Errors: Mark
Reported` có 2 CTE trong CÙNG 1 câu SQL (`updated` UPDATE + `stats` SELECT) — theo ngữ nghĩa Postgres,
mọi CTE trong 1 câu `WITH` dùng chung 1 snapshot, nên `stats` không thấy được thay đổi `updated` vừa
ghi TRONG CÙNG câu lệnh đó. Hiện KHÔNG sai (vì `open_cnt` tính gộp cả `'open'` lẫn `'reported'` là
"còn mở", việc chuyển trạng thái không đổi con số) nhưng là bẫy tiềm ẩn nếu sau này tách riêng đếm
2 trạng thái đó. Đã thêm comment SQL giải thích ngay trong node để phiên sau không bị bất ngờ, publish
lại (`activeVersionId: 2a977928-6b08-4016-8420-bf247bdedbb8`).

## 2026-09-11 (tiếp 35) — Fix bug thật: `/help` (Admin) mất phản hồi do backtick thừa trong Code node

User báo `/help` bên bot Admin không phản hồi gì ("menu help lại biến mất"). Tra execution log thật
(`2064`) ra node `Nội dung lệnh help` bị `SyntaxError` — 2 dấu backtick thừa nằm bên trong template
literal bao ngoài (`` `<code>@@all</code>` ``, thêm ở phiên tiếp 21 khi viết đoạn "Nhóm mention" vào
help text) làm JS hiểu nhầm kết thúc chuỗi sớm → node lỗi ngay, không tin nào được gửi. Đã bỏ 2
backtick thừa, verify bằng `node -c` (parse OK) + `get_workflow_details` (connections không đổi),
publish lại (`activeVersionId: 5ecf1ab4-2a73-46be-8620-5c821d9dd76d`). Không test được qua MCP
(Telegram Trigger không hỗ trợ `execute_workflow`) — cần user xác nhận lại qua Telegram thật.

## 2026-09-11 (tiếp 34) — Nâng cấp `/error_logs`: fix knowledge base cho agent đọc lại

Yêu cầu user: khi 1 lỗi được sửa xong, lưu lại vào Postgres kèm link execution + nội dung lỗi + cách
sửa, để lần sau AI agent (Claude Code) đọc lại được thay vì phải debug lại từ đầu.

**Workflow MỚI `GW Error Knowledge`** (`GSz6ZluGT5jCgdEc`, publish
`activeVersionId: d79bd142-24d4-4d6c-9f03-8c209c7a0947`): Webhook POST
`https://n8n.toididuhoc.net/webhook/gw-error-knowledge` (không xác thực — chấp nhận rủi ro thấp vì
chỉ chứa mô tả lỗi/cách sửa nội bộ, không PII/tài chính) → `Normalize Input` → `Ensure Fix Columns`
(ALTER 3 cột mới `fix_description`/`fixed_at`/`fixed_by` vào `gateway.error_logs`, idempotent,
`alwaysOutputData`+`onError` đúng Rule #18) → `Switch (Action)` → `action:"search"` (tìm lỗi ĐÃ TỪNG
được sửa khớp từ khóa trong workflow_name/node_name/error_message/fix_description) hoặc
`action:"log_fix"` (UPDATE `status='fixed'`, ghi `fix_description`+`fixed_at`+`fixed_by` theo `id`).
Gọi được qua n8n MCP `execute_workflow` (triggerNodeName `"From Webhook"`, vì `executeWorkflowTrigger`
KHÔNG hỗ trợ gọi trực tiếp qua MCP — đã thử ban đầu, đổi sang Webhook mới chạy được) hoặc HTTP POST
trực tiếp từ bất kỳ agent nào có mạng. **Đã test thật** (execution `2023`, `action:"search"` với từ
khóa không khớp) — xác nhận DDL chạy thật, routing đúng, trả về 0 kết quả như thiết kế.

**Mở rộng `/error_logs`+`/error_log_now`** (`Telebot Admin System`, publish
`activeVersionId: 27ac63ad-9b8e-4121-a152-6a27c25cb691`): SQL của `Errors: Query Recent`/
`Errors: Mark Reported` bọc thêm 1 CTE thống kê (`fixed_cnt`/`open_cnt`/`total_cnt` 7 ngày qua, CROSS
JOIN vào mỗi dòng — tái dùng đúng pattern "1 câu SQL" Rule #11) + trả thêm cột `id`. 2 Code node
`Errors: Build Report (Logs)`/`(Now)` hiện `id` từng lỗi trong tin nhắn, thêm dòng thống kê ✅ đã sửa/
🔓 còn mở, và **prompt Claude Code nhúng sẵn giờ có thêm 2 bước mới**: TRƯỚC khi sửa 1 lỗi → gọi
`GW Error Knowledge` với `action:"search"` xem đã có cách sửa biết trước chưa; SAU khi sửa xong (đã
publish+verify) → gọi lại với `action:"log_fix"` kèm `id`+mô tả cách sửa để lưu lại cho phiên sau —
KHÔNG thay thế bước cập nhật CHANGELOG.md/PROJECT_STATUS.md như cũ, chỉ bổ sung 1 nguồn tra cứu
nhanh bằng SQL. Sửa cả 4 node bằng `removeNode`+`addNode` (đúng Rule #16, không dùng
`updateNodeParameters` cho node đã tồn tại), verify lại đầy đủ SQL/JS/connections qua
`get_workflow_details` trước khi publish.

File mới: `sql/11_gateway_error_logs_fix_tracking.sql` (lưu cấu trúc 3 cột mới, tham khảo — cột thật
đã được `Ensure Fix Columns` tự ALTER, không cần chạy tay).

**Audit độc lập (subagent) tìm ra 1 bug thật**: `Errors: Query Recent`/`Errors: Mark Reported` dùng
`CROSS JOIN` với CTE thống kê — khi 0 lỗi trong 7 ngày, vế trái (0 dòng) làm CROSS JOIN ra 0 dòng
luôn (dù CTE thống kê có 1 dòng), thiếu `alwaysOutputData: true` nên node bị SKIP hoàn toàn theo
đúng cơ chế Rule #6 → tin nhắn "✅ Không có lỗi nào" sẽ KHÔNG BAO GIỜ được gửi trong trường hợp 0 lỗi
(im lặng không phản hồi gì, giống bug hiện tại project rất hay gặp). **Đã sửa ngay**: thêm
`setNodeSettings` `alwaysOutputData: true` cho cả 2 node, verify qua `get_workflow_details`, publish
lại (`activeVersionId: 13e755f0-dfd7-40ea-ae86-fc3eec9e0c42`).

## 2026-09-11 (tiếp 33) — Gateway: chặn tin không phải lệnh trong group (chuẩn bị tắt Privacy Mode)

Debug `/tomtat` không phản hồi trong nhóm "Elite Nhà cửa" ra nguyên nhân gốc ở tầng Telegram, không
phải bug code: bot Gateway (`ClickupElite`) đang Privacy Mode BẬT nên Telegram không chuyển tiếp
ảnh-kèm-caption-lệnh cho bot (chỉ chuyển text thường bắt đầu bằng `/`) — xác nhận qua ảnh member
list ("has no access to messages") + Gateway hoàn toàn không có execution ở đúng thời điểm gửi.
Cần user tắt Privacy Mode qua BotFather để fix triệt để, nhưng trước khi tắt phải sửa `GW-01
Envelope` thêm chặn sớm: trong group, tin không phải lệnh thì bỏ qua hoàn toàn (không auth-check,
không audit log, không reply) — nếu không, tắt Privacy Mode xong bot sẽ nhận MỌI tin nhắn trong
nhóm và trả lời công khai "bạn chưa có quyền" cho mọi thành viên chưa duyệt mỗi khi họ nhắn bất kỳ
gì, gây spam group. Đã publish phần sửa workflow; phần tắt Privacy Mode trên BotFather cần user
thao tác thủ công (ngoài phạm vi n8n).

## 2026-09-11 (tiếp 32) — Fix help text bot user: mất dấu tiếng Việt + emoji hỏng

`/help` bên bot chính (user) bị 2 lỗi thật: chữ Việt không dấu, và emoji viết sai thành escape kiểu
Python (`\U0001F4D8`, không hợp lệ trong JS) nên gửi ra hiện chữ thô thay vì icon. Viết lại toàn bộ
với emoji UTF-8 thật, đủ dấu, chia 5 mục rõ ràng, thêm mục mới hướng dẫn `@@all`/`@@<nhóm>` (tính
năng user cũng dùng được, help cũ chưa từng nói tới). Giữ nguyên escape `&lt;...&gt;` cho placeholder
để không dính lại bug "Unsupported start tag" ở mục dưới. Help bên bot Admin không bị lỗi này.

## 2026-09-11 (tiếp 31) — Fix bug thật Mention Group (menu gửi lỗi 100%) + filter theo group thật

User test thật phát hiện đúng rủi ro "chưa verify" của bản build hôm trước là bug có thật: bấm
"🏷️ Nhóm mention" trong `/user_list` không hiện nút gì. Đọc execution log lỗi thật của
`Telebot Admin System` ra 2 nguyên nhân: (1) text gợi ý "/tao_group <tên>" chứa dấu `<>` thật bị
Telegram HTML parser (`parse_mode: HTML`) hiểu nhầm là tag lạ → toàn bộ message lỗi 400, không gửi
được gì hết — sửa bỏ dấu ngoặc. (2) Cách set `inlineKeyboard.rows` = string expression (field CON
trong 1 object) mà bản trước chọn dùng KHÔNG hoạt động ở runtime (node vẫn resolve ra 17 hàng rỗng
tĩnh từ lúc scaffold, dù save/publish không báo lỗi) — đổi sang set CẢ field `inlineKeyboard` = 1
string expression (`={{ { rows: $json.rows } }}`), verify lại qua `get_workflow_details` xác nhận
đã lưu đúng, publish lại. Phát hiện phụ: `versionId` (draft) từng lệch `activeVersionId` (live) ở
workflow này — nghĩa là 1 lần sửa trước có publish nhưng bản live không khớp bản vừa sửa; từ nay
luôn diff 2 giá trị này sau mỗi lần sửa, không chỉ tin `publish_workflow` trả `success:true`.

Ngoài ra, theo yêu cầu mới của user (nhóm mention "universal" dùng chung mọi group, nhưng chỉ
mention người thật có mặt trong group đang gõ lệnh): sửa `Resolve Mention Users` trong
`GW Mention Resolver`, nhánh named-group thêm `EXISTS (... gateway.group_chat_log WHERE
chat_id=$1 AND user_id=bu.user_id)` — tái dùng tín hiệu "đã từng nhắn trong group này" mà `@@all`
đã dùng, thay vì lấy toàn bộ member global của nhóm mention. Giới hạn cố hữu: vẫn chỉ nhận diện
được người ĐÃ NHẮN chữ trong group đó ít nhất 1 lần, không phải member list Telegram thật.

## 2026-09-10 (tiếp 30) — Build tính năng Mention Group (@@nhóm/@@all) — 3 workflow

Admin tạo "nhóm mention" (danh sách user đặt tên) qua `/tao_group <tên>`; gán/gỡ user qua nút mới
"🏷️ Nhóm mention" trong `/user_list`; user thường gõ `@@<tên nhóm>` hoặc `@@all` trong 1 nhóm
Telegram → bot mention đúng người. Tự build tới giới hạn tối đa theo yêu cầu user, không dừng lại
hỏi giữa chừng.

- **2 bảng mới**: `gateway.mention_groups`, `gateway.mention_group_members` — không dual-write
  Supabase (đã biết cơ chế đó hỏng từ trước, bỏ cho gọn).
- **Workflow MỚI `GW Mention Resolver`** (`ESbedUROf4udAkY6`) — tách hẳn logic xử lý mention ra
  sub-workflow riêng theo đúng yêu cầu user (nhẹ, độc lập, không làm nặng workflow chính). Nhận
  `{chatId, messageId, messageThreadId, tokens}`, resolve user qua 1 câu SQL UNION ALL (`@@all` lấy
  từ `group_chat_log`, tên nhóm cụ thể lấy từ `bot_users` JOIN `mention_group_members`), build text
  mention (`@username` hoặc `tg://user?id=` fallback, cap 50), gửi bằng credential Elite Crawl Bot
  (đã có mặt sẵn trong nhóm, Privacy Mode tắt sẵn). Tự phát hiện + sửa 1 bug thật lúc build (trigger
  node `setNodeParameter` lồng sai vị trí, đúng RULES.md #16). Test bằng `test_workflow`+pin data
  2 kịch bản (có user / không có user) — cả 2 đúng thiết kế.
- **Hook vào `GW Crawl Bot - Group Capture`**: thêm tách `mentionTokens` (regex `@@(\w+)`) không đổi
  hành vi ghi log cũ, gọi `GW Mention Resolver` song song (fire-and-forget, lỗi không ảnh hưởng ghi
  log chính).
- **`Telebot Admin System`**: thêm `/tao_group`, mở rộng `/user_list` (nút toggle nhóm mention, tái
  dùng nguyên pattern "toggle rồi refresh panel" đã có cho quyền bot). `Switch (Admin Extras)` 14→17
  output, verify lại đủ 14 kết nối cũ.
- **Rủi ro CHƯA xác nhận được** (như RULES.md #21 — validator không tin được, cần Telegram thật):
  `Send Mention Menu` là bàn phím Telegram ĐẦU TIÊN trong dự án có SỐ NÚT không cố định (tùy số
  nhóm mention đã tạo) — cú pháp `inlineKeyboard.rows` dạng expression bị validator tĩnh báo sai kiểu
  dù publish thành công, CHƯA xác nhận render đúng qua Telegram thật.
- **Audit PASS**: subagent độc lập đọc lại JSON thật cả 3 workflow, xác nhận PASS ~15 điểm kiểm tra,
  không tìm thấy bug mới. Rủi ro `Send Mention Menu` (bàn phím số nút động) vẫn là điểm DUY NHẤT
  chưa xác nhận được — cần Telegram thật.

## 2026-09-10 (tiếp 29) — Fix bug thật: nút 1/3/5/7 ngày dính nhầm vào tin không liên quan (Admin)

User báo "/lichsu bên admin không có link" + "nhầm lẫn với /error_log_now khi bấm nút ngày". Tra
execution log xác nhận: link `/lichsu` THẬT SỰ VẪN CÓ (thấy rõ `text_link` entity trỏ đúng
`t.me/c/...` trong tin tóm tắt) — nhưng phát hiện bug thật khác: node `Lichsu: Send` (bot Admin) là
1 node TERMINAL DÙNG CHUNG cho 5 nguồn khác nhau (`Lichsu: Build Group List`, `Lichsu: Build Summary
Text`, `Errors: Build Report (Logs)`, `Errors: Build Report (Now)`, `Timkiem: Build Results`) nhưng
lại gắn CỨNG bộ nút "1/3/5/7 ngày + ❌ Hủy" cho MỌI tin nhắn gửi qua nó — kể cả tin `/error_logs`,
`/error_log_now`, `/timkiem` hoàn toàn không liên quan. Khi user bấm 1 nút ngày dính trên tin
`/error_log_now`, bot vẫn hiểu là chọn ngày cho `/lichsu` → đúng bug "nhầm lẫn" user báo.

**Đã sửa**: tách thành 2 node theo đúng pattern Rule #21 (static branch, không dùng expression cho
`replyMarkup`) — `Lichsu: Send` (bỏ hẳn `replyMarkup`, dùng cho Errors×2 + Timkiem) và node MỚI
`Lichsu: Send With Day Picker` (giữ nguyên bộ nút, CHỈ dùng cho `Build Group List`/`Build Summary
Text`). Verify qua `get_workflow_details` xác nhận đúng 5 nguồn được phân đúng 2 nhánh, publish.

## 2026-09-10 (tiếp 28) — Help text: phân biệt /sum vs /lichsu

Thêm 1 dòng giải thích ngắn vào `/help` (chỉ bot user — `/sum` không tồn tại ở Admin System):
`/sum` = xem nhanh tuần này của TẤT CẢ nhóm, không cần bấm gì thêm; `/lichsu` = tự chọn số ngày
(1/3/5/7) và có thể xem riêng 1 nhóm.

## 2026-09-10 (tiếp 27) — Sửa /timkiem: cú pháp mới + tách nhánh song song + help text đầy đủ

- `/timkiem <từ khóa>` giờ tìm trong TẤT CẢ nhóm (user: nhóm mình tham gia; admin: mọi nhóm), không
  bắt buộc chat_id nữa. `/timkiem <chat_id> <từ khóa>` vẫn dùng được để giới hạn 1 nhóm.
- Root cause của báo lỗi user: nhánh "hiện danh sách nhóm" và "tìm kiếm" chạy SONG SONG thay vì qua
  đúng 2 nhánh IF `Show List?` — sửa lại mutually exclusive, chỉ 1 tin nhắn/lần gõ lệnh.
- Thêm guard SQL chặn từ khóa rỗng khớp mọi tin nhắn.
- Cập nhật `/help` cả 2 bot: cú pháp `/timkiem` mới + nhãn 🔒 phân biệt lệnh admin-exclusive.

## 2026-09-10 (tiếp 26) — Cập nhật /help: thêm 2 nút xóa file + link timkiem

Node `Nội dung lệnh help` (`Telebot ClickUp Reader`) chưa nhắc "🗑️ Xóa file vừa upload"/"🗑️ Xóa & thu
hồi" (phiên tiếp 14) và link "Xem gốc" của `/timkiem` (phiên tiếp 16). Đã bổ sung, publish, verify.

## 2026-09-10 (tiếp 25) — Link tin nhắn gốc cho /lichsu + /timkiem (admin + user), bỏ capture media

- `GW Crawl Bot - Group Capture`: bỏ capture tin nhắn media/file (chỉ giữ text thuần).
- `GW Daily Chat Summary`: AI trích dẫn `[#message_id]` cho chủ đề, node mới `Linkify Summary` thay
  thành link `t.me/c/<internal_id>/<message_id>` thật, lưu pre-escaped vào `summary_text`. Prompt rút
  gọn 8→6 dòng để tiết kiệm token.
- `Telebot ClickUp Reader` + `Telebot Admin System`: bỏ escape 2 lần cho `summary_text`, `/timkiem`
  thêm link "🔗 Xem gốc" mỗi kết quả. Đồng bộ cả bản user (lọc theo nhóm tham gia) lẫn admin (không
  lọc, xem mọi nhóm).
- Tự phát hiện + sửa 3 lỗi mất connection do `removeNode`+`addNode` (đúng bài học Rule #16).
- Xác nhận thật qua `execute_workflow`: link render đúng, ghi DB thành công.
- Tạo doc ClickUp hướng dẫn dùng bot cho user tra cứu:
  https://app.clickup.com/9018351620/docs/8crj804-4598
- Ghi nhận roadmap mới (chưa build): mention `@@group`/`@@all`, quản lý nhóm mention qua
  `/tao_group`/`/user_list`, AI đọc tin nhắn visa/vé máy bay để tự update ClickUp.
- **Audit độc lập tìm ra 1 bug thật**: `Linkify Summary` thiếu `mode: "runOnceForEachItem"` — chạy
  đúng khi test với 1 nhóm/ngày (không lộ bug), sẽ lỗi/lẫn dữ liệu giữa các nhóm khi có ≥2 nhóm cùng
  ngày. Sửa ngay + verify lại thật với 3 nhóm cùng lúc, xác nhận đúng.

## 2026-09-10 (tiếp 24) — Fix GW Daily Chat Summary không bao giờ ra kết quả (2 bug thật)

Kiểm tra thực tế xác nhận `GW Crawl Bot - Group Capture` đang capture đúng dữ liệu thật vào
`gateway.group_chat_log`, nhưng `GW Daily Chat Summary` (`ElSGQgdHPMtrzwME`) chưa từng ra kết quả kể
từ lúc build (09/09) dù chạy đúng lịch.

- **Bug 1 (root cause)**: `Query Groups Aggregated` so sánh `ts::date = (now() - interval '1
  day')::date` bằng UTC (server timezone), trong khi lịch chạy job là 1h sáng giờ Việt Nam (=18:00
  UTC ngày hôm trước) — lệch mất 1 ngày, không bao giờ khớp dữ liệu thật. Sửa: quy đổi cả `ts` lẫn
  `now()` về `Asia/Ho_Chi_Minh` trước khi lấy `::date`, áp dụng đồng bộ cho cả node lọc lẫn node ghi
  `summary_date`.
- **Bug 2**: `Upsert Daily Summary` dùng `queryBatching` mặc định (`single`) — n8n tự cảnh báo khi
  chạy thật với 3 item cùng lúc, rủi ro sai lệch tham số giữa các nhóm. Sửa: `queryBatching:
  'independently'`.
- Xác nhận bằng 2 lần chạy thật (`execute_workflow`, không phải test giả lập): tìm đúng 3 nhóm có
  dữ liệu, AI tóm tắt đúng, ghi thành công vào `gateway.daily_chat_summary`, không còn cảnh báo.
- Đổi tên `08_upload_notify_queue_delete.sql` → `09_upload_notify_queue_delete.sql` (trùng số với
  `08_gateway_group_chat_capture.sql` có sẵn).

## 2026-09-09 (tiếp 23) — Xóa file OneDrive vừa upload + xóa & thu hồi tin đã forward

Build 4 stage (mỗi stage publish riêng để chống mất tiến độ giữa chừng): thêm 6 cột vào
`clickup.upload_notify_queue` (`drive_id`, `item_id`, `fwd_chat_id`, `fwd_message_id`,
`zalo_chat_id_used`, `deleted_at`) + 2 nút mới (`od_del_<id>` trên tin upload result, `od_delfwd_<id>`
trên tin lưu riêng sau forward) + 2 chuỗi xử lý (17 node mới tổng cộng): xóa file trên OneDrive qua
Graph API `DELETE`, xóa tin đã forward trong nhóm Telegram qua `deleteMessage`, và báo hủy vào nhóm
Zalo bằng 1 tin nhắn mới (Zalo Bot API không có API xóa/thu hồi theo tài liệu chính thức). Cả 2
callback đều bắt đầu `od_` nên tự khớp whitelist Gateway có sẵn — không cần sửa `GW Gateway -
Telegram`. Toàn bộ HTTP/Telegram delete dùng `onError: continueRegularOutput` (thiết kế
best-effort). Audit độc lập qua subagent: PASS toàn bộ, không có bug thật. Chưa test qua Telegram
thật — 1 rủi ro mở: giả định shape response của node Telegram `Send Forward Message`
(`message_id`/`chat.id`) chưa xác nhận được vì `test_workflow` pin node Telegram.
**Việc cần user làm**: dán token Zalo thật vào node `OD Delfwd: Announce Zalo Deleted`, rồi test cả
2 nút qua Telegram thật.

## 2026-09-09 (tiếp 22) — Gửi bản lưu riêng vào chat cá nhân khi forward tin nhắn upload OneDrive

Sau khi fix "❓ Trợ giúp" (tiếp 20-21 bên PROJECT_STATUS đánh số "phiên tiếp 11/12") được user xác
nhận hoạt động, user yêu cầu: mỗi lần bot forward tin nhắn thông báo upload OneDrive vào 1 nhóm
Telegram, cũng gửi cùng nội dung vào chat riêng của chính user upload để họ lưu hồ sơ cá nhân.

- **`Telebot ClickUp Reader`** (`9JJRrh36H2rLwtnu`): thêm node `Send Forward Copy To User`
  (Telegram), nối từ output TRUE của `Forward OK?` chạy song song với `Send Forward Message` /
  `Has Zalo Target?` (fan-out 3 nhánh, không xoá connection cũ nào). Dùng `chatId:
  ={{ $json.adminChatId }}` (chat id gốc của người upload, đã có sẵn trong output của
  `Build Forward Message`) + `text` = tiền tố "📋 (Bản lưu riêng cho bạn)" nối với `{{ $json.text }}`
  (đã escape HTML sẵn từ `Build Forward Message`, không escape lại).
- Không cần sửa Gateway (`xmEKeIUnzxm2F7dF`): không tạo/đổi callback_data nào — tính năng này chỉ
  là 1 side-effect tự động của nhánh IF có sẵn.
- Audit độc lập qua subagent: PASS toàn bộ 6 mục kiểm tra (wiring, replyMarkup, Gateway whitelist,
  credential, escaping, các quy tắc khác). 1 gợi ý hardening: thêm `onError: continueRegularOutput`
  cho node mới để lỗi gửi tin riêng (VD user chặn bot) không ảnh hưởng nhánh forward nhóm/Zalo — đã
  áp dụng.
- Publish 2 lần: `d704b252-e314-4f0b-b03a-ce2dccc09a43` (thêm node) →
  `48441cac-286f-41f9-ba4f-7c40d5b02ff0` (thêm hardening).
- **Trạng thái: ĐÃ BUILD + AUDIT PASS + PUBLISH, CHƯA TEST THẬT qua Telegram** — chờ user upload +
  forward thử 1 lần.

## 2026-09-09 (tiếp 21) — Tách bot ghi log nhóm ra riêng (Elite Crawl Bot) + retention 14/365 ngày

Sửa lại đúng theo yêu cầu user làm rõ lại (bản trước "tiếp 20" hiểu NHẦM — credential
`Elite Crawl Bot` không phải để gửi thông báo backup, đã revert lại `SQL - Backup System` về dùng
`Telegram System Bot` như cũ).

- **Workflow mới `GW Crawl Bot - Group Capture`** (`SNNrXneenXVnLHh6`): Telegram Trigger riêng
  dùng credential `Elite Crawl Bot`, CHỈ lắng nghe tin nhắn + ghi `gateway.group_chat_log` —
  không có lệnh/command nào. Đây là bot chuyên trách "backup tin nhắn nhóm", tách biệt hoàn toàn
  khỏi Elite Clickupbot (bot chính vẫn ở trong Gateway, chỉ lo xử lý lệnh `/task`, `/lichsu`,
  `/timkiem`, `/sum`...).
- **Tắt nhánh ghi log cũ trong `GW Gateway - Telegram`** (`Là Tin Nhắn Nhóm?` +
  `Ghi Log Tin Nhắn Nhóm`, `disabled: true`) — vì Elite Clickupbot vẫn ở trong cùng các nhóm để
  dùng lệnh, nếu để cả 2 nhánh chạy song song sẽ ghi TRÙNG 2 lần mỗi tin nhắn.
- **Retention tự động** (thêm vào `GW Daily Chat Summary`, chạy chung lịch 1h sáng mỗi ngày, chạy
  song song độc lập với nhánh tóm tắt AI):
  - `Cleanup Old Group Chat Log (14 ngày)`: `DELETE FROM gateway.group_chat_log WHERE ts < now() -
    interval '14 days'` — tin nhắn gốc chỉ giữ 14 ngày gần nhất (đủ cho `/timkiem` tra cứu gần đây),
    xóa hẳn sau đó để tiết kiệm DB, vì đã có tóm tắt AI lưu lâu dài.
  - `Cleanup Old Daily Summaries (365 ngày)`: `DELETE FROM gateway.daily_chat_summary WHERE
    summary_date < CURRENT_DATE - interval '365 days'` — bảng tóm tắt theo ngày giữ tối đa 1 năm.
  - **Hệ quả cần lưu ý**: sau 14 ngày, `/timkiem` (tìm nội dung gốc) sẽ không còn tìm thấy tin nhắn
    cũ hơn — chỉ `/lichsu`/`/sum` (đọc từ bảng tóm tắt, giữ 365 ngày) vẫn còn dữ liệu xa hơn.
- User yêu cầu rõ: phải hỏi xác nhận trước khi đổi các workflow đang chạy tốt — đã hỏi 3 câu qua
  AskUserQuestion (tắt nhánh cũ? ý nghĩa "14 ngày"? bảng tổng hợp có cần tạo mới không?) và chỉ
  thực hiện sau khi có xác nhận rõ ràng cho cả 3.

## 2026-09-09 (tiếp 20) — Đổi bot gửi thông báo backup sang "Elite Crawl Bot"

- User tạo sẵn 1 bot Telegram mới (credential `Elite Crawl Bot`, id `V8w3wIjyeVaz9Um9`) — token
  còn thừa từ ý tưởng Crawl Bot cũ (đã bỏ, xem "tiếp 17"/"tiếp 18") — quyết định dùng làm bot
  gửi thông báo backup thay cho `Telegram System Bot` dùng chung trước đây.
- Đổi credential ở cả 4 node `Notify Backup ... Xong` (N8N/DB/Credential/Config) trong
  `SQL - Backup System` sang `Elite Crawl Bot`. Giữ nguyên toàn bộ logic gửi (DM admin khi chạy
  tay qua `/backup_n8n`/`/backup_db`, nhóm hệ thống topic 6 khi tự động chạy Chủ nhật 2h sáng).
  **Lưu ý kỹ thuật**: `updateNodeParameters` với `credentials` rỗng+`parameters:{}` KHÔNG áp dụng
  được (giống bug đã gặp lúc sửa node OpenRouter) — phải dùng `removeNode` + `addNode` (giữ
  nguyên `parameters`/`webhookId`/`position`, chỉ đổi `credentials`) mới chắc chắn áp dụng, rồi
  verify lại bằng `get_workflow_details` trước khi publish.

## 2026-09-09 (tiếp 19) — Thêm `/error_logs` + `/error_log_now` (Telebot Admin System)

- Mục tiêu: cho admin xem/tổng hợp lỗi hệ thống ON-DEMAND thay vì chỉ chờ báo cáo tự động Thứ 2
  8h sáng (`GW Weekly Error Report`) — đồng thời mỗi lần xem đều kèm sẵn 1 **prompt paste thẳng
  vào Claude Code** để bắt đầu sửa lỗi ngay, không cần dò lại toàn bộ dự án.
- **`/error_logs`**: SELECT read-only `gateway.error_logs` 7 ngày qua (mọi status) → thống kê số
  lỗi theo từng workflow → kèm chi tiết tối đa 12 lỗi gần nhất (workflow/node/message/execution_url)
  + prompt Claude Code. KHÔNG đổi dữ liệu gì trong DB.
- **`/error_log_now`**: `UPDATE gateway.error_logs SET status='reported' WHERE status='open' AND
  occurred_at >= now() - interval '7 days' RETURNING ...` — đây là hành động "force tổng hợp vào
  DB": các lỗi đang mở được đánh dấu đã tổng hợp (khác `/error_logs` là không đổi gì). Trả về đúng
  format thống kê + prompt như trên, dùng dữ liệu từ chính `RETURNING`.
- **Nội dung prompt Claude Code** (nhúng thẳng trong tin nhắn Telegram, dạng `<pre>` để copy
  nguyên khối) gồm: đường dẫn repo GitHub, thứ tự đọc tài liệu bắt buộc (RULES.md →
  PROJECT_STATUS.md → ARCHITECTURE.md), lưu ý n8n MCP server của dự án này KHÁC package n8n-mcp
  cộng đồng (tên tool khác), URL n8n instance, danh sách lỗi cụ thể kèm `execution_url`, và yêu
  cầu rõ ràng (sửa → publish → cập nhật CHANGELOG/PROJECT_STATUS → commit + push).
- Route mới trong `Telebot Admin System`: `Switch` node lên 21 rule (`error_logs` idx 19,
  `error_log_now` idx 20, fallback dời sang 21) — dùng chung `Check Admin (Errors)` (IF) →
  `Switch (Error Actions)` (2 route) → 2 chain riêng, tận dụng lại đúng pattern `Check Admin` +
  `Switch (Sync Actions)` đã có sẵn trong workflow này (tránh phát minh lại). Đã verify
  `connections` đầy đủ 0-21 trước khi publish (RULES.md #13/#15).
- Update `Nội dung lệnh help` liệt kê 2 lệnh mới.

## 2026-09-09 (tiếp 18) — Bỏ hẳn `/crawl`, biến `/sum` thành tóm tắt tuần này

- **`/crawl`**: bỏ hẳn, không dùng nữa (đã bỏ khỏi `COMMAND_MAP` ở "tiếp 17", không thêm lại).
- **`/sum`**: chuyển thành lệnh tóm tắt nhanh — trả về tóm tắt AI của TẤT CẢ các nhóm user tham
  gia, tính từ đầu tuần (thứ 2, `date_trunc('week', CURRENT_DATE)`) tới hiện tại, không cần bấm
  nút chọn ngày/nhóm như `/lichsu` (một lệnh, một lần gõ, ra kết quả ngay). Vẫn lọc theo
  `user_id` (dùng lại đúng bộ lọc chống lộ chat nhóm khác của `/lichsu`/`/timkiem` bản user).
  Route ở `Telebot ClickUp Reader`: `Switch` thêm rule `sum` (index 16, fallback dời sang 17,
  đã verify lại `connections` sau khi patch theo đúng quy trình RULES.md #13/#15). Thêm lại
  `sum:'telebot_main'` vào `COMMAND_MAP` của Gateway (khác `/lichsu`/`/timkiem`, `/sum` chỉ có ở
  bản user, không có ở Admin System). Update `Nội dung lệnh help` liệt kê `/sum`.

## 2026-09-09 (tiếp 17) — Đóng 2 mục checklist: nền trắng/logo (huỷ), Crawl Bot (gộp vào chat capture)

- **"Nền trắng"/"chèn logo"** (Bot Xử Lý Ảnh) — user xác nhận không cần thiết ở thời điểm này.
  Chưa từng build gì nên không cần dọn workflow, chỉ gỡ khỏi checklist.
- **Crawl Bot** — user làm rõ: ý tưởng ban đầu của nó ("bot lắng nghe tin nhắn nhóm/topic + lưu
  Postgres") **chính là** tính năng "Nhóm chat capture" đã build ở mục "tiếp 13" — không phải 2
  việc khác nhau. Việc capture đã chạy sẵn trong `GW Gateway - Telegram` (nhánh `Là Tin Nhắn
  Nhóm?` → `Ghi Log Tin Nhắn Nhóm`, cho MỌI nhóm bot có mặt, không cần sub-workflow riêng như dự
  tính ban đầu) — nên quyết định không xây `Crawl Bot` riêng nữa.
- Dọn theo quyết định trên: bỏ `sum`/`crawl` khỏi `COMMAND_MAP` và bỏ `crawl_bot` khỏi
  `AVAILABLE_BOTS` trong node `⚙️ Config` của Gateway. **Phát hiện tiện thể 1 bug nhỏ**: 2 lệnh
  `/sum`/`/crawl` trước đó route vào node `→ Sub: Crawl Bot` (đã `disabled: true` từ trước, chưa
  từng gán Workflow ID thật) khiến bot **im lặng không phản hồi gì** khi ai gõ lệnh này — chưa ai
  báo lỗi này. Sau khi bỏ khỏi `COMMAND_MAP`, 2 lệnh này giờ rơi vào route `unknown` → trả lời
  "❓ Lệnh không hợp lệ" tử tế. Cập nhật luôn text node `Hướng dẫn lệnh` (bỏ nhắc `/sum`, thêm
  `/lichsu`/`/timkiem`). Node `→ Sub: Crawl Bot` giữ nguyên (đã disabled, vô hại) để tránh động
  vào `Switch (Route bot?)` không cần thiết.
- Đã publish lại `GW Gateway - Telegram`.

## 2026-09-09 (tiếp 16) — Tạm deactivate tính năng AI xoá nền/upscale (chờ credential)

- Theo yêu cầu user: tạm gác tính năng 🤖 AI xoá nền / 🔍 Upscale (đang chặn bởi việc thiếu
  credential OpenRouter HTTP — xem mục "tiếp 15" bên dưới) để publish được workflow sạch, không
  còn nút bấm dẫn tới lỗi.
- Đã: (1) `setNodeDisabled` cho 2 node `Call OpenRouter (AI Bỏ Xoá Nền)` và
  `Call OpenRouter (Upscale)`; (2) gỡ 2 nút "🤖 Xoá nền bằng AI" / "🔍 Upscale cho sắc nét" khỏi
  CẢ 2 tin nhắn từng hiện chúng (`Gửi Ảnh Đã Xóa Nền` và `Báo Lỗi Remove.bg`) — chỉ còn lại nút
  ❌ Hủy. Người dùng `/xoanen` giờ không còn thấy 2 nút dẫn tới tính năng chưa hoạt động.
  (3) Tiện thể dọn nốt: lúc `setNodeDisabled` cho node Upscale, credential sai `Spaceocr` (bug đã
  ghi ở mục "tiếp 15") lại xuất hiện lại trong draft — dọn sạch lần nữa bằng removeNode+addNode.
- **Để bật lại sau**: xoá `disabled: true` khỏi 2 node trên, thêm lại 2 nút vào 2 tin nhắn (xem
  git history của workflow hoặc mục "tiếp 15"/"tiếp 14" để lấy lại đúng cấu hình cũ), và hoàn
  thành bước tạo credential OpenRouter HTTP (Custom Auth, template
  `{"headers":{"Authorization":"Bearer {{api_key}}"}}`) rồi gán vào 2 node.
- Đã publish lại workflow `Bot Xử Lý Ảnh` ở trạng thái sạch (không lỗi, không nút chết).

## 2026-09-09 (tiếp 15) — Fix bug credential sai ở node Upscale AI (Bot Xử Lý Ảnh)

- Phát hiện **bug thật**: node `Call OpenRouter (Upscale)` đang gán NHẦM credential `Spaceocr`
  (của OCR.space, dùng cho `/tomtat`) thay vì credential đúng cho OpenRouter — copy-paste sai lúc
  build. Đây là lý do chính khiến nút "🔍 Upscale cho sắc nét" không hoạt động.
- Đã thử phương án user đề xuất: dùng credential OpenRouter **có sẵn** (`OpenRouter account`,
  đang dùng cho model DeepSeek/Mistral) qua `authentication: predefinedCredentialType` cho cả 2
  node `Call OpenRouter (...)` để khỏi phải tạo credential mới. **Kết quả: n8n từ chối** —
  credential type `openRouterApi` chỉ được đăng ký cho các node LangChain (`lmChatOpenRouter`),
  KHÔNG hỗ trợ dùng chung với node HTTP Request thường (`setNodeCredential` báo lỗi "node type
  'httpRequest' does not accept credential 'openRouterApi'"). Đây là giới hạn của chính n8n, không
  phải công cụ MCP.
- Đã revert cả 2 node về đúng cấu hình gốc (`genericCredentialType` + `httpTemplatedCustomAuth`),
  xoá credential sai khỏi node Upscale. **Vẫn cần user tạo credential mới** như đã ghi ở
  PROJECT_STATUS.md mục 0 — không có cách nào tránh việc này.

## 2026-09-09 (tiếp 14) — Button hóa `/lichsu` + mở `/lichsu`/`/timkiem` cho user thường

- **`Telebot Admin System`**: `/lichsu` giờ có luồng bấm nút 3 bước thay vì gõ tay: bấm số ngày
  (1/3/5/7) → bấm nhóm muốn xem (hoặc "🌐 Tất cả nhóm") → nhận tóm tắt. Có nút ❌ Hủy ở mọi bước.
  Bước chọn nhóm dùng **deep-link dạng hyperlink** (`t.me/<bot>?start=lchs_g_<days>_<chatId>`),
  không dùng inline keyboard động — vì số nhóm thay đổi, tránh đúng cái bẫy inlineKeyboard-động ở
  RULES.md #14. Cú pháp gõ tay cũ (`/lichsu <1|3|5|7> <chat_id>`) vẫn hoạt động song song cho ai
  quen dùng. `Switch` node của workflow này giờ có 19 rule (thêm `lichsu_day`/`lichsu_pick`/
  `lichsu_cancel`); tự phát hiện và sửa đúng bẫy fallback-wire ở RULES.md #15 ngay lúc thêm y hệt
  lần trước (dây fallback cũ ở output 16 bị patch lại đúng vị trí mới là 19 trước khi publish).
- **Mở `/lichsu` + `/timkiem` cho user thường** (trước đây chỉ admin dùng được, qua bot System
  riêng): thêm 2 lệnh này vào `Telebot ClickUp Reader` (bot chính `Elite Clickupbot` mà user dùng
  hàng ngày) với **bộ lọc theo user** — chỉ liệt kê/tóm tắt/tìm trong các nhóm mà chính user đó đã
  từng nhắn tin (join `EXISTS` vào `gateway.group_chat_log` theo `user_id`, chặn cả trường hợp gõ
  tay một `chat_id` không thuộc về mình). Cùng luồng bấm nút 3 bước như bản admin, callback dùng
  prefix riêng `ulchs_` (không trùng `lchs_` của Admin System — hai bot khác nhau, không chung
  whitelist).
- **`GW Gateway - Telegram`**: thêm `lichsu`/`timkiem` vào `COMMAND_MAP` (trước đó thiếu, nên gõ
  lệnh sẽ rơi vào route `unknown` — lỗi phát hiện lúc build tính năng này) và thêm prefix `ulchs_`
  vào whitelist callback của `GW-03 Router` để route đúng về `telebot_main`.
- Update `Nội dung lệnh help` của cả 2 bot (Admin System + ClickUp Reader) để liệt kê `/lichsu`
  và `/timkiem` với mô tả luồng bấm nút mới.
- Chưa test qua Telegram thật (như lần trước — Trigger không chạy được qua MCP); phần filter theo
  user đặc biệt cần test kỹ vì liên quan tới việc lộ dữ liệu chat của nhóm khác.

## 2026-09-09 (tiếp 13) — Ghi log tin nhắn nhóm + tóm tắt AI hàng đêm + `/lichsu` + `/timkiem`

Kiến trúc: tóm tắt AI tính **1 lần/ngày/nhóm** (không tính lại mỗi lần hỏi) để tiết kiệm chi phí —
lệnh xem lại chỉ đọc từ bảng đã tóm tắt sẵn; riêng tìm kiếm luôn quét tin nhắn GỐC để không mất
chi tiết. Đặt cả 2 lệnh ở `Telebot Admin System` (chỉ admin) vì đây là dữ liệu riêng tư của người
khác trong nhóm.

- **`GW Gateway - Telegram`**: thêm nhánh song song ghi MỌI tin nhắn trong nhóm/supergroup vào
  `gateway.group_chat_log` (không qua bước xác thực/phân quyền — ghi log thụ động). Mở rộng bảng
  thêm `message_thread_id`, `reply_to_message_id`, index full-text (`pg_trgm`) phục vụ tìm kiếm.
  **⚠️ Điều kiện tiên quyết CHƯA xác nhận**: bot Telegram cần TẮT Privacy Mode qua @BotFather
  (`/setprivacy` → Disable) mới nhận được tin nhắn thường trong nhóm (mặc định chỉ nhận lệnh `/...`).
- **Workflow mới `GW Daily Chat Summary`** (`ElSGQgdHPMtrzwME`): Schedule 1h sáng mỗi ngày — gộp tin
  nhắn hôm qua theo nhóm (SQL `string_agg`, không cần code node), tóm tắt bằng DeepSeek (đúng model
  đã chọn từ trước), upsert vào `gateway.daily_chat_summary`.
- **`Telebot Admin System`**: thêm `/lichsu` (không tham số → liệt kê nhóm có dữ liệu;
  `/lichsu <1|3|5|7>` → tóm tắt tất cả nhóm; `/lichsu <1|3|5|7> <chat_id>` → 1 nhóm cụ thể) và
  `/timkiem <chat_id> <từ khóa>` (tìm full-text trên tin nhắn gốc, tối đa 15 kết quả). Cập nhật
  `/help`.
- **Bug tự phát hiện + tự sửa ngay trong lúc build**: khi thêm 2 rule mới (`lichsu`, `timkiem`) vào
  `Switch` (đã có 14 rule từ trước), quên rewiring fallback — connection fallback CŨ vẫn dính vào
  output 14 (giờ là `lichsu`) cùng lúc với node xử lý `lichsu` thật, còn fallback THẬT (output 16)
  chưa được nối gì. Phát hiện qua bước đối chiếu `connections` bắt buộc sau khi sửa Switch (đúng quy
  trình RULES.md #13) — nếu bỏ qua bước này sẽ gây lỗi kép: `/lichsu` vừa chạy đúng vừa nhận thêm
  "❓ Lệnh không hợp lệ", còn lệnh sai thật thì im lặng không phản hồi.
- **CHƯA test thật** toàn bộ tính năng này qua Telegram (cần user tắt Privacy Mode trước, và không
  execute được Trigger qua MCP).

## 2026-09-09 (tiếp 12) — AI xoá nền (fallback) + Upscale cho `/xoanen`; dọn lại PROJECT_STATUS.md

- **Xác nhận Phương án A (DKPV/PVTC) đã được 1 phiên trước làm đúng và đang chạy tốt** — kiểm tra
  trực tiếp Postgres: khoá chính `clickup.task_links` đã là
  `(student_task_id, order_task_id, link_type, year)`, không còn lỗi duplicate key, 0 dòng trùng.
  Không cần sửa gì thêm.
- **Thêm tính năng AI xoá nền (fallback) + Upscale cho `/xoanen`** (`Bot Xử Lý Ảnh`,
  `6I4MnJiJCiv2JOIr`): sau khi remove.bg chạy (dù thành công hay thất bại), tin nhắn trả về giờ có
  3 nút: 🤖 Xoá nền bằng AI, 🔍 Upscale cho sắc nét, ❌ Huỷ. Đã tra giá + format API thật từ
  OpenRouter (`https://openrouter.ai/api/v1/images`, model `google/gemini-2.5-flash-image`,
  ~$0.0003/ảnh) — không đoán mù, đúng nguyên tắc đã áp dụng cho Mistral OCR trước đây. State tạm
  cho 2 nút follow-up lưu ở bảng mới `gateway.image_action_queue` (cùng lý do 64-byte callback_data
  như `clickup.upload_notify_queue`). Gateway thêm whitelist `imgai_`/`imgupscale_`/`imgcancel`.
  **⚠️ CẦN user tạo credential `httpTemplatedCustomAuth` cho OpenRouter và gán vào 2 node HTTP mới
  trước khi dùng được — chưa test thật.**
- **Dọn lại toàn bộ `PROJECT_STATUS.md`**: bỏ hết nội dung tường thuật lỗi thời tích luỹ qua nhiều
  phiên, chỉ giữ trạng thái hiện tại + 1 index tra nhanh trỏ tới các mục CHANGELOG liên quan. Chuyển
  phần "ghi nhớ kỹ thuật" trùng lặp sang tham chiếu thẳng `RULES.md` (đã có đủ, tránh 2 nguồn không
  đồng bộ).

## 2026-09-09 (tiếp 11) — Fix "Tên: —, Link: —" khi task chưa từng đồng bộ vào Postgres

Test thật ngay sau khi sửa dấu `=` (tiếp 10) lộ ra thêm 1 case: task `z9088279pb` gửi thông báo
"CẬP NHẬT Task" nhưng Tên và Link đều hiện "—". Nguyên nhân: task này **chưa từng được đồng bộ vào
`clickup.tasks`** (task mới tạo trên ClickUp, chưa qua lần `/sync`/Full Reconcile nào) — câu UPDATE
không khớp dòng nào (0 rows), node Postgres trả về item rỗng thay vì dữ liệu task thật.

Sửa `Build Thông Báo`:
- **Link ClickUp giờ LUÔN hiển thị đúng** dù task chưa có trong Postgres — vì URL ClickUp là
  deterministic (`https://app.clickup.com/t/<taskId>`), không cần tra DB mới dựng được.
- Tên hiện ghi rõ "(task chưa đồng bộ vào Postgres - sẽ có ở lần /sync tiếp theo)" thay vì "—" gây
  hiểu lầm là lỗi.

## 2026-09-09 (tiếp 10) — Fix ghi đè Postgres từ ClickUp Live Update (thiếu dấu `=`)

- **User xác nhận toàn bộ nút Upload OneDrive đã hoạt động đầy đủ** (nút chọn tên, nút forward,
  nút Hủy, menu chọn preset...).
- Sửa `SQL - ClickUp Live Update (Webhook)` → node "Ghi Đè Postgres": thêm dấu `=` vào đầu câu
  UPDATE (xem giải thích chi tiết trong CHANGELOG "tiếp 7" và hội thoại — thiếu dấu này khiến n8n
  không dịch `{{ $json.column }}` thành tên cột thật, gửi nguyên văn xuống Postgres và luôn lỗi cú
  pháp). Từ nay mỗi khi ai đổi custom field/trạng thái/tên task trực tiếp trên ClickUp, giá trị mới
  sẽ được ghi đúng ngược lại Postgres theo thời gian thực thay vì chỉ được cập nhật vào lần
  `/sync`/Full Reconcile tiếp theo.

## 2026-09-09 (tiếp 9) — Nút Hủy cho menu forward + workflow báo cáo lỗi hàng tuần mới

- Thêm nút ❌ Hủy vào menu forward (bên cạnh ❓ Trợ giúp) trên tin nhắn kết quả upload OneDrive.
- Xác nhận lại nút "🧾 Hóa đơn" (topic 6) đã đúng từ trước — không cần sửa.
- **Tính năng mới: lưu log lỗi + báo cáo hàng tuần để chạy Claude Code sửa.**
  - Bảng mới `gateway.error_logs` (`sql/06_gateway_error_logs.sql`) — workflow, node, message,
    execution_id/url, `status` ('open' mặc định, đánh dấu 'fixed'/'ignored' thủ công sau khi xử lý).
  - `GW Error Handler`: thêm node `Log Error To DB` (chạy song song với thông báo Telegram hiện có)
    ghi mọi lỗi từ MỌI workflow (workflow nào cũng nên gán `errorWorkflow` trỏ về đây) vào bảng trên.
  - **Workflow mới `GW Weekly Error Report`** (`ZJvP7L2aVPpeCGGW`) — Schedule Trigger mỗi Thứ 2,
    8h sáng → query `gateway.error_logs` (status='open', 7 ngày gần nhất) → tổng hợp theo workflow
    (số lượng lỗi, tối đa 3 lỗi/ workflow kèm link execution) → gửi riêng cho admin (không phải nhóm,
    vì đây là việc cần admin tự hành động: chạy Claude Code rà soát và sửa).
  - Xây bằng `create_workflow_from_code` (SDK) — như dự đoán, credential bị auto-gán SAI (Supabase
    Postgres, `@csfsintbot`) — đã sửa lại đúng (Postgres Docker, Telegram System Bot) ngay sau khi
    tạo, đúng như ghi chú kinh nghiệm cũ trong RULES.md.
  - **CHƯA test thật** (không execute được Schedule Trigger an toàn qua MCP mà không gửi tin nhắn
    thật cho admin) — cần đợi tới Thứ 2 tới, hoặc admin tự bấm "Execute workflow" thủ công trong n8n
    UI để xem trước.

## 2026-09-09 (tiếp 8) — Đối chiếu nút forward "Giấy tờ khác" + thêm mô tả vào `/help`

Kiểm tra lại theo báo cáo "thiếu mục gửi nhóm giấy khác": nút thứ 3 (`odfwd_<id>_3` → `od_giayto`,
topic 7, đúng nhóm/topic user gửi lại) **đã tồn tại và đúng cấu hình** — vấn đề thực sự là `/help`
(`Telebot ClickUp Reader`) chưa hề mô tả tính năng Upload OneDrive + forward, nên nhìn không rõ có
những lựa chọn nào. Đã sửa:
- Đổi nhãn `od_giayto` thành "📄 Giấy tờ khác" (đúng theo từ user dùng, rõ nghĩa hơn "Giấy tờ").
- Thêm mô tả đầy đủ luồng Upload OneDrive + 3 nút forward + nút Trợ giúp vào `/help`.

## 2026-09-09 (tiếp 7) — Định tuyến 3 loại thông báo hệ thống vào nhóm + topic riêng

Dùng chung bảng `gateway.notify_targets` đã tạo cho tính năng forward OneDrive (mở rộng bằng
INSERT, không sửa code) — thêm 4 dòng `category='system_notify'` cho nhóm `-1003647848349`:
`sys_clickup`(topic 2), `sys_schedule`(topic 6), `sys_error`(topic 4), `sys_catchall`(topic 1, DÙNG
CHO SAU — chưa có nguồn nào nối vào, giữ chỗ cho thông báo chưa phân loại trong tương lai).

- **`GW Error Handler`** (`34ccboHpyoY2r691`): "Báo admin Telegram" đổi từ nhắn riêng admin
  (`975005174`) sang gửi vào nhóm, topic 4 (lỗi hệ thống).
- **`SQL - ClickUp Live Update (Webhook)`** (`uqTqjtHYieotPZuc`): node "Notify" (thông báo cập nhật
  task) đổi sang nhóm, topic 2. **Phát hiện thêm (ngoài phạm vi hôm nay, đã tạo task riêng)**: node
  "Ghi Đè Postgres" trong workflow này thiếu dấu `=` ở đầu query — n8n không evaluate `{{ }}` bên
  trong, khả năng cao câu UPDATE ghi đè cột custom field/status/tên vào Postgres đang LUÔN LỖI. Chưa
  sửa (không thuộc yêu cầu hôm nay), đã note lại để làm riêng.
- **`SQL - Backup System (n8n + Postgres)`** (`iVtOA9LEtjpLDkln`): 4 node "Notify Backup ... Xong" —
  CHỈ đổi sang nhóm/topic 6 khi chạy TỰ ĐỘNG theo lịch (Schedule Chủ nhật 2h sáng) hoặc Manual Trigger
  test trong n8n (không có `notifyChatId` truyền vào); khi chạy THỦ CÔNG qua lệnh `/backup_n8n`/
  `/backup_db` (Admin System truyền `notifyChatId` rõ ràng) vẫn trả lời trực tiếp cho admin để có
  phản hồi tức thì. **Phát hiện thêm, đã sửa luôn (ảnh hưởng trực tiếp tới việc thông báo có gửi được
  hay không)**: cả 4 node này đang dùng nhầm credential "Telegram Dev Bot" (bot cũ, có thể không còn
  hoạt động) thay vì "Telegram System Bot" — đã đổi đúng.
- **`SQL - ClickUp Sync Scheduler`** (`loCm8Tg8Sqfj7ygy`): không có node Telegram nào tự gửi thông
  báo (chỉ gọi sang Full Reconcile) — không có gì cần sửa cho workflow này.

## 2026-09-09 (tiếp 6) — Chuẩn hóa tên file Upload OneDrive: tối đa 5 từ, không emoji/số/ký tự đặc biệt

- Thêm hàm `sanitizeFilenamePart()` (bỏ emoji, bỏ số, bỏ ký tự đặc biệt — chỉ giữ chữ cái có dấu và
  khoảng trắng — giới hạn tối đa 5 từ) áp dụng ở 2 nơi tạo tên file trong `Telebot ClickUp Reader`:
  - Chọn preset (BAV/Kammer/EZB/Schulbestätigung/Spateinstieg): áp dụng lên preset + tên học sinh
    GỘP LẠI (tổng tối đa 5 từ, không phải 5 từ riêng cho tên học sinh).
  - Nhập tên tùy chỉnh: áp dụng lên toàn bộ nội dung user gõ.
  - "📎 Giữ tên gốc" KHÔNG bị ảnh hưởng (giữ nguyên tên file gốc theo đúng ý nghĩa lựa chọn này).
  - Đuôi file (`.pdf`, `.png`...) được nối vào SAU khi làm sạch, không bị ảnh hưởng bởi bộ lọc.

## 2026-09-09 (tiếp 5) — Fix nút forward mất tích (batch rollback cũ), thêm nút ❌ Hủy cho menu admin

- **Nút forward sau upload (Kammer/BAV/Hóa đơn/Giấy tờ/Trợ giúp) không hiện**: cùng loại lỗi đã gặp
  trước đó trong phiên này — cập nhật `Send Upload Result` (thêm inlineKeyboard 4 nút) từng nằm
  chung 1 batch `update_workflow` với 1 operation sau đó bị lỗi (sai `sourceIndex`), khiến CẢ BATCH
  rollback — chỉ phần nối dây được làm lại sau đó, còn phần cập nhật node `Send Upload Result` thì
  quên làm lại. Xác nhận qua execution thật: tin nhắn gửi thành công nhưng hoàn toàn không có nút.
  Đã áp dụng lại đúng cấu hình 4 nút, publish.
  **Bài học lặp lại 2 lần trong 1 ngày**: khi 1 `update_workflow` nhiều operation báo lỗi giữa chừng,
  KHÔNG CHỈ redo phần operation bị lỗi — phải kiểm tra lại TOÀN BỘ operation trong batch đó (kể cả
  những operation đứng TRƯỚC operation lỗi) vì cả batch bị rollback cùng nhau.
- **Thêm nút ❌ Hủy vào menu "Thêm quyền"/"Xóa quyền"** (`Telebot Admin System`) — bấm vào gọi thẳng
  route `admin_cancel` (mới, output thứ 14 của `Switch (Admin Extras)`) → node `Reply Cancelled
  (Admin)` có sẵn từ `/cancel`. Đã đối chiếu `connections` sau khi thêm, xác nhận không còn node nào
  bị đứt kết nối trong cả 2 workflow (dùng đúng quy trình kiểm tra của skill `n8n-mcp-skills` mới
  kích hoạt).
- **Bắt đầu dùng bộ skill `n8n-mcp-skills`** (`using-n8n-mcp-skills` làm entry point) cho mọi việc
  xây dựng/kiểm tra workflow từ nay — lưu ý: bộ skill viết cho server n8n-mcp cộng đồng (tên tool
  `n8n_update_partial_workflow`, `get_node`...), khác với server đang dùng trong dự án này (tên tool
  `update_workflow`, `get_node_types`...) — áp dụng đúng NGUYÊN TẮC (tra schema trước khi cấu hình,
  luôn `get_workflow_details` đối chiếu `connections` sau khi sửa, hạn chế Code/Set node không cần
  thiết) bằng bộ tool thực tế, không gọi nhầm tên tool của skill.

## 2026-09-09 (tiếp 4) — `/cancel` cho Telebot Admin System + đúc kết nợ kỹ thuật (ARCHITECTURE.md §9)

- **Thêm `/cancel` cho `Telebot Admin System`** (bot riêng `@elite_n8n_system_bot`) — hiện chưa có
  state đa lượt thật ở bot này nên chỉ trả lời "không có gì để huỷ", giữ nhất quán UX với
  `Telebot ClickUp Reader` (đã có `/cancel` thật từ bản trước). `Bot Xử Lý Ảnh` và các sub-bot tương
  lai dùng chung vật lý bot Telegram với ClickUp Reader qua Gateway nên KHÔNG cần `/cancel` riêng.
- **Thêm `gateway.changelog` v9** ghi lại các việc trên + fix nút forward hôm nay.
- **Thêm mục 9 vào `ARCHITECTURE.md`** — đúc kết nợ kỹ thuật thực tế phát sinh qua nhiều phiên vá
  lỗi (bẫy inlineKeyboard động, sai tên field addConnection, whitelist callback hardcode, rủi ro 2
  phiên sửa song song...) kèm hướng refactor đề xuất cho từng mục — đọc trước khi làm refactor lớn.

## 2026-09-09 (tiếp 3) — Fix nút forward không phản hồi + auto-delete cho Reader + `/cancel`

- **Root cause nút forward (Kammer/BAV, Hóa đơn, Giấy tờ, Trợ giúp) hoàn toàn không phản hồi**: xác
  nhận qua execution — callback `odfwd_<id>_<id>`/`odhelp` KHÔNG lọt qua được whitelist route của
  Gateway (`GW-03 Router`), vì điều kiện cũ chỉ check `data.startsWith('od_')` — "odfwd_..." không
  bắt đầu bằng "od_" (ký tự thứ 3 là "f" không phải "_")! 0 execution nào được ghi nhận ở
  `Telebot ClickUp Reader` sau khi bấm nút — bug ở tầng Gateway, không phải ở workflow đích. Đã thêm
  `odfwd_`/`odhelp` vào whitelist.
- **Mở rộng tự xóa tin nhắn cũ sang `Telebot ClickUp Reader`**: mọi callback (chi tiết task qua nút,
  toàn bộ luồng Upload OneDrive, forward, trợ giúp) giờ tự xóa tin nhắn chứa nút vừa bấm trước khi xử
  lý tiếp — cùng pattern đã dùng ở `Telebot Admin System`.
- **Thêm `/cancel`** (+ nút ❌ Hủy trong menu chọn tên file OneDrive): xóa dòng
  `clickup.pending_uploads` đang dở cho chat đó, báo user có thể bắt đầu lại. Thêm `cancel` vào
  `COMMAND_MAP` (Gateway) để route đúng `telebot_main`.
- **CHƯA test qua Telegram** cả 3 việc trên trong phiên này.

## 2026-09-09 (tiếp 2) — Forward thông báo upload vào nhóm/topic + fix bug xóa tin nhắn

- **User xác nhận Upload OneDrive đã hoạt động đúng.**
- **Fix bug UX tự xóa tin nhắn cũ** (thêm hôm trước): sau khi xóa tin nhắn panel cũ, node xóa trả về
  response riêng của nó (không phải envelope gốc) khiến `$json.extraRoute` bị mất, làm rớt xuống
  nhánh flow cũ thay vì gửi panel tiếp theo — tin cũ mất nhưng tin mới không tới. Sửa bằng cách thêm
  node khôi phục lại envelope gốc (`$('Admin Extras Router').first().json`) ngay sau bước xóa.
- **Thêm forward thông báo upload vào nhóm/topic**: sau khi upload OneDrive thành công, tin nhắn kết
  quả có 4 nút tĩnh (Kammer/BAV, Hóa đơn, Giấy tờ, ❓ Trợ giúp) gửi bản copy thông báo vào đúng
  nhóm/topic. Bảng cấu hình mới `gateway.notify_targets` (mở rộng bằng INSERT, không cần sửa code)
  + bảng tạm `clickup.upload_notify_queue` (state ngắn hạn vì callback_data giới hạn 64 byte). Chi
  tiết + roadmap dùng chung bảng này cho định tuyến thông báo hệ thống: xem PROJECT_STATUS.md.
- SQL migration: `sql/04_gateway_notify_targets.sql`.

## 2026-09-09 (tiếp) — Fix Upload OneDrive (nút không hiện) + tự xóa panel cũ khi điều hướng admin

- **Root cause thật của "Upload OneDrive không phản hồi"**: xác nhận qua execution thật (đúng nghi
  phạm đã ghi ở CHANGELOG hôm trước) — `inlineKeyboard`/`replyMarkup` set bằng 1 expression động cho
  CẢ field (`={{ $json.telegramInlineKeyboard }}`) thay vì object tĩnh, khiến Telegram node âm thầm
  gửi tin nhắn KHÔNG có nút nào (không lỗi, không cảnh báo). Sửa bằng cách tách nhánh IF trước khi
  gửi (đúng số nút cố định ở mỗi nhánh): `Telebot ClickUp Reader` — `Beautify chi tiết`→`Telegram`
  (chi tiết task, 0 hoặc 1 nút) và `Build OD Menu`→`Send OD Menu` (menu chọn tên, 0 hoặc 4 hàng nút
  cố định: BAV/Kammer, EZB/Schulbestätigung, Spateinstieg, Tên tùy chỉnh/Giữ tên gốc).
- **Thêm UX tự xóa tin nhắn panel cũ khi điều hướng giữa các chức năng admin** (`Telebot Admin
  System`): mọi lần bấm nút (callback) trong luồng `/user_list`/duyệt user giờ tự xóa tin nhắn chứa
  nút vừa bấm (`Delete Old Panel Message`, dùng `callback.message_id` có sẵn) TRƯỚC khi gửi panel
  tiếp theo — đỡ tốn diện tích màn hình khi thao tác nhiều bước liên tiếp. Không áp dụng cho tin
  nhắn gõ tay (lệnh `/user_list`, `/version`...) vì không có tin nhắn nút nào để xóa.
- **CHƯA test thật qua Telegram** cả 2 việc trên — cần user xác nhận.

## 2026-09-09 — Fix panel gall/bl/dl bị lệch route, thêm `/version`, phát hiện lỗi tham số nối dây

- **Xung đột giữa 2 phiên chat chạy song song trên cùng workflow `Telebot Admin System`**: 1 phiên
  khác đã tự sửa lỗi routing `Switch (Admin Extras)` VÀ tự thêm 3 nút mới (⚡ Cấp tất cả quyền,
  ⛔ Block user, 🗑️ Xóa hoàn toàn — 13 output tổng cộng) trong lúc phiên này đang làm việc song song
  mà không biết. Phiên này vô tình ghi đè lại `rules` của `Switch (Admin Extras)` với 12 output cũ
  (thiếu route `delete_prompt`/`delete_confirm`), làm lệch khớp với 13 connection đã có sẵn. Đã phát
  hiện qua PROJECT_STATUS.md (đọc lại khi user cung cấp link) và sửa lại đúng 13 route khớp với
  node/connection thực tế đang tồn tại: `approve_user, deny_user, users_list, users_back,
  users_manage, grant_menu, revoke_menu, grant_confirm, revoke_confirm, grant_all, block_user,
  delete_prompt, delete_confirm`.
- **⚠️ Phát hiện kỹ thuật mới quan trọng**: tham số đúng cho `addConnection`/`removeConnection` qua
  n8n MCP là `sourceIndex`/`targetIndex`, KHÔNG PHẢI `sourceOutput`/`targetInput` — dùng sai tên bị
  ÂM THẦM bỏ qua (mặc định về index 0), không báo lỗi. Đây nhiều khả năng là nguyên nhân gốc của lỗi
  "connection dồn hết vào 1 output" đã từng gặp và tự tin fix trước đó. Xem `RULES.md` mục 13.
- **Thêm lệnh `/version`** (chỉ admin, gate qua `Check Admin (Version)`): đọc bảng mới
  `gateway.changelog` (SQL: `sql/03_gateway_changelog.sql`, seed sẵn v1-v8 theo mốc ngày thật), hiện
  phiên bản mới nhất + 6 thay đổi gần nhất + link sang `FEATURE_CATALOG.md` đầy đủ. Nối vào `Switch`
  chính (không đụng `Switch (Admin Extras)` đang nhạy cảm) để giảm rủi ro va chạm lần nữa.
- Cập nhật `/help` (Admin System): thêm mục `/user_list` và `/version`.
- Route thông báo duyệt user mới: Gateway giờ gửi qua `Telegram System Bot` (trước đó gửi nhầm qua
  `Elite Clickupbot`) — nút Approve/Deny được `Telebot Admin System` xử lý (không còn xử lý ở
  Gateway, vì callback giờ đến từ bot khác với bot nhận tin Gateway).
- **CHƯA làm trong phiên này** (backlog user yêu cầu, theo thứ tự): định tuyến 3 loại thông báo
  (cập nhật ClickUp / hệ thống-lịch / lỗi) vào 3 topic khác nhau trong group
  `https://t.me/c/3647848349/` (topic 2/6/4, group id `-1003647848349`); debug tiếp Upload OneDrive
  (vẫn chưa phản hồi khi bấm nút, xem đầu PROJECT_STATUS.md); form upload cần thêm lựa chọn
  "giữ tên gốc" / "tên tùy chỉnh" (có vẻ đã có trong bản build trước, cần xác nhận lại khi debug).

## 2026-09-08 (tiếp, cuối phiên) — /xoanen HOẠT ĐỘNG THẬT; /tomtat + cutover đang hoàn thiện
- **`/xoanen` xác nhận chạy được với ảnh Telegram thật** sau chuỗi debug live qua execution log:
  1. Node "Có Ảnh Không" lỗi kiểu dữ liệu — thiếu `singleValue: true` trong operator `array.exists`
     (so với bản gốc `Telebot_main.json`).
  2. `wrong file_id` — do vẫn dùng credential Telegram cũ sau khi cutover; **file_id của 1 bot
     KHÔNG dùng được với bot khác** — mọi node Get File trong sub-workflow phải cùng credential với
     bot Gateway đang nhận tin nhắn.
  3. **Bug build gốc nghiêm trọng nhất**: node "Gọi remove.bg API" chưa từng gửi ảnh thật — SDK n8n
     Workflow Builder không hỗ trợ khai báo `bodyParameters` kiểu `formBinaryData` qua type an toàn,
     nên lúc build ban đầu chỉ có tham số `size=auto`, thiếu hẳn `image_file`. Phải vá bằng
     `setNodeParameter` raw JSON sau khi tạo, đúng như cảnh báo tự đặt ra lúc build nhưng quên thực
     hiện — **bài học: LUÔN verify bằng 1 lần chạy thật ngay sau khi build node dùng SDK cho phần
     không có type hỗ trợ đầy đủ, đừng tin suông là đã thêm đủ tham số.**
  4. Credential `REMOVE.BG` ban đầu chứa API key sai/hết hạn — xác nhận độc lập bằng `curl` trực
     tiếp (không qua n8n) trước khi kết luận là lỗi key, không phải lỗi workflow.
  5. `parameterType: "formBinaryData"` không hiện trong TS type định nghĩa httpRequest v4.5 khi build
     qua SDK, nhưng node vẫn CHẤP NHẬN khi set qua raw `update_workflow` — xác nhận: SDK typing không
     đầy đủ = giới hạn của lớp SDK, không phải giới hạn thật của node.
  6. Đặt tên file kết quả rõ ràng `.png` (remove.bg trả PNG có alpha) thay vì tên mặc định không rõ
     định dạng.
- **`/tomtat` đang debug tiếp** — đã qua bug Telegram/credential, còn vướng:
  - `Gọi OCR.space API` báo `E572: Missing apikey` — do gán NHẦM dùng chung credential với
    `REMOVE.BG` lúc đầu (2 API key khác nhau, credential khác nhau).
  - Sau khi gán đúng credential `Spaceocr` (Simplified Custom Auth riêng) — đang chờ user xác nhận
    kết quả.
  - **User đã tự nâng cấp** node Vision từ Mistral-qua-OpenRouter sang **Mistral Cloud thật**
    (`mistral-ocr-latest` qua credential `mistralCloudApi` mới) — model chuyên OCR, giữ nguyên
    hướng đi này, không revert.
- **Cutover PROD bot (Giai đoạn 4) hoàn tất cho**: `GW_Gateway_Telegram.json` (11 node),
  `Telebot_ClickUp_Reader.json` (`USE_PROD_BOT=true` + 4 node), `Bot_Image_Processing.json`
  (7 node) — tất cả dùng `Elite Clickupbot` (`@Elite_clickup_bot`).
- **Bug phát sinh do người dùng thật (không phải admin) nhắn bot PROD lần đầu**: node
  "Không có quyền bot này" crash với `can't find end of the entity` — `bot_key` như `telebot_main`
  (có dấu `_`) bị hiểu nhầm là markup Markdown khi thiếu `parse_mode` tường minh. Đã fix bằng cách
  set rõ `parse_mode: HTML`. **Bài học: MỌI node Telegram chèn giá trị động vào text đều nên set
  `parse_mode` tường minh, không dựa vào default ngầm định.**
- **Vấn đề vận hành phát hiện thêm**: `update_workflow` qua MCP có thể bị **user tự lưu đè lại** nếu
  họ mở workflow trong UI trước khi bản publish của Claude kịp áp dụng (credential Telegram bị quay
  lại giá trị cũ 2 lần trong phiên này) — khi nghi ngờ 1 fix "biến mất", kiểm tra lại
  `get_workflow_details` trước khi debug tiếp theo hướng khác.
- **Format `/task chitiet_<id>` v3**: link giờ hiển thị **2 lớp** — tiêu đề in đậm bọc `<a href>`
  (bấm mở link) + dòng dưới bọc `<code>` (chạm copy nguyên văn URL), đồng bộ cho cả
  `Telebot_ClickUp_Reader.json` và `Telebot_Admin_System.json`.

## 2026-09-08 (tiếp, hết phiên) — /tomtat hoàn tất, đổi sang Mistral OCR native
- **OCR.space đã hoạt động** — lỗi `Missing apikey` trước đó do Auth Template của credential
  `Spaceocr` dùng nhầm header `X-Api-Key` (của remove.bg) thay vì đúng header `apikey` của
  OCR.space. Đã sửa, xác nhận qua `curl` độc lập trước khi kết luận.
- **Đổi kiến trúc nhánh Vision theo yêu cầu user** (chỉ cần OCR thuần bằng Mistral, không cần mô
  tả bối cảnh, và dùng đúng node/API dành cho OCR để tận dụng gói free của Mistral thay vì gọi qua
  Chat Completion):
  - Thay thế `Mô Tả Ảnh Bằng AI (Vision)` (`chainLlm` + subnode `Mistral Cloud Chat Model` qua
    LangChain) bằng node gốc **`n8n-nodes-base.mistralAi`** (resource `document`, operation
    `extractText`) — gọi thẳng OCR endpoint của Mistral (`mistral-ocr-latest`), không qua lớp
    Chat Completion/LangChain — đơn giản hơn, đúng mục đích, tận dụng pricing/free-tier riêng của
    OCR endpoint.
  - Đã tra cứu **response schema thật** từ tài liệu Mistral OCR chính thức trước khi build:
    `{ pages: [{ markdown: "...", ... }], model, usage_info }` — field text nằm ở
    `pages[0].markdown`, KHÔNG phải `text` như chainLlm cũ. Sửa lại prompt tổng hợp cuối cho khớp.
  - Dọn 1 node `Extract text` (cùng loại, do user tự thêm thử nghiệm) bị orphan chưa nối dây.
- **Kết quả**: cả `/xoanen` và `/tomtat` đã xác nhận chạy được với ảnh Telegram thật, đã publish.
  Còn cần 1 lần test cuối để xác nhận field `pages[0].markdown` đúng như tài liệu (build dựa trên
  tài liệu chính thức, CHƯA tự chạy thử được vì trigger không hỗ trợ gọi trực tiếp qua MCP).
- User ghi nhận Mistral Cloud (Vision) chạy khá chậm — nếu cần tối ưu tốc độ thêm, cân nhắc bỏ bớt
  1 trong 2 nguồn OCR song song (OCR.space hoặc Mistral) thay vì chạy cả 2 — cần hỏi ý kiến user
  trước khi đổi, không tự quyết.

## 2026-09-08 (tiếp) — CUTOVER sang bot PROD (Giai đoạn 4) + fix format /task
- **Cutover chính thức theo `GO_LIVE_CHECKLIST.md`**: đổi bot DEV (`@elite_n8n_test_bot`) sang PROD
  (`@Elite_clickup_bot`) cho `GW_Gateway_Telegram.json` (11 node: Trigger + 10 reply/notify),
  `Telebot_ClickUp_Reader.json` (`USE_PROD_BOT=true` + 4 node Telegram), và `Bot_Image_Processing.json`
  (7 node, mới thêm hôm nay nên không có sẵn trong checklist gốc — đã bổ sung tương tự).
  `Telebot_Admin_System.json` KHÔNG đổi (dùng System Bot cố định theo RULES.md #9).
- **Bug nghiêm trọng phát hiện + đã sửa**: TOÀN BỘ node Telegram reply trong
  `Telebot_ClickUp_Reader.json` trước đó dùng NHẦM credential "Telegram System Bot" thay vì bot Gateway
  thật đang nhận tin nhắn — khiến câu trả lời `/task` luôn gửi sang MỘT BOT KHÁC với bot user vừa nhắn
  (dễ hiểu nhầm là "bot không phản hồi"). Đã sửa toàn bộ 4 node.
- **Bài học mới quan trọng nhất phiên này — ghi vào `RULES.md` #12**: `update_workflow` qua MCP trên
  1 workflow đang **active** chỉ tạo bản NHÁP, KHÔNG tự áp dụng vào bản đang chạy thật
  (`activeVersionId`) cho tới khi gọi `publish_workflow`. Đã sửa xong tính năng `/xoanen`/`/tomtat`
  gắn Gateway từ sáng nhưng **CHƯA TỪNG hoạt động thật** vì quên publish cả Gateway lẫn
  ClickUp Reader — user test nhiều lần vẫn ra kết quả cũ. Từ giờ: LUÔN publish ngay sau update trên
  workflow active.
- **Format `/task chitiet_<id>` — redesign theo yêu cầu user**:
  - Thêm `youtube_link` (cột đã có sẵn trong DB, trước đó chưa từng được đọc).
  - Mỗi field: nhãn in đậm + xuống dòng riêng (dễ phân biệt), không còn ký tự cây `├└│`.
  - Thứ tự mới: Mô tả → Trạng thái → List → Phụ trách → **Youtube → OneDrive → ClickUp** → Đăng ký
    phỏng vấn (DKPV) → Phỏng vấn thành công (PVTC).
  - Mỗi link hiển thị **2 dòng**: tiêu đề in đậm bọc `<a href>` (bấm để MỞ link) + dòng dưới bọc
    `<code>` (chạm để COPY nguyên văn URL) — giải quyết yêu cầu "copy được plain text của link".
  - Thêm fallback tự cắt bớt nếu vượt giới hạn 4096 ký tự của Telegram (cắt theo block hoàn chỉnh,
    không cắt giữa dòng để tránh vỡ thẻ HTML). Áp dụng cho cả `Beautify chi tiết` và `Beautify full`.
  - Đồng bộ y hệt cho cả `Telebot_ClickUp_Reader.json` (qua Gateway) và
    `Telebot_Admin_System.json` (bot Admin riêng).
- **Xác nhận header xác thực thật** (đọc tài liệu chính thức, không đoán): remove.bg dùng
  `X-Api-Key`, OCR.space dùng `apikey` — khớp đúng cấu hình node đã build trước đó.

## 2026-09-08 (tiếp) — Backup Credential + Config (mã hóa), subagent, restore tool
- Thêm nhánh **backup Credential thật** (decrypted) vào `SQL_Backup_System.json`: export qua
  `n8n export:credentials --all --decrypted`, mã hóa AES-256-CBC bằng `openssl` + passphrase
  lưu tại `/root/.n8n_backup_passphrase` (chmod 600, KHÔNG nằm trong workflow/GitHub) trước khi
  rời VPS, xóa plaintext ngay trong cùng 1 lệnh. User tự paste 6 node vào canvas (thao tác này bị
  auto-mode classifier chặn khi Claude thử tự làm qua MCP — hợp lý vì tự động hóa export secret
  thật là hành động nhạy cảm, cần user xác nhận qua thao tác thủ công).
- Thêm nhánh **backup Config** (docker-compose.yml của 3 stack: n8n_stack, fachkraft_db,
  portainer) — cùng cơ chế mã hóa AES-256, dùng chung passphrase với Credential backup. Lý do:
  phát hiện các file compose này (định nghĩa container/network/port) KHÔNG được backup ở đâu cả
  trước đây — nếu VPS sập, chỉ có SQL/workflow/credential vẫn không đủ để dựng lại đúng stack.
- `Config` backupType giờ hỗ trợ 4 giá trị: `n8n` | `db` | `credential` | `config` | `both`
  (`both` = chạy tất cả).
- Viết `restore.sh` — script khôi phục Postgres + Credentials (giải mã) + Workflows sau khi VPS
  sập, chạy trên VPS mới đã dựng lại đúng docker-compose. **CHƯA test thật trên production** (rủi
  ro tạo trùng lặp dữ liệu) — cần test trên 1 n8n instance rỗng trước khi tin dùng.
- **Nghi vấn cần điều tra**: file backup n8n workflow (`Upload Backup N8N (OneDrive)`) có dấu hiệu
  vẫn giữ tên cũ `file.json` thay vì `n8n_backup_YYYY-MM-DD.json` trên OneDrive dù tham số
  `fileName` đã set đúng (nhánh DB backup vẫn đặt tên đúng bình thường) — có thể do OneDrive node
  match theo item ID cũ (đã có sẵn 1 file tên `file.json` trong folder từ lần test rất sớm) thay
  vì tạo mới theo tên — CHƯA xác nhận nguyên nhân, cần kiểm tra lại khi rảnh.
- Tạo subagent Claude Code `n8n-vps-ops` (`~/.claude/agents/n8n-vps-ops.md`) — gom kiến thức hạ
  tầng (container name, credential ID, passphrase path, quy tắc an toàn) để phiên chat sau không
  cần đọc lại toàn bộ lịch sử debug.

## 2026-09-08 (tiếp) — Bot Xử Lý Ảnh mới: /xoanen + /tomtat (gắn Gateway)
- **`Bot_Image_Processing.json`** (19 node, sub-workflow mới, gắn qua Gateway giống Telebot ClickUp
  Reader/Help Bot/Crawl Bot):
  - `/xoanen`: Telegram Get File → **remove.bg API** (xóa nền) → gửi lại document (giữ alpha
    transparency, không dùng sendPhoto vì Telegram nén JPEG mất nền trong suốt).
  - `/tomtat`: OCR **CẢ 2 nguồn song song** — OCR.space (text-based OCR qua base64) VÀ Mistral
    Vision (`mistralai/pixtral-12b` qua OpenRouter, đọc ảnh trực tiếp qua `chainLlm` với
    `messageType: imageBinary`) — gộp bằng node Merge (combine by position) — AI tổng hợp
    (`mistralai/mistral-small-3.2-24b-instruct` qua OpenRouter) đối chiếu cả 2 nguồn, ưu tiên
    nguồn rõ ràng hơn nếu mâu thuẫn, xuất ra tiếng Việt có emoji + xuống dòng + cú pháp Markdown
    Telegram thật (`*đậm*`, `_nghiêng_`) — gửi với `parse_mode: Markdown` để render đúng định dạng.
- **Gateway (`GW_Gateway_Telegram.json`)**: thêm node `→ Sub: Image Bot`, case `image_bot` trong
  switch `Route bot?` (output index 5), `COMMAND_MAP` thêm `xoanen`/`tomtat` → `image_bot`,
  `AVAILABLE_BOTS` thêm `image_bot`. Đã update `gateway.config.available_bots` (DB) tương ứng và
  cấp quyền `image_bot` cho admin để test.
- **Build bằng n8n Workflow SDK** (`create_workflow_from_code` qua MCP) cho phần khung, sau đó
  dùng `update_workflow` (raw node/connection ops) để thêm nhánh Vision song song — SDK không có
  cú pháp xác nhận rõ ràng cho fan-out 1 node ra nhiều nhánh song song trong cùng 1 câu lệnh, nên
  dùng addConnection nhiều lần (đã proven từ SQL_Backup_System) để nối 1 nguồn ra nhiều đích an toàn.
- **Lỗi đã gặp khi build**: `autoAssignedCredentials` của `create_workflow_from_code` gán NHẦM
  credential Telegram (`@csfsintbot` thay vì `Telegram Dev Bot` — bot thật Gateway đang dùng) —
  phải kiểm tra + sửa lại bằng `setNodeCredential` cho từng node Telegram ngay sau khi tạo. Bài
  học: luôn xác nhận credential thật bằng cách đọc trực tiếp `get_workflow_details` của Gateway
  live, không tin auto-assign theo tên gần giống.
- **Cần user tự làm sau khi đọc file này**: tạo 2 credential mới trong n8n (`remove.bg API`,
  `OCR.space API`, cả 2 dạng httpTemplatedCustomAuth) — có API key thật nên không thể tự động
  hóa qua MCP; nên tạo key MỚI thay vì dùng lại key cũ đã lộ công khai trong
  `original/Telebot_main.json` (remove.bg) và `original/Elite_Crawl_Bot.json` (OCR.space).

## 2026-09-08 — Backup Postgres qua SSH thật (Phase 3 DB backup) HOÀN TẤT
- **`SQL_Backup_System.json`**: nhánh backup DB đổi từ 3 node Postgres SELECT (tasks/task_links/
  sync_targets, gộp JSON) sang **pg_dump SQL thật** qua 4 node SSH mới:
  `SSH - Dump Postgres (docker exec)` → `SSH - Copy File Ra Host` → `SSH - Tải File Về n8n`
  (operation Download, trả binary) → nhánh song song `SSH - Dọn File Tạm (Host + Container)`.
  Đã test executeWorkflow qua MCP nhiều lần tới khi `status: success` toàn bộ, file `.sql` 3MB
  lên đúng OneDrive, Telegram báo đúng link.
- **Xác nhận credential Postgres thật**: `-U n8n -d n8n` (role `postgres` KHÔNG tồn tại, thông tin
  cũ trong memory dự án sai) — 2 schema cần backup là `clickup` và `gateway`.
- **3 lỗi thực tế gặp khi build node SSH — ghi lại để tránh lặp lại:**
  1. Key SSH dạng **ED25519 (OpenSSH format mới)** báo `Cannot parse privateKey: Unsupported key
     format` trong credential SSH của n8n (thư viện `ssh2` không đọc được) — phải dùng
     **RSA 4096-bit, định dạng PEM** (`ssh-keygen -t rsa -b 4096 -m PEM`).
  2. **Tham số `command`/`path` của node SSH bắt buộc phải có dấu `=` ở đầu chuỗi** thì n8n mới
     coi `{{ }}` là expression — thiếu dấu `=` khiến n8n gửi literal `{{ new Date()... }}` xuống
     shell, gây `syntax error` (Execute) hoặc `No such file` (Download). Đã xác nhận bằng
     `get_workflow_execution` qua MCP, không đoán.
  3. Node SSH Download đọc file trên **host** (qua SFTP), KHÔNG đọc được file bên trong container
     Docker — phải có bước `docker cp` ra host trước, không thể gộp 2 bước.
- **Sửa thêm lỗi có sẵn từ trước** (phát hiện khi debug): cả 2 node Notify (`Notify Backup N8N
  Xong`, `Notify Backup DB Xong`) đọc field `$json.webViewLink` (tên field cũ thời còn dùng Google
  Drive) — OneDrive trả về field tên `webUrl`, khiến Telegram luôn báo `🔗 undefined`. Đã sửa cả 2.
- Dùng MCP n8n (search_workflows/get_workflow_details/update_workflow/execute_workflow/
  get_workflow_execution) để tự sửa + tự test trực tiếp trên n8n live, không cần user copy/paste
  qua UI — nên có thể dùng cách này cho các lần debug workflow sau nếu MCP còn khả dụng.

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
