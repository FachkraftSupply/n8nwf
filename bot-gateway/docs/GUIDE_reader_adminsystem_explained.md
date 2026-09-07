# GIẢI THÍCH CHI TIẾT — `Telebot_ClickUp_Reader.json` + `Telebot_Admin_System.json`

> Dành cho người MỚI BẮT ĐẦU học lập trình. 2 file này CHIA SẺ phần lớn node giống hệt nhau —
> `Telebot_Admin_System.json` là bản ĐẦY ĐỦ (có thêm `/sync`), `Telebot_ClickUp_Reader.json` là bản
> RÚT GỌN (chỉ tìm task + xem chi tiết) — nên gộp giải thích chung, ghi rõ phần nào chỉ có ở bản nào.

## Node `Phân tích lệnh` (Code) — "bộ não" định tuyến của cả workflow

**Vấn đề:** Lệnh user gõ có thể ở NHIỀU DẠNG: `/task linh nhi` (lệnh + tham số), `/help` (lệnh
trơn), `chitiet_z908824gex` (deep-link, không có dấu `/`), hay bấm nút trong menu — cần 1 nơi DUY
NHẤT phân tích và quyết định "đây là yêu cầu gì, cần đi tới đâu".

**Cách làm thực tế (rút gọn phần lặp lại nhiều, đầy đủ xem trực tiếp trong workflow):**
```js
function parseCommand(rawText) {
  let command = '';
  let params = '';
  if ((rawText || '').startsWith('/')) {
    const parts = rawText.trim().split(/\s+/);
    command = parts[0].toLowerCase();
    params = parts.slice(1).join(' ');
  } else {
    params = rawText || '';
  }
  return { command, params };
}
```
- `rawText.trim()`: hàm CẮT khoảng trắng thừa Ở ĐẦU VÀ CUỐI chuỗi (không cắt khoảng trắng ở giữa).
- `.split(/\s+/)`: cắt chuỗi thành mảng theo "1 hoặc nhiều khoảng trắng liên tiếp" (`\s+` là regex —
  `\s` nghĩa là ký tự khoảng trắng, `+` nghĩa là "1 hoặc nhiều lần") — tách được lệnh và tham số dù
  người dùng gõ nhiều dấu cách liền nhau.
- `parts[0]`: phần tử ĐẦU TIÊN của mảng (chỉ số 0) — chính là LỆNH (`/task`).
- `parts.slice(1).join(' ')`: `.slice(1)` lấy TỪ phần tử thứ 2 TRỞ ĐI (bỏ lệnh), `.join(' ')` nối lại
  bằng dấu cách — ra được TOÀN BỘ phần THAM SỐ sau lệnh.
- `return { command, params }`: khi tên BIẾN và tên FIELD trong object GIỐNG NHAU, JavaScript cho
  phép viết TẮT `{ command, params }` thay vì phải viết `{ command: command, params: params }`.

```js
function computeRoute(command, params) {
  if (params.startsWith('chitiet_')) {
    return { route: 'chitiet', params: 'chitiet', taskId: params.replace('chitiet_', '').trim() };
  }
  if (params.startsWith('sync_folder_')) { ... }   // CHỈ CÓ ở Telebot_Admin_System
  if (params.startsWith('sync_list_')) { ... }      // CHỈ CÓ ở Telebot_Admin_System
  if (params === 'menu_sync') return { route: 'sync', params: '', taskId: null };   // link trong /help
  if (command === '/task') return { route: 'task', params, taskId: null };
  if (command === '/help' || command === '/start') return { route: 'help', params, taskId: null };
  if (command === '/sync') return { route: 'sync', params, taskId: null };          // CHỈ CÓ ở Admin
  if (!command && params) return { route: 'free_text', params, taskId: null };
  return { route: 'unknown_command', params, taskId: null };
}
```
- Đây là 1 dãy `if` KIỂM TRA TUẦN TỰ — CÁI NÀO KHỚP TRƯỚC thì DỪNG LẠI ngay (nhờ có `return` bên
  trong mỗi khối `if`), không xét tiếp các điều kiện phía sau — thứ tự kiểm tra RẤT QUAN TRỌNG (ví dụ
  phải kiểm tra `chitiet_` TRƯỚC khi kiểm tra lệnh `/task`, vì deep-link `chitiet_` không bắt đầu
  bằng `/`).
- `params.replace('chitiet_', '')`: thay thế đoạn `chitiet_` bằng chuỗi RỖNG — tức "XOÁ" đoạn đó khỏi
  chuỗi, chỉ giữ lại phần ID task còn lại.

```js
if (isCallback) {
  const r = computeRoute('', rawText);
  route = r.route; params = r.params; taskId = r.taskId;
} else {
  const parsed = parseCommand(rawText);
  const r = computeRoute(parsed.command, parsed.params);
  route = r.route; params = r.params; taskId = r.taskId;
}
```
- Nếu là CALLBACK (bấm nút trong `Telebot_Admin_System.json`): TÁI SỬ DỤNG luôn hàm `computeRoute`
  (không viết logic riêng) — chỉ cần truyền `command=''` và `params=rawText` (dữ liệu nút bấm), vì
  cả deep-link lẫn callback_data đều dùng CHUNG 1 tập tiền tố (`sync_folder_`, `menu_sync`...).

## Node `⚙️ Config` (Code)

Tương tự Full Reconcile — 1 nơi tập trung `botUsername` (tên bot để tạo deep-link), `ADMIN_CHAT_ID`.
Ở `Telebot_Admin_System.json` còn có thêm `TEAM_ID`/`SPACE_ID` để dùng làm EXPRESSION cho node ClickUp
(tránh lỗi "Error fetching options" đã ghi trong `RULES.md` mục 4).

## Node `Prepare Search` (Code)

**Vấn đề:** Người dùng gõ tiếng Việt CÓ DẤU (`linh nhi`), nhưng dữ liệu trong Postgres có cột KHÔNG
DẤU (`linh nhi` → `linh nhi`, không đổi; nhưng `Lệ` → `le`) để tìm kiếm không cần gõ dấu.

**Cách làm:**
```js
const normalize = (s) => (s || '')
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .replace(/\u0111/g, 'd').replace(/\u0110/g, 'D').toLowerCase();
```
- `.normalize('NFD')`: hàm CÓ SẴN của JavaScript, TÁCH RIÊNG chữ cái và dấu thanh (ví dụ chữ "ệ" tách
  thành "e" + "dấu nặng" + "dấu mũ" — 3 ký tự Unicode riêng biệt thay vì 1 ký tự gộp).
- `.replace(/[\u0300-\u036f]/g, '')`: `\u0300-\u036f` là DẢI MÃ UNICODE của các "dấu thanh" (sau khi
  tách bằng NFD) — regex này XOÁ TOÀN BỘ dấu, chỉ còn lại chữ cái gốc.
- `\u0111`/`\u0110`: mã Unicode riêng của chữ "đ"/"Đ" (2 chữ này KHÔNG tách được bằng NFD như chữ có
  dấu thanh, vì "đ" là 1 CHỮ CÁI RIÊNG trong tiếng Việt, không phải "d + dấu") — phải xử lý THỦ CÔNG.

## Node `Beautify full` (Code) — định dạng kết quả tìm kiếm

Đọc kết quả từ Postgres (đã có sẵn `total_count` nhờ `COUNT(*) OVER()` trong câu SQL), format thành
tin nhắn HTML đẹp, có LINK bấm được (deep-link `chitiet_<id>`) cho từng task tìm thấy. Nếu có nhiều
hơn 10 kết quả, chỉ hiện 10 đầu + nhắc user tìm cụ thể hơn.

## Node `Beautify chi tiết` (Code) — hiện chi tiết 1 task + thống kê DKPV/PVTC

**Vấn đề:** Chi tiết task cần đọc từ 2 NGUỒN dữ liệu KHÁC NHAU (thông tin task từ bảng `tasks`, danh
sách liên kết từ bảng `task_links`) — 2 node Postgres phía trước, `$json` chỉ giữ được nguồn GẦN NHẤT.

**Cách làm:** đọc thông tin task qua `$('task_detail_sql').all()` (tham chiếu TƯỜNG MINH ngược lại
đúng 1 bước, an toàn vì không có node nào ở giữa), còn `$input.all()` (input trực tiếp của CHÍNH node
này) là danh sách liên kết DKPV/PVTC — nhóm theo `link_type` VÀ `year` bằng hàm `groupByYear()`.

## Node `Nội dung lệnh help` (Code)

Ở `Telebot_Admin_System.json`: liệt kê ĐẦY ĐỦ lệnh, có 3 dòng LINK bấm được (deep-link `menu_sync`...).
Ở `Telebot_ClickUp_Reader.json`: chỉ còn `/task` (đã bỏ `/sync`* — chuyển hẳn sang Admin System).

## Các node RIÊNG của `Telebot_Admin_System.json`

### `Build Envelope (System Bot)` (Code)
Vì bot này có Telegram Trigger RIÊNG (không qua Gateway), phải TỰ "dịch" dữ liệu Telegram thô về đúng
cấu trúc Envelope mà `Phân tích lệnh` cần (giống hệt việc `GW-01 Envelope` làm bên Gateway).

### `Build Nút Folder` / `Build Nút List` (Code)
Nhận danh sách Folder/List từ ClickUp (`$input.all().map(i => i.json)`), với MỖI phần tử tạo 1 DÒNG
LINK: `` `https://t.me/${botUsername}?start=sync_folder_${f.id}` `` — bấm vào link này Telegram tự
động gửi lệnh `/start sync_folder_<id>`, được `Phân tích lệnh` nhận diện qua `computeRoute()`.
`folders.forEach((f, i) => {...})`: `forEach` là hàm DUYỆT MẢNG (giống `map` nhưng KHÔNG tạo mảng mới
— chỉ để "làm gì đó" với từng phần tử, ở đây là "thêm 1 dòng vào mảng `lines`"), `i` là CHỈ SỐ (0, 1,
2...) của phần tử hiện tại trong mảng, dùng để đánh số thứ tự `${i + 1}.`.

### `Tách List ID + Folder ID` (Code)
```js
const raw = $('Phân tích lệnh').first().json.params;
const [listId, folderId] = raw.split('_');
```
`callback_data`/deep-link dạng `sync_list_<listId>_<folderId>` sau khi bỏ tiền tố `sync_list_` (đã
làm ở `computeRoute`) còn lại `<listId>_<folderId>` — TÁCH tiếp bằng dấu `_` để lấy riêng 2 giá trị.

### `Chuẩn bị lưu Sync Target` (Code)
Gộp dữ liệu từ 2 node TRƯỚC ĐÓ (`Tách List ID + Folder ID` và `ClickUp - Get List Info`) thành 1 dòng
object CHUẨN HOÁ, sẵn sàng để node Postgres phía sau LƯU vào bảng `clickup.sync_targets`.

### `Hỏi Đồng Bộ Ngay` (Code)
Sau khi lưu xong 1 List vào danh sách tự động đồng bộ, hỏi user muốn đồng bộ NGAY hay CHỜ LẦN SAU —
2 LINK riêng biệt (`sync_now_<id>` / `sync_later`), dẫn tới 2 hành động khác nhau.

### `Build Sync Status` / `Build DB Status` (Code)
- `Build Sync Status`: liệt kê các List ĐÃ ĐĂNG KÝ tự động đồng bộ (đọc từ `clickup.sync_targets`).
- `Build DB Status`: thống kê SỐ LƯỢNG task theo TỪNG STATUS trong Postgres — dùng
  `statuses.reduce((sum, r) => sum + r.cnt, 0)` để CỘNG DỒN tổng số (hàm `reduce` "gộp" cả mảng thành
  1 GIÁ TRỊ DUY NHẤT, ở đây là tổng — `sum` là "tổng đang cộng dồn", `r` là từng phần tử, `0` là giá
  trị KHỞI ĐẦU của `sum` trước khi bắt đầu cộng).
- `Object.entries(byList)`: chuyển 1 OBJECT (dạng `{tênList: [dòng, dòng...]}`) thành MẢNG các CẶP
  `[tên, giá trị]` — để dùng được với vòng lặp `for...of`.

## Sơ đồ tổng thể (bản đầy đủ `Telebot_Admin_System.json`)

```
Telegram Trigger (System Bot) → Build Envelope → Phân tích lệnh → Config → Switch
  → help / task / chitiet / sync / sync_folder / sync_list / sync_now / sync_later /
    sync_status / db_status / (mặc định: lệnh không hợp lệ)
```
