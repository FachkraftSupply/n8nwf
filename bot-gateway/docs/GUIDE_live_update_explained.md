# GIẢI THÍCH CHI TIẾT — `SQL_ClickUp_Live_Update.json`

> Dành cho người MỚI BẮT ĐẦU học lập trình.

## Workflow này khác Full Reconcile ở điểm gì?

`Full Reconcile` chạy ĐỊNH KỲ, quét TOÀN BỘ task 1 lượt (tốn thời gian, phù hợp chạy vài ngày 1 lần).
`Live Update` chạy NGAY LẬP TỨC mỗi khi có 1 THAY ĐỔI xảy ra trên ClickUp (ai đó sửa task, thêm
comment...) — ClickUp tự động gửi 1 "webhook" (tin báo) tới n8n, workflow bắt lấy tin báo đó và xử lý.

## Node `⚙️ Config (Admin Chat ID)` (Code)

**Vấn đề:** Cần biết gửi thông báo Telegram tới CHAT NÀO.

**Cách làm:**
```js
const ADMIN_CHAT_ID = "975005174";
return [{ json: { ...$json, adminChatId: ADMIN_CHAT_ID } }];
```
- Khai báo 1 HẰNG SỐ (constant) `ADMIN_CHAT_ID` — muốn đổi người nhận thông báo, chỉ cần sửa đúng
  DÒNG NÀY, không phải tìm khắp nơi.
- `{ ...$json, adminChatId: ADMIN_CHAT_ID }`: dùng dấu `...` (spread, đã giải thích ở guide Gateway)
  để giữ nguyên TOÀN BỘ dữ liệu webhook gốc, chỉ THÊM 1 field mới `adminChatId`.

## Node `Nhận Diện & Format Thay Đổi` (Code) — phần quan trọng nhất

**Vấn đề:** 1 webhook ClickUp gửi tới có thể chứa NHIỀU thay đổi CÙNG LÚC (ví dụ sửa cả tên VÀ trạng
thái task trong 1 lần lưu) — và MỖI LOẠI thay đổi (đổi tên, đổi mô tả, đổi custom field, thêm
comment...) có CẤU TRÚC DỮ LIỆU khác nhau, cần xử lý riêng.

**Ý tưởng giải quyết:** Duyệt qua danh sách `history_items` (danh sách thay đổi) ClickUp gửi kèm, với
MỖI thay đổi thì XÁC ĐỊNH LOẠI (dùng `if/else if` — "nếu là loại A thì làm cách A, loại B thì làm cách
B..."), rồi tạo ra 1 "item" riêng biệt cho từng thay đổi để các node phía sau xử lý tuần tự.

**Cách làm thực tế (tóm tắt các phần chính, đã giải thích chi tiết hơn ở phần trả lời trước trong dự
án — xem lại `CHANGELOG.md` ngày 06/09 nếu cần code đầy đủ):**

```js
const body = $('ClickUp Trigger (Live)').first().json;
const historyItems = body.history_items || [];
const taskId = body.task_id;
```
- `historyItems = body.history_items || []`: nếu ClickUp KHÔNG gửi kèm `history_items` (trường hợp
  hiếm), dùng MẢNG RỖNG thay thế — tránh lỗi khi code phía sau cố `.map()`/`.filter()` trên `undefined`.

```js
function extractPlainTextFromDelta(raw) {
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (parsed && Array.isArray(parsed.ops)) {
      return parsed.ops.map(op => (typeof op.insert === 'string' ? op.insert : '')).join('').trim();
    }
  } catch (e) { }
  return typeof raw === 'string' ? raw : '';
}
```
- Mô tả task trong ClickUp lưu ở định dạng "Quill Delta" (dùng cho trình soạn thảo rich-text) — dạng
  `{"ops":[{"insert":"Xin chào "},{"insert":"thế giới"}]}` thay vì text thường.
- `try { ... } catch (e) { }`: khối XỬ LÝ LỖI — "thử chạy code trong `try`, nếu có lỗi (ví dụ
  `JSON.parse` thất bại vì dữ liệu không phải JSON hợp lệ) thì nhảy sang `catch`, KHÔNG làm crash cả
  chương trình".
- `typeof raw === 'string' ? JSON.parse(raw) : raw`: `typeof` kiểm tra KIỂU DỮ LIỆU của biến — nếu
  `raw` là chuỗi thì PARSE (chuyển từ text sang object thật), nếu ĐÃ là object rồi thì dùng luôn.
- `.map(op => ...).join('')`: `map` chuyển mỗi "đoạn" (`op`) trong `ops` thành CHỮ (nếu có), `join('')`
  NỐI tất cả đoạn chữ lại thành 1 chuỗi hoàn chỉnh, không có gì xen giữa.

```js
function simpleDiff(before, after) {
  if (before === after) return { changed: false, removed: '', added: '', start: 0, endB: 0, endA: 0 };
  let start = 0;
  const minLen = Math.min(before.length, after.length);
  while (start < minLen && before[start] === after[start]) start++;
  let endB = before.length, endA = after.length;
  while (endB > start && endA > start && before[endB - 1] === after[endA - 1]) { endB--; endA--; }
  return { changed: true, removed: before.slice(start, endB), added: after.slice(start, endA), start, endB, endA };
}
```
- Hàm TỰ VIẾT (không dùng thư viện có sẵn) để so sánh 2 đoạn text TRƯỚC và SAU khi sửa, tìm ra ĐÚNG
  PHẦN nào đã thay đổi (không phải in ra toàn bộ đoạn văn dài).
- `Math.min(before.length, after.length)`: lấy ĐỘ DÀI NHỎ HƠN giữa 2 chuỗi (tránh so sánh vượt quá
  giới hạn của chuỗi ngắn hơn).
- **Vòng lặp `while (...) start++`**: `while` là vòng lặp chạy MÃI khi điều kiện còn ĐÚNG — ở đây tăng
  `start` lên từng bước, so sánh ký tự cùng vị trí của 2 chuỗi, DỪNG LẠI ngay khi gặp ký tự KHÁC NHAU
  — tìm ra "đoạn giống nhau ở ĐẦU" 2 chuỗi.
- Vòng lặp `while` thứ 2 làm TƯƠNG TỰ nhưng đi từ CUỐI chuỗi lùi lại — tìm "đoạn giống nhau ở CUỐI".
- Phần CÒN LẠI ở GIỮA (không thuộc đầu/cuối giống nhau) chính là đoạn ĐÃ THAY ĐỔI thật sự.
- `.slice(start, endB)`: cắt lấy 1 ĐOẠN của chuỗi, từ vị trí `start` tới TRƯỚC vị trí `endB`.

```js
const results = [];
for (const h of historyItems) {
  ...
  if (h.field === 'comment' && h.comment) { ... }
  else if (h.field === 'content') { ... }
  else if (h.field === 'custom_field' && h.custom_field) { ... }
  else if (h.field === 'assignee_add') { ... }
  else if (h.field === 'name') { ... }
  else if (h.field === 'status') { ... }
  else { continue; }
  results.push({ json: { taskId, column, label, displayValue, dbValue, changedBy, dateStr } });
}
```
- `for (const h of historyItems)`: vòng lặp "for...of" — duyệt qua TỪNG PHẦN TỬ của mảng
  `historyItems`, mỗi lần lặp `h` là 1 thay đổi cụ thể.
- Dãy `if/else if` dài: xét LẦN LƯỢT xem `h.field` (loại field bị đổi) là gì, RẼ NHÁNH xử lý tương ứng.
- `else { continue; }`: nếu KHÔNG khớp loại nào đã biết, `continue` là lệnh "bỏ qua, nhảy sang lần lặp
  TIẾP THEO ngay", không chạy dòng `results.push(...)` phía dưới cho thay đổi này.
- `results.push({...})`: `push` là hàm THÊM 1 phần tử vào CUỐI mảng — dùng để "gom" từng kết quả xử lý
  vào danh sách `results`, để cuối cùng TRẢ VỀ toàn bộ (n8n hiểu đây là "nhiều item" nếu 1 webhook có
  nhiều thay đổi cùng lúc, sẽ tự tách thành nhiều lần chạy các node phía sau).

## Node `Build Thông Báo` (Code)

**Vấn đề:** Nội dung task (tên, mô tả...) có thể chứa CHÍNH XÁC ký tự `<`, `>`, `&` (ví dụ ai đó gõ
`<b>` như CHỮ THẬT, không phải định dạng) — nếu chèn thẳng vào tin nhắn HTML, Telegram sẽ HIỂU NHẦM
thành thẻ HTML thật, gây lỗi gửi tin.

**Cách làm:**
```js
function escapeHtml(s) {
  return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
```
- `s ?? ''`: toán tử `??` (nullish coalescing) — "nếu `s` là `null`/`undefined` thì dùng chuỗi rỗng
  thay thế" (khác `||`, `??` KHÔNG coi số `0` hay chuỗi rỗng `''` là "thiếu giá trị").
- `.replace(/&/g, '&amp;')`: THAY THẾ mọi ký tự `&` (dấu `/g` sau regex nghĩa là "global" — thay TẤT
  CẢ, không chỉ lần đầu tiên) bằng mã HTML tương ứng — làm 3 lần liên tiếp cho `&`, `<`, `>` (LƯU Ý:
  phải escape `&` TRƯỚC TIÊN, nếu không sẽ escape luôn cả `&amp;` vừa tạo ra thành `&amp;amp;`).

## Sơ đồ tổng thể

```
ClickUp Trigger (Live) → Config (Admin Chat ID) → Nhận Diện & Format Thay Đổi
  → Có Thay Đổi Cần Theo Dõi? → Có Cột Cần Ghi DB?
       true  → Ghi Đè Postgres (UPDATE dynamic column)
       false → Lấy Thông Tin Task (SELECT)
  → (cả 2 nhánh) → Build Thông Báo → Notify (Telegram System Bot)
```
