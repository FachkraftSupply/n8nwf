# GIẢI THÍCH CHI TIẾT — `SQL_ClickUp_Full_Reconcile.json`

> Tài liệu này giải thích từng node Code theo cấu trúc: **Vấn đề** (tại sao cần node này) →
> **Ý tưởng giải quyết** → **Cách làm thực tế** (giải thích từng biến/hàm trong code).

## Tổng quan workflow

Workflow này đồng bộ dữ liệu từ ClickUp sang Postgres, gồm 3 việc chính:
1. Lấy toàn bộ task trong 1 List ClickUp, lưu thành dòng dữ liệu gọn gàng vào bảng `clickup.tasks`.
2. Trích xuất các liên kết "Đăng ký phỏng vấn" (DKPV) và "Được nhận" (PVTC) — vốn là các custom field
   kiểu quan hệ (list_relationship) trỏ tới task khác (Đơn Hàng) — lưu thành bảng quan hệ có cấu trúc
   `clickup.task_links` (thay vì chỉ lưu dạng chuỗi text khó xử lý).
3. Với từng task, kiểm tra comment để tìm link OneDrive/Youtube (do nhân viên dán vào comment), cập
   nhật vào bảng `tasks`.

---

## Node `⚙️ Config` (Code)

**Vấn đề:** Cần 1 nơi TẬP TRUNG để cấu hình các giá trị dùng CHUNG cho toàn bộ workflow (team ID,
space ID, List đang đồng bộ, chế độ test...) — nếu rải rác hardcode ở nhiều node, khi cần đổi 1 giá
trị sẽ phải sửa ở nhiều chỗ, dễ sót.

**Ý tưởng giải quyết:** Dùng 1 Code node CHẠY ĐẦU TIÊN, trả về 1 object JSON chứa TẤT CẢ cấu hình.
Các node phía sau tham chiếu tới `$('⚙️ Config').first().json...` để lấy giá trị, thay vì hardcode.

**Cách làm thực tế:**
```js
const input = $json || {};
const config = {
  team_id: "9018351620",
  space_id: "90183192291",
  list_id: input.list_id || "901812218309",
  list_name: input.list_name || "",
  notifyChatId: "",
  ADMIN_CHAT_ID: "975005174",
  testMode: input.testMode !== undefined ? input.testMode : true,
  testTaskLimit: 5,
  fieldNameMap: { b1_datum: "B1 Datum", dob: "DOB", ... }
};
return [{ json: config }];
```
- `input`: dữ liệu ĐẦU VÀO của node này — nếu workflow được gọi qua "Execute Workflow Trigger" (từ
  `/sync` hoặc `Sync Scheduler`), `input` sẽ chứa `list_id`/`testMode`/`list_name` được truyền vào từ
  nơi gọi. Nếu chạy qua Manual Trigger, `input` rỗng `{}`.
- `list_id: input.list_id || "901812218309"`: dùng toán tử `||` — nếu `input.list_id` có giá trị (từ
  `/sync`) thì DÙNG giá trị đó; nếu không (Manual Trigger, không truyền gì) thì dùng List mặc định.
- `testMode: input.testMode !== undefined ? input.testMode : true`: KHÔNG dùng `||` ở đây vì
  `testMode` có thể là `false` (giá trị hợp lệ) — nếu dùng `||`, `false || true` sẽ SAI (luôn ra
  `true`)! Phải kiểm tra rõ ràng "có được truyền vào hay không" bằng `!== undefined`.
- `fieldNameMap`: bảng tra cứu — cột Postgres (`b1_datum`) ứng với tên custom field THẬT trong ClickUp
  (`"B1 Datum"`) — vì tên cột code không thể có dấu/khoảng trắng, nhưng tên field ClickUp thì có.

---

## Node `Map Row (không comment)` (Code, mode `runOnceForEachItem`)

**Vấn đề:** Dữ liệu thô từ ClickUp API rất phức tạp (nhiều tầng lồng nhau: `custom_fields` là 1 mảng
object, ngày tháng là timestamp số...) — không thể lưu thẳng vào Postgres, cần "dịch" sang dạng bảng
phẳng (mỗi cột 1 giá trị đơn giản).

**Ý tưởng giải quyết:** Viết 1 hàm helper `getCF()` (get custom field) để tìm ĐÚNG custom field theo
TÊN (không phải ID — vì ID field trên ClickUp là chuỗi ngẫu nhiên khó nhớ, tên thì cố định), rồi tuỳ
KIỂU DỮ LIỆU của field mà xử lý khác nhau (ngày tháng → format `dd/mm/yyyy`, quan hệ → gộp thành chuỗi
tên+trạng thái, còn lại → chuyển thành chuỗi text).

**Cách làm thực tế:**
```js
const cfg = $('⚙️ Config').first().json;
const t = $json;
const fieldNameMap = cfg.fieldNameMap;

const normalize = (s) => (s || '')
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .replace(/\u0111/g, 'd').replace(/\u0110/g, 'D').toLowerCase();

function getCF(customFields, name) {
  if (!Array.isArray(customFields) || !name) return null;
  const f = customFields.find(cf => (cf.name || '').trim().toLowerCase() === name.trim().toLowerCase());
  if (!f || f.value === undefined || f.value === null) return null;
  if (f.type === 'list_relationship' && Array.isArray(f.value)) {
    return f.value.map(v => v.status ? `${v.name} (${v.status})` : v.name).join('; ');
  }
  if (f.type === 'date' || /^\d{10,13}$/.test(String(f.value))) {
    const d = new Date(Number(f.value));
    if (!isNaN(d.getTime())) {
      const dd = String(d.getDate()).padStart(2, '0');
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      return `${dd}/${mm}/${d.getFullYear()}`;
    }
  }
  if (typeof f.value === 'object') return JSON.stringify(f.value);
  return String(f.value);
}
```
- `normalize(s)`: bỏ dấu tiếng Việt (dùng chuẩn Unicode NFD tách chữ cái khỏi dấu, rồi xoá dấu) — để
  tạo cột `name_khong_dau` phục vụ tìm kiếm không cần gõ dấu (`/task linh nhi` vẫn ra "Linh Nhi").
- `getCF(customFields, name)`: hàm CHÍNH — nhận mảng `custom_fields` (từ ClickUp) và TÊN field cần
  tìm, trả về giá trị đã "dịch" sẵn thành chuỗi text hiển thị được:
  - `customFields.find(...)`: tìm phần tử có `name` khớp (so sánh không phân biệt hoa/thường, bỏ
    khoảng trắng thừa — phòng khi ClickUp trả về tên field có khoảng trắng lạ).
  - Nếu field kiểu `list_relationship` (liên kết tới task khác, như DKPV/PVTC): gộp TẤT CẢ đơn hàng
    liên quan thành 1 chuỗi `"Tên (trạng thái); Tên khác (trạng thái khác)"` — đây là bản HIỂN THỊ
    đơn giản, dùng cho cột text trong bảng `tasks`; bảng `task_links` (node khác) lưu bản có CẤU TRÚC.
  - Nếu field kiểu `date` (hoặc giá trị là số 10-13 chữ số, dấu hiệu là timestamp Unix): chuyển từ số
    mili-giây thành chuỗi `dd/mm/yyyy` dễ đọc.
  - Còn lại: nếu là object thì `JSON.stringify`, nếu không thì ép thành chuỗi text.
- Cuối node: dùng `getCF(cfs, fieldNameMap.xxx)` LẶP LẠI cho từng cột cần lưu — mỗi lần gọi tự động
  tra đúng tên field thật trong ClickUp qua `fieldNameMap`.

---

## Node `Trích Xuất Task Links` (Code, mode `runOnceForEachItem`)

**Vấn đề:** DKPV/PVTC là dữ liệu QUAN HỆ (1 học sinh có thể liên kết với NHIỀU đơn hàng, qua NHIỀU
năm khác nhau) — nếu chỉ lưu thành 1 chuỗi text (như node `Map Row` ở trên), sẽ KHÔNG đếm được chính
xác số lượng, KHÔNG tạo được link bấm xem chi tiết từng đơn hàng. Ngoài ra, tên field ClickUp cho
DKPV/PVTC ĐỔI MỖI NĂM (`DKPV 2026`, `DKPV 2027`, `PVTC 2026`...) — không thể hardcode 1 tên cố định.

**Ý tưởng giải quyết:** Dùng REGEX để tự động nhận diện MỌI field có tên khớp mẫu `DKPV <năm>` hoặc
`PVTC <năm>` (không cần biết trước có bao nhiêu field, năm nào) — với mỗi field tìm được, "bung" mảng
đơn hàng liên kết (`value[]`) thành TỪNG DÒNG RIÊNG để lưu vào bảng quan hệ `task_links`.

**Cách làm thực tế:**
```js
const t = $('ClickUp - Get Tasks').item.json;
const cfs = t.custom_fields || [];

function extractLinks(field, linkType, year) {
  if (!field || !Array.isArray(field.value)) return [];
  return field.value.map(v => ({
    order_task_id: v.id,
    order_task_name: v.name || '',
    order_task_status: v.status || '',
    link_type: linkType,
    year: year,
  }));
}

let links = [];
const DKPV_RE = /^DKPV\s+(\d{4})$/i;
const PVTC_RE = /^PVTC\s+(\d{4})$/i;

for (const cf of cfs) {
  const name = (cf.name || '').trim();
  const dkpvMatch = name.match(DKPV_RE);
  if (dkpvMatch) {
    links = links.concat(extractLinks(cf, 'dkpv', parseInt(dkpvMatch[1], 10)));
    continue;
  }
  const pvtcMatch = name.match(PVTC_RE);
  if (pvtcMatch) {
    links = links.concat(extractLinks(cf, 'pvtc', parseInt(pvtcMatch[1], 10)));
  }
}

const seen = new Set();
const dedupedLinks = links.filter(l => {
  const key = `${l.order_task_id}|${l.link_type}|${l.year}`;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

return { json: { taskId: t.id, linksJson: JSON.stringify(dedupedLinks),
                  id: $json.id, onedrive_link: $json.onedrive_link, youtube_link: $json.youtube_link } };
```
- `t = $('ClickUp - Get Tasks').item.json`: LẤY DỮ LIỆU GỐC từ ClickUp (không phải từ Postgres) — vì
  cần `custom_fields` NGUYÊN BẢN (Postgres chỉ lưu bản đã "dịch" thành text, mất cấu trúc gốc).
- `extractLinks(field, linkType, year)`: hàm chuyển 1 custom field (dạng `{value: [{id,name,status}]}`)
  thành MẢNG các object phẳng — mỗi phần tử `value[]` (1 đơn hàng liên kết) → 1 dòng riêng, kèm
  `link_type` ('dkpv'/'pvtc') và `year` (năm lấy từ tên field, không phải năm hiện tại).
- 2 biến regex `DKPV_RE`/`PVTC_RE`: mẫu `^DKPV\s+(\d{4})$` nghĩa là "bắt đầu bằng chữ DKPV, theo sau
  là khoảng trắng, rồi đúng 4 chữ số (năm), không còn gì khác". `(\d{4})` là NHÓM BẮT (capture group)
  — lấy ra được đúng số năm để dùng ở `dkpvMatch[1]`.
- Vòng lặp `for (const cf of cfs)`: quét TỪNG custom field của task, thử khớp lần lượt DKPV rồi PVTC,
  gom kết quả vào mảng `links`.
- `seen`/`dedupedLinks`: lớp PHÒNG VỆ khử trùng lặp — dùng `Set` (cấu trúc chỉ lưu giá trị DUY NHẤT)
  để đánh dấu đã gặp key nào (`order_task_id|link_type|year`), bỏ qua nếu gặp lại — tránh lỗi
  "duplicate key" khi ghi vào Postgres nếu dữ liệu ClickUp có phần tử trùng.
- 3 dòng cuối `id`/`onedrive_link`/`youtube_link`: đọc TRỰC TIẾP từ `$json` (input của CHÍNH node
  này, tức từ node `Upsert Postgres` ngay phía trước) — mục đích để 3 giá trị này "đi nhờ" qua node
  tiếp theo, thay vì phải quay lại tham chiếu ngược (kỹ thuật đã ghi trong `RULES.md` mục 11).

---

## Node `Trích Link từ Comment` (Code, `alwaysOutputData: true`)

**Vấn đề:** Link OneDrive/Youtube được nhân viên dán vào PHẦN COMMENT của task (không phải custom
field) — ClickUp trả về comment dưới dạng cấu trúc phức tạp (mảng các "segment" văn bản/link), có thể
là link "trần" (dán y nguyên URL) hoặc link "được bọc" (bookmark, giữ tên hiển thị khác URL).

**Ý tưởng giải quyết:** Duyệt qua từng comment, ưu tiên đọc field cấu trúc sẵn có
(`bookmark.url`/`attributes.link`) — nếu không có, DÙNG REGEX quét chuỗi text thô tìm URL. Với mỗi
URL tìm được, phân loại là OneDrive hay Youtube dựa vào domain.

**Cách làm thực tế:**
```js
const items = $input.all();
const URL_RE = /https?:\/\/[^\s)"'\]]+/g;
function classifyLink(url) {
  const u = url.toLowerCase();
  if (u.includes('onedrive.live.com') || u.includes('1drv.ms') || u.includes('sharepoint.com')) return 'onedrive';
  if (u.includes('youtube.com') || u.includes('youtu.be')) return 'youtube';
  return null;
}
const results = [];
for (let idx = 0; idx < items.length; idx++) {
  const c = items[idx].json;
  let taskId = c.task_id || c.task?.id || null;
  if (!taskId) {
    try { taskId = $('ClickUp - Get Tasks').itemMatching(idx).json.id; } catch (e) { continue; }
  }
  if (!taskId) continue;
  let link = null, kind = null;
  const segs = Array.isArray(c.comment) ? c.comment : [];
  for (const seg of segs) {
    const candidate = seg.bookmark?.url || seg.attributes?.link;
    if (candidate) { const k = classifyLink(candidate); if (k) { link = candidate; kind = k; break; } }
  }
  if (!link) {
    const plain = c.comment_text || '';
    for (const url of (plain.match(URL_RE) || [])) {
      const k = classifyLink(url); if (k) { link = url; kind = k; break; }
    }
  }
  if (link) results.push({ json: { taskId, link, kind } });
}
if (results.length === 0) return [{ json: { taskId: null, link: null, kind: null } }];
return results;
```
- `URL_RE`: regex tìm chuỗi bắt đầu bằng `http://` hoặc `https://`, dừng lại khi gặp khoảng trắng
  hoặc các ký tự thường đứng SAU 1 URL trong văn bản (dấu ngoặc, nháy) — tránh "dính" thêm ký tự thừa
  vào cuối URL.
- `classifyLink(url)`: hàm phân loại — kiểm tra URL có chứa domain OneDrive (`onedrive.live.com`,
  `1drv.ms`, `sharepoint.com`) hay Youtube (`youtube.com`, `youtu.be`), trả về `null` nếu không khớp.
- Vòng lặp ngoài `for (idx...)`: xử lý TỪNG comment (node ClickUp Get Comments có thể trả về comment
  của NHIỀU task gộp lại nếu chạy theo batch — tuy hiện tại là 1 task/lần nên thường chỉ 1 comment).
  - `taskId = c.task_id || c.task?.id`: thử lấy task ID trực tiếp từ dữ liệu comment; nếu ClickUp
    không trả về (tuỳ phiên bản API), dùng `itemMatching(idx)` để dò lại từ node gốc — bọc `try/catch`
    để bỏ qua an toàn nếu không xác định được (tránh lỗi làm dừng cả workflow).
  - Vòng lặp trong `for (seg of segs)`: mỗi comment gồm nhiều "segment" (đoạn văn bản/link) — ưu tiên
    đọc `bookmark.url` (link được ClickUp tự nhận diện, có preview) hoặc `attributes.link` (link kiểu
    hyperlink có text khác URL).
  - Nếu không tìm thấy qua segment có cấu trúc, fallback quét `comment_text` (text thô) bằng regex.
- `if (results.length === 0) return [...]`: nếu KHÔNG tìm thấy link nào, vẫn trả về 1 item "rỗng" —
  không để node bị bỏ qua hoàn toàn (0 item đầu ra sẽ khiến node sau bị skip, đã ghi trong RULES.md).

---

## Node `Build Notify Start` / `Build Notify Done` (Code)

**Vấn đề:** Cần soạn nội dung tin nhắn Telegram (HTML, có emoji, số liệu thống kê) TRƯỚC KHI gửi —
tách riêng bước "soạn nội dung" và "gửi tin" giúp dễ đọc/sửa hơn là viết logic ngay trong node Telegram.

**Ý tưởng giải quyết:** 1 Code node soạn sẵn `{chatId, text}`, node Telegram phía sau chỉ việc "đọc và
gửi", không cần logic gì thêm.

**Cách làm thực tế (`Build Notify Done`):**
```js
const cfg = $('⚙️ Config').first().json;
const chatId = cfg.notifyChatId || cfg.ADMIN_CHAT_ID;
const rows = $input.all().map(i => i.json);

const totalByList = {};
for (const r of rows) totalByList[r.list_name] = (totalByList[r.list_name] || 0) + r.cnt;

const statusEmoji = (status) => {
  const s = (status || '').toLowerCase();
  if (s.includes('xử lý')) return '⚙️';
  if (s.includes('ready') || s.includes('sẵn sàng')) return '✅';
  if (s.includes('lỗi')) return '❌';
  if (s.includes('chờ')) return '⏳';
  return '🔹';
};

let text = `✅ <b>Đồng bộ ClickUp → Postgres HOÀN TẤT</b>\n\n`;
for (const [listName, total] of Object.entries(totalByList)) {
  text += `📋 <b>${listName}</b>: <b>${total}</b> task\n`;
  rows.filter(r => r.list_name === listName)
      .forEach(r => { text += `   ${statusEmoji(r.status)} ${r.status || 'Không rõ'}: ${r.cnt}\n`; });
  text += `\n`;
}
text += `🕒 Kết thúc lúc: ${new Date().toLocaleString('vi-VN')}\n#full_reconcile_done`;
return [{ json: { chatId, text } }];
```
- `chatId = cfg.notifyChatId || cfg.ADMIN_CHAT_ID`: nếu Config có đặt `notifyChatId` riêng (gửi sang
  group khác) thì dùng, không thì mặc định gửi cho admin.
- `totalByList`: object dùng làm "bảng đếm" — gom số lượng task theo TỪNG List (dù hiện tại thường
  chỉ có 1 List, viết tổng quát để hỗ trợ nếu sau này có nhiều List cùng lúc).
- `statusEmoji(status)`: hàm nhỏ chọn emoji phù hợp dựa trên TỪ KHOÁ trong tên trạng thái — chỉ mang
  tính trang trí cho tin nhắn dễ đọc.
- Vòng lặp `for (const [listName, total] of Object.entries(totalByList))`: với mỗi List, in ra tổng
  số task, rồi lồng thêm 1 vòng lặp `.filter().forEach()` liệt kê chi tiết theo từng status.

---

## Ghi chú chung về Postgres node (không phải Code, nhưng quan trọng)

Các node Postgres (`Upsert Postgres (main)`, `Ghi Task Links Mới`, `Kiểm Tra Link Có Sẵn`, `Update
Link vào Postgres`...) đều dùng cơ chế **tham số hoá** (`$1`, `$2`...) qua `queryReplacement` — đây là
cách AN TOÀN để chèn giá trị động vào câu SQL (tránh SQL injection, tự động xử lý escape ký tự đặc
biệt như dấu nháy). `queryReplacement` LUÔN phải là 1 MẢNG, kể cả chỉ có 1 giá trị:
`={{ [$json.x] }}` — thiếu dấu `[ ]` là lỗi hay gặp nhất trong dự án này.
