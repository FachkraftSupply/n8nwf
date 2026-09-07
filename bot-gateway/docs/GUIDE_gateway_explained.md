# GIẢI THÍCH CHI TIẾT — `GW_Gateway_Telegram.json` (Gateway)

> Dành cho người MỚI BẮT ĐẦU học lập trình — mỗi khái niệm code lạ (array, object, hàm, toán tử...)
> đều được giải thích ngắn gọn ngay khi xuất hiện lần đầu.

## Gateway là gì, tại sao cần?

Gateway là "cổng gác cửa" duy nhất nhận TẤT CẢ tin nhắn Telegram gửi tới bot DEV/PROD, rồi quyết định
chuyển tin nhắn đó sang ĐÚNG sub-workflow nào xử lý (tìm task, hỏi AI, tóm tắt...) — giống như tổng
đài điện thoại: khách gọi tới 1 số, tổng đài nghe rồi CHUYỂN MÁY sang đúng phòng ban cần thiết. Không
có Gateway, mỗi bot sẽ phải tự viết logic phân quyền/định tuyến riêng, trùng lặp code rất nhiều.

## Node `GW-01 Envelope` (Code)

**Vấn đề:** Telegram gửi dữ liệu (gọi là "update") với CẤU TRÚC KHÁC NHAU tuỳ loại sự kiện — tin nhắn
thường có `message.text`, `message.chat.id`; còn khi user BẤM NÚT (callback) thì lại là
`callback_query.data`, `callback_query.message.chat.id` — 2 đường dẫn dữ liệu hoàn toàn khác nhau.
Nếu mọi node phía sau đều phải tự kiểm tra "đây là tin nhắn hay callback?" thì code sẽ lặp lại rất
nhiều, dễ sai sót.

**Ý tưởng giải quyết:** "Dịch" cả 2 loại update về CÙNG 1 CẤU TRÚC DUY NHẤT (gọi là "Envelope" - tức
"phong bì", đóng gói thống nhất) — các node phía sau chỉ cần đọc từ Envelope, không cần quan tâm dữ
liệu gốc phức tạp thế nào.

**Cách làm thực tế:**
```js
const upd = $('Telegram Trigger Gateway').first().json;
const reqId = `req_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

let kind, m = null, user, chat, text = '', callback = null;

if (upd.callback_query) {
  kind = 'callback';
  const cq = upd.callback_query;
  user = cq.from;
  chat = cq.message.chat;
  callback = { id: cq.id, data: cq.data || '', message_id: cq.message.message_id };
  text = cq.data || '';
} else {
  m = upd.message || upd.edited_message;
  if (!m) return [];
  kind = 'message';
  user = m.from;
  chat = m.chat;
  text = m.text || m.caption || '';
}

const command = (text.match(/^\/(\w+)/) || [])[1] || null;

return [{ json: {
  request_id: reqId, platform: 'telegram', kind,
  user_id: String(user.id), username: user.username || '',
  display_name: [user.first_name, user.last_name].filter(Boolean).join(' '),
  chat_id: String(chat.id), message_id: m ? m.message_id : (callback ? callback.message_id : null),
  text, command, callback,
  has_media: !!(m && (m.photo || m.document || m.video)),
  ts: new Date().toISOString(), raw: upd
}}];
```
Giải thích từng phần (cho người mới):
- **`const`**: khai báo 1 biến (ô nhớ đặt tên) mà giá trị KHÔNG đổi sau khi gán — dùng `const` thay vì
  `let` khi chắc chắn không cần gán lại, giúp code an toàn hơn (lỡ tay sửa nhầm sẽ báo lỗi ngay).
- **`` `req_${Date.now()}_...` ``**: đây là "template string" (chuỗi mẫu) — dấu `` ` `` (backtick) cho
  phép nhúng biến trực tiếp vào chuỗi bằng `${...}`, không cần nối chuỗi bằng dấu `+` như cách cũ.
  `Date.now()` trả về số mili-giây hiện tại (dùng làm 1 phần của "mã định danh" để phân biệt request
  này với request khác).
- **`let kind, m = null, ...`**: khai báo NHIỀU biến cùng lúc, cách nhau dấu phẩy — khác `const`, dùng
  `let` vì các biến này sẽ được GÁN GIÁ TRỊ THẬT ở dưới, tuỳ vào loại update.
- **`if (upd.callback_query) { ... } else { ... }`**: cấu trúc RẼ NHÁNH — "nếu update này CÓ trường
  `callback_query` thì làm khối lệnh A, KHÔNG THÌ làm khối lệnh B". Đây chính là chỗ "dịch" 2 loại dữ
  liệu khác nhau về cùng 1 dạng.
- **`if (!m) return [];`**: dấu `!` là PHỦ ĐỊNH — `!m` nghĩa là "nếu `m` KHÔNG có giá trị" (null/rỗng).
  `return [];` — trả về 1 MẢNG RỖNG (không có item nào), làm node này "im lặng" không tạo ra dữ liệu gì
  nếu gặp loại update lạ không phải tin nhắn/callback (ví dụ Telegram gửi sự kiện khác không cần xử lý).
- **`text.match(/^\/(\w+)/)`**: đây là REGEX (biểu thức chính quy — công cụ tìm mẫu trong chuỗi text).
  `/^\/(\w+)/` nghĩa là: "bắt đầu chuỗi (`^`) là dấu `/`, theo sau là 1 hoặc nhiều ký tự chữ/số
  (`\w+`, được NGOẶC lại để lấy ra riêng)". Ví dụ với text `/task linh nhi`, regex này khớp
  `/task`, lấy ra được `task`.
- **`(text.match(...) || [])[1] || null`**: `match()` trả về MẢNG kết quả nếu khớp, hoặc `null` nếu
  KHÔNG khớp. `|| []` là "nếu kết quả là null thì dùng mảng rỗng thay thế" — để đoạn `[1]` phía sau
  (lấy phần tử thứ 2 trong mảng — chỉ số bắt đầu từ 0, nên `[1]` là phần tử THỨ HAI, chính là phần chữ
  trong ngoặc của regex) không bị lỗi "không đọc được thuộc tính của null".
- **`String(user.id)`**: ép kiểu dữ liệu — `user.id` từ Telegram vốn là SỐ, `String()` chuyển thành
  CHUỖI TEXT. Quan trọng vì so sánh SỐ với CHUỖI trong JavaScript "nghiêm ngặt" sẽ luôn ra sai (ví dụ
  lỗi "Wrong type: number vs string" đã từng gặp trong dự án này).
- **`[user.first_name, user.last_name].filter(Boolean).join(' ')`**: tạo 1 MẢNG gồm họ và tên, dùng
  `.filter(Boolean)` để LOẠI BỎ phần tử rỗng/không có (ví dụ user không có `last_name`), rồi
  `.join(' ')` NỐI các phần tử còn lại bằng dấu cách — kết quả là tên đầy đủ, không bị dư khoảng trắng
  nếu thiếu họ hoặc tên.
- **`!!(m && (m.photo || m.document || m.video))`**: `!!` (2 dấu chấm than) là mẹo ép 1 giá trị bất kỳ
  thành `true`/`false` thuần tuý (boolean) — ở đây kiểm tra "có `m` VÀ (có ảnh HOẶC file HOẶC video)".

## Node `GW-02b Merge Auth` (Code)

**Vấn đề:** Trước node này có 1 bước TRA CỨU Postgres xem người gửi tin nhắn đã được admin DUYỆT hay
chưa (bảng quyền truy cập). Kết quả tra cứu (từ Postgres) và Envelope (từ `GW-01`) là 2 nguồn dữ liệu
TÁCH RỜI — cần GỘP LẠI thành 1 object để dùng tiếp.

**Cách làm thực tế:**
```js
const env  = $('GW-01 Envelope').first().json;
const rows = $input.all().map(i => i.json).filter(r => r && r.status);

let state = 'new', bots = [], role = 'user';
if (rows.length) {
  const r = rows[0];
  role = r.role;
  bots = r.bots || [];
  state = r.status === 'active'  ? 'active'
        : r.status === 'pending' ? 'pending'
        : 'denied';
}
return [{ json: { ...env, auth: { state, role, bots } } }];
```
- **`$input.all()`**: lấy TẤT CẢ item đang chảy vào node này (từ bước tra cứu Postgres phía trước) —
  khác `$json` (chỉ lấy item hiện tại), `.all()` lấy CẢ DANH SÁCH.
- **`.map(i => i.json)`**: `map` là hàm DUYỆT QUA từng phần tử của mảng, TRẢ VỀ 1 mảng MỚI với mỗi
  phần tử đã được "biến đổi" theo hàm cho trước — ở đây chỉ lấy phần `.json` của từng item, bỏ các
  thông tin thừa khác (metadata n8n).
- **`.filter(r => r && r.status)`**: `filter` DUYỆT QUA mảng, chỉ GIỮ LẠI phần tử thoả điều kiện — ở
  đây giữ lại dòng nào CÓ dữ liệu (`r` khác rỗng) VÀ CÓ trường `status` (phòng khi Postgres trả về
  dòng trống do không tìm thấy user).
- **`r => r && r.status`**: đây là ARROW FUNCTION (hàm mũi tên) — cách viết NGẮN GỌN của hàm trong
  JavaScript hiện đại, tương đương `function(r) { return r && r.status; }`.
- **`if (rows.length) { ... }`**: `rows.length` là SỐ LƯỢNG phần tử trong mảng — nếu > 0 (có ít nhất
  1 dòng, tức JavaScript tự hiểu số khác 0 là "true"), nghĩa là ĐÃ TÌM THẤY user trong bảng quyền.
- **Toán tử 3 ngôi `?:`** (ternary): `r.status === 'active' ? 'active' : ...` nghĩa là "NẾU
  `r.status` bằng `'active'` THÌ kết quả là `'active'`, KHÔNG THÌ xét tiếp điều kiện sau `:`" — viết
  gọn cho `if/else` khi chỉ cần TRẢ VỀ 1 GIÁ TRỊ (không chạy nhiều dòng lệnh).
- **`{ ...env, auth: {...} }`**: dấu `...` (spread — "trải rộng") sao chép TOÀN BỘ field có sẵn trong
  `env` vào object mới, rồi THÊM field `auth` mới — cách "gộp" 2 object phổ biến trong JS hiện đại.

## Node `GW-03 Router` (Code)

**Vấn đề:** Cần biết tin nhắn/lệnh này nên chuyển sang SUB-WORKFLOW nào (`telebot_main`, `help_bot`...)
— message (gõ lệnh, có dạng `/lệnh`) và callback (bấm nút, `callback_data` KHÔNG có dạng `/lệnh`) cần
2 CÁCH nhận diện KHÁC NHAU.

**Cách làm thực tế:**
```js
const cfg = $('⚙️ Config').first().json;
const env = $input.first().json;

function resolveBotKeyForCallback(data) {
  if (!data) return null;
  if (data.startsWith('chitiet_') || data.startsWith('sync_') || data.startsWith('view_file:')) {
    return 'telebot_main';
  }
  return null;
}

let bot;
if (env.command) {
  bot = cfg.COMMAND_MAP[env.command] || null;
} else if (env.kind === 'callback') {
  bot = resolveBotKeyForCallback(env.callback?.data) || cfg.DEFAULT_BOT;
} else {
  bot = cfg.DEFAULT_BOT;
}

let route;
if (!bot)                                route = 'unknown';
else if (!env.auth.bots.includes(bot))   route = 'no_permission';
else                                     route = bot;

return [{ json: { ...env, bot_key: bot, route } }];
```
- **`function resolveBotKeyForCallback(data) {...}`**: khai báo 1 HÀM có TÊN (khác arrow function ẩn
  danh ở trên) — dùng khi hàm cần TÊN rõ ràng để dễ đọc code, hoặc gọi lại nhiều lần.
- **`data.startsWith('chitiet_')`**: hàm có sẵn của chuỗi text, kiểm tra chuỗi có BẮT ĐẦU BẰNG đoạn
  cho trước hay không, trả về `true`/`false`.
- **`cfg.COMMAND_MAP[env.command]`**: đây là cách TRUY CẬP GIÁ TRỊ trong OBJECT bằng KHOÁ ĐỘNG (khoá
  không viết cố định mà lấy từ biến `env.command`) — ví dụ nếu `env.command` là `"task"`, dòng này
  tương đương `cfg.COMMAND_MAP.task`.
- **`env.callback?.data`**: dấu `?.` gọi là OPTIONAL CHAINING — nghĩa là "nếu `env.callback` CÓ giá
  trị thì lấy `.data`, KHÔNG THÌ trả về `undefined` LUÔN, không bị lỗi crash chương trình" — an toàn
  hơn hẳn viết `env.callback.data` (sẽ lỗi nếu `env.callback` là `null`).
- **`env.auth.bots.includes(bot)`**: `includes()` là hàm của MẢNG, kiểm tra mảng có CHỨA giá trị cho
  trước hay không — ở đây kiểm tra "user này có quyền dùng bot `bot` không" (dựa vào danh sách quyền
  đã tra cứu ở `GW-02b`).

## Node `Parse callback` (Code)

**Vấn đề:** Riêng LUỒNG DUYỆT USER MỚI (khi admin bấm nút "Duyệt"/"Từ chối") mã hoá thông tin ngay
trong `callback_data`, dạng chuỗi `"ap:12345:telebot_main"` (duyệt user 12345 dùng bot telebot_main)
— cần TÁCH chuỗi này thành từng phần riêng để dùng.

**Cách làm thực tế:**
```js
const env = $('GW-01 Envelope').first().json;
const [action, uid, bot] = (env.callback.data || '').split(':');
return [{ json: { ...env, action, target_uid: uid, target_bot: bot || '' } }];
```
- **`.split(':')`**: hàm CẮT chuỗi text thành MẢNG các đoạn nhỏ, dựa vào ký tự phân cách (ở đây là dấu
  `:`) — ví dụ `"ap:12345:telebot_main".split(':')` cho ra mảng `["ap", "12345", "telebot_main"]`.
- **`const [action, uid, bot] = [...]`**: đây là DESTRUCTURING (giải cấu trúc mảng) — gán TỪNG PHẦN TỬ
  của mảng vào TỪNG BIẾN riêng theo đúng thứ tự, thay vì phải viết `arr[0]`, `arr[1]`, `arr[2]` dài
  dòng.

## Sơ đồ tổng thể Gateway

```
Telegram Trigger → GW-01 Envelope → (rẽ nhánh callback ap:/dn: hay không)
  → không phải ap:/dn: → GW-02 Auth Lookup (Postgres) → GW-02b Merge Auth
       → Trạng thái user? (mới/chờ duyệt/đã duyệt) → GW-03 Router → Route bot? → gọi sub-workflow
  → là ap:/dn: → Check admin → Là admin? → Parse callback → Approve/Deny (duyệt user mới)
```
