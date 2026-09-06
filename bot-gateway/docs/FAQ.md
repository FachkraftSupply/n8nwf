# FAQ — Lỗi thường gặp & Cách đã sửa (tra cứu nhanh)

Ghi lại các lỗi ĐÃ GẶP THẬT trong quá trình build, để không mất thời gian debug lại lần 2.
Xem `CHANGELOG.md` để biết ngày tháng chính xác nếu cần thêm chi tiết.

---

## 🤖 Nhóm lỗi: Nhầm Bot Telegram

### "Bấm link chỉ hiện chữ 'start' trơ trọi, không có nội dung gì"
**Nguyên nhân:** Deep-link (`https://t.me/<bot>?start=...`) đang trỏ SAI bot — ví dụ trỏ tới bot PROD
(`@Elite_clickup_bot`) trong khi Gateway đang lắng nghe trên bot DEV (`@elite_n8n_test_bot`). Bot bị
trỏ nhầm không xử lý gì với lệnh `/start ...` đó nên chỉ hiện mỗi "start".
**Cách sửa:** Kiểm tra biến `botUsername` trong node `⚙️ Config` của `Telebot_ClickUp_Reader.json` —
phụ thuộc `USE_PROD_BOT` (true/false). Đảm bảo khớp đúng bot Gateway đang chạy.

### "Gõ lệnh không thấy phản hồi gì cả, hoặc phản hồi từ bot lạ"
**Nguyên nhân:** Đang gõ lệnh trên **sai bot**. Dự án có 3 bot khác nhau, chỉ 1 bot có Gateway lắng nghe
lệnh tại 1 thời điểm:
| Bot | Vai trò | Gõ lệnh admin ở đây? |
|---|---|---|
| `@elite_n8n_test_bot` (DEV) | Gateway đang chạy — TẤT CẢ lệnh admin (`/task`, `/sync`, `/sync_status`...) | ✅ Đúng |
| `@Elite_clickup_bot` (PROD) | Gateway sẽ chuyển sang đây ở Giai đoạn 4 cutover, CHƯA active | ❌ Chưa dùng |
| `@elite_n8n_system_bot` (System) | CHỈ gửi thông báo nền 1 chiều (SQL sync) — không có Trigger nhận lệnh | ❌ Không bao giờ |
**Cách sửa:** Luôn thao tác admin trên `@elite_n8n_test_bot` cho tới khi go-live.

### "Gõ lệnh đúng trên bot DEV, có phản hồi, nhưng phản hồi lại xuất hiện ở bot System"
**Biến thể khác của lỗi nhầm bot** — lần này KHÔNG phải do Trigger sai, mà do **1 node reply cụ thể**
(callback/thông báo) trong workflow vẫn còn để credential Telegram của `@elite_n8n_system_bot` thay vì
bot DEV Gateway đang lắng nghe. Gateway trigger đúng bot, nhưng node TRẢ LỜI lại dùng nhầm credential.
**Cách sửa:** Không chỉ kiểm tra credential của node Trigger — phải rà **TỪNG node Telegram reply**
trong toàn bộ luồng (đặc biệt các node mới thêm/copy từ chỗ khác), xác nhận `result.from.username` khi
test đúng là bot đang mong đợi. Không giả định "sửa Trigger là đủ".

### "Bấm nút inline keyboard không có phản ứng gì"
**Nguyên nhân:** Gateway (trước khi fix) route TOÀN BỘ callback (bấm nút) vào luồng duyệt user riêng
(`ap:`/`dn:`), không có đường chung sang sub-workflow như message thường.
**Cách sửa đã áp dụng:** Chuyển hẳn `/sync` từ inline keyboard sang **deep-link dạng text** (giống
`chitiet_`) — né hẳn vấn đề callback routing, ổn định hơn. Nếu sau này cần dùng lại inline keyboard,
nhớ đã có node `Là Callback Duyệt User?` trong Gateway để rẽ nhánh đúng.

---

## 🔀 Nhóm lỗi: Gateway không nhận diện lệnh mới

### "Lệnh mới báo 'Lệnh không hợp lệ' với danh sách lệnh lạ (/task /ask /sum)"
**Nguyên nhân:** Gateway có `COMMAND_MAP` RIÊNG (trong node `⚙️ Config` của `GW_Gateway_Telegram.json`)
— không tự động biết về lệnh mới thêm vào sub-workflow. Message "Lệnh không hợp lệ" đó ĐẾN TỪ GATEWAY,
không phải từ sub-workflow.
**Cách sửa:** Mở `GW_Gateway_Telegram.json` → node `⚙️ Config` → thêm lệnh mới vào `COMMAND_MAP`, trỏ
tới đúng `bot_key` (thường là `telebot_main`). **⚠️ Đây là bước BẮT BUỘC mỗi khi thêm lệnh mới** — xem
quy tắc đầu `PROJECT_STATUS.md`.

---

## 🔍 Nhóm lỗi: Tìm kiếm Postgres

### "Postgres có dữ liệu đúng nhưng bot báo không tìm thấy kết quả"
2 nguyên nhân độc lập từng gặp:
1. `queryReplacement` để giá trị đơn `={{ $json.x }}` thay vì **mảng** `={{ [$json.x] }}` — Postgres
   node của n8n LUÔN cần mảng dù chỉ 1 tham số `$1`.
2. Code chấm điểm đọc field (`searchKeywords`) từ item **đã bị Postgres node phía trước ghi đè mất**
   — Postgres node luôn thay `$json` bằng kết quả SQL thuần, xoá hết field khác đã gắn trước đó.
**Cách sửa:** Luôn dùng mảng cho `queryReplacement`. Nếu cần dữ liệu từ node TRƯỚC Postgres, tham chiếu
qua `$('Tên Node').first().json...`, không dùng `$json` sau khi qua Postgres node.

---

## 📨 Nhóm lỗi: Gửi tin nhắn Telegram

### "Bad Request: can't parse entities" khi gửi tin nhắn HTML
**Nguyên nhân:** Nội dung động (tên task, mô tả...) chứa ký tự `<`, `>`, `&` THẬT (ví dụ mô tả có chữ
`<b>` là text người dùng gõ, không phải định dạng) — Telegram cố hiểu nhầm thành thẻ HTML thật.
**Cách sửa:** Luôn `escapeHtml()` mọi nội dung ĐỘNG trước khi chèn vào tin nhắn `parse_mode: HTML`.

### "Bad Request: chat_id is empty"
**Nguyên nhân:** `notifyChatId` để trống trong Config, và node gửi thông báo chạy TRƯỚC KHI kịp query
`admin_chat_id` từ Postgres (query đó chạy gần cuối workflow).
**Cách sửa:** Hardcode `ADMIN_CHAT_ID` trực tiếp trong Config (không phụ thuộc query Postgres nữa) —
đã áp dụng ở cả 3 workflow (Full Reconcile, Live Update, Telebot Reader).

---

## 🧩 Nhóm lỗi: Code node & node bị "im lặng" không chạy

### "Node chỉ xử lý được 1 item dù đầu vào có nhiều item"
**Nguyên nhân:** Code node mặc định chạy "Run Once for All Items" nhưng code viết theo kiểu xử lý
từng item (`$json`, `return {json:{...}}`).
**Cách sửa:** Set `"mode": "runOnceForEachItem"` trong parameters của Code node, hoặc đổi trong UI
(góc trên bên phải node).

### "Multiple matches" khi dùng `.item` hoặc `itemMatching()`
**Nguyên nhân:** Node native (đặc biệt ClickUp community node) không set `pairedItem` chuẩn khi 1 input
item "biến mất" khỏi output (ví dụ task không có comment).
**Cách sửa:** Dùng `itemMatching(idx)` thay vì `.item`, bọc `try/catch` để bỏ qua an toàn nếu không xác
định được — hoặc tốt hơn, thiết kế lại để không cần khớp ngược pairedItem (đọc lại từ node gốc qua tên).

### "Node bị bỏ qua hoàn toàn, không thấy chạy trong Execution"
**Nguyên nhân:** n8n mặc định BỎ QUA (skip) 1 node nếu nó nhận 0 item đầu vào — kể cả node tiếp theo
sau đó cũng bị ảnh hưởng dây chuyền.
**Cách sửa:** Set `"alwaysOutputData": true` cho node đó — ép nó luôn chạy và trả về ít nhất 1 item
(rỗng/placeholder) thay vì bị bỏ qua.

---

## 🔧 Nhóm lỗi: Format tham số ClickUp node

### "Node ClickUp native báo lỗi tham số / không tìm thấy Space-Folder-List"
**Nguyên nhân:** Node ClickUp trên n8n instance này dùng **THAM SỐ PHẲNG** (`team: "9018351620"`),
KHÔNG PHẢI kiểu resource-locator hiện đại (`{__rl:true, value, mode}`) như nhiều node n8n khác.
**Cách sửa:** Copy đúng format từ ví dụ đã xác nhận chạy tốt (`original/Telebot_sql.json`, node
"lay task"/"lay comment1"):
```js
// ĐÚNG:
{ team: "9018351620", space: "90183192291", folderless: true, list: "={{ $json.id }}" }
// SAI (đừng copy từ node n8n khác, hầu hết đều dùng resource-locator):
{ team: { "__rl": true, "value": "...", "mode": "id" } }
```

---

## 📌 Ghi chú chung
- `gateway.config` là bảng key-value (`key`, `value`) — không có cột riêng cho từng key.
- ClickUp Task ID hiện là dạng chữ+số (vd `z908826jhz`) — luôn để cột `id` trong Postgres kiểu `TEXT`.
- Deep-link Telegram (`?start=...`) CHỈ cho phép ký tự `[A-Za-z0-9_-]`, không được dùng dấu `:`.


### "chatId/message_id ra rỗng dù đã truyền từ Trigger xuống" (dùng `$json` trần)
**Nguyên nhân:** `$json` trong 1 node LUÔN chỉ lấy từ output của node NỐI TRỰC TIẾP ngay trước nó —
không đảm bảo field cần thiết (vd `chat_id`) có mặt, kể cả khi field đó "chắc chắn" có ở đâu đó phía
trên trong chuỗi xử lý. Đây là lỗi dễ mắc phải nhất khi copy node hoặc thêm field mới vào giữa chuỗi.
**Cách sửa:** KHÔNG BAO GIỜ dùng `{{ $json.x }}` cho dữ liệu quan trọng (chatId, message_id...) — luôn
tham chiếu tường minh qua tên node đã xác nhận có field đó: `{{ $('GW-01 Envelope').first().json.chat_id }}`
hoặc `{{ $('Phân tích lệnh').first().json.chatId }}`. Quy tắc này ĐÃ có trong dự án (memory: "Postgres
nodes overwrite $json...") nhưng cần áp dụng CHUNG cho MỌI loại node, không riêng Postgres.
