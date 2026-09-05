# GUIDE — SQL ClickUp Sync (Full Reconcile + Live Update)

Hướng dẫn vận hành 2 workflow đồng bộ dữ liệu `clickup.tasks` trong Postgres từ ClickUp.
Xem `PROJECT_STATUS.md` để biết trạng thái hiện tại, `CHANGELOG.md` cho lịch sử thay đổi.

## Tổng quan kiến trúc

| | `SQL_ClickUp_Full_Reconcile.json` | `SQL_ClickUp_Live_Update.json` |
|---|---|---|
| Trigger | Schedule (5 ngày/lần, 1h sáng) + Manual (test) | ClickUp Trigger (webhook, real-time) |
| Mục đích | Quét lại TOÀN BỘ 1 List, đảm bảo dữ liệu đầy đủ/đồng nhất | Cập nhật NGAY khi có thay đổi trên ClickUp, không cần chờ 5 ngày |
| Cách lấy field thường | Gọi lại ClickUp API (Get Tasks) | Đọc thẳng từ `history_items` trong webhook, KHÔNG gọi lại API |
| Cách lấy link OneDrive/Youtube | Gọi Get Comments cho từng task | Gọi lại Get Comments khi có sự kiện comment |

## `SQL_ClickUp_Full_Reconcile.json` — Cấu hình

### Node `⚙️ Config` — các giá trị cần biết
```js
team_id: "9018351620"       // Workspace ID
space_id: "90183192291"     // Space ID (xác nhận từ dữ liệu ClickUp thật, KHÔNG phải List/Team ID)
list_id: "901812218309"     // List đang đồng bộ — ĐỔI giá trị này để chuyển sang List khác

testMode: true / false      // true = giới hạn testTaskLimit task để test nhanh
                             // false = lấy ĐẦY ĐỦ (returnAll) — dùng khi chạy thật
testTaskLimit: 5            // chỉ áp dụng khi testMode=true

notifyChatId: ""            // để trống = gửi thông báo tới admin_chat_id (gateway.config)
                             // điền vào = ghi đè, gửi sang group Telegram khác

fieldNameMap: { ... }       // map tên cột Postgres -> tên custom field THẬT trong ClickUp
                             // (không phải ID field) — sửa nếu List khác có tên field khác
```

### Bật/tắt Test Mode
Đổi `testMode: true` ↔ `false` trong node Config. Không cần sửa gì khác — `returnAll` và giới hạn
task đều tự động theo giá trị này.

### Chuyển sang đồng bộ List khác
Đổi `list_id` trong Config sang List ID mới (xem trên URL ClickUp: `.../v/li/<list_id>` hoặc
`.../v/f/<folder_id>/<list_id>`). Kiểm tra lại `fieldNameMap` nếu List đó dùng tên custom field khác.

> Việc chọn nhiều List tự động (không cần sửa Config tay) đang được xây dựng qua lệnh `/sync` trên
> Telegram — xem mục "Việc tiếp theo" trong PROJECT_STATUS.md.

### Chống Rate Limit khi lấy comment (ClickUp giới hạn 100 request/phút)
```
Loop Over Tasks (loop) → Kiểm Tra Link Có Sẵn (SELECT Postgres)
  → Đã Có Đủ Link?
      true  → bỏ qua, quay về Loop (task đã có sẵn cả 2 link từ lần sync trước, không cần gọi lại)
      false → Nghỉ 700ms → ClickUp - Get Comments (Retry On Fail: 3 lần, chờ 5s/lần)
             → Trích Link → Update Link → quay về Loop
```
Lần sync đầu tiên vẫn quét hết (DB đang trống), nhưng từ lần thứ 2 trở đi chỉ gọi API cho task MỚI
hoặc task CHƯA có đủ link — giảm mạnh số lượng request.

### ⚠️ Lưu ý quan trọng về node ClickUp native
Node ClickUp trên n8n instance này dùng **tham số phẳng** (`team: "..."`), KHÔNG dùng
resource-locator (`{__rl:true,...}`). Nếu copy node ClickUp từ chỗ khác/thêm node mới, PHẢI theo
đúng format này — xem ví dụ thật trong `original/Telebot_sql.json` (node "lay task"/"lay comment1").

### Sơ đồ đầy đủ
```
Manual/Schedule → Config → Ensure Schema (ALTER COLUMN, tự thêm cột thiếu, bật pg_trgm)
  → Notify Start → ClickUp Get Tasks
      → Map Row → Upsert Postgres (main)
      → Loop Over Tasks → Kiểm Tra Link Có Sẵn → Đã Có Đủ Link? → [Wait → Get Comments →
        Trích Link → Update Link] → (quay lại Loop)
  → (khi Loop xong) → Limit(1) → Lấy Admin Chat ID → Query Thống Kê → Build Notify Done → Notify Done
```

## `SQL_ClickUp_Live_Update.json` — Cấu hình (✅ HOÀN TẤT, 9 node)

### Giới thiệu
Webhook real-time từ ClickUp — mỗi khi 1 task trong Space `90183192291` thay đổi (status, tên, mô tả,
custom field, thêm phụ trách, hoặc có comment mới), workflow này nhận diện loại thay đổi, **ghi đè trực
tiếp vào Postgres** (không phải chờ Full Reconcile 5 ngày/lần) và **gửi thông báo Telegram** ngay lập tức.
Đã đơn giản hoá mạnh: từ bản đầu 36 node (Switch + 24 node Update riêng từng cột) xuống còn **9 node**,
bằng cách build tên cột UPDATE **động** trong 1 câu query duy nhất (an toàn vì cột luôn lấy từ danh sách
cố định kiểm soát trong code, không phải input tự do).

### Sơ đồ
```
ClickUp Trigger (Live)
  → ⚙️ Config (Admin Chat ID)          [Code — dien tay ADMIN_CHAT_ID, KHONG doc Postgres]
  → Nhận Diện & Format Thay Đổi        [Code — doc $('ClickUp Trigger (Live)').first().json,
                                         co the ra NHIEU item, 1 item = 1 thay doi]
  → Có Thay Đổi Cần Theo Dõi?          [If: skip? true → (khong lam gi, co chu dich)
                                              false → di tiep]
  → Có Cột Cần Ghi DB?                 [If: column co gia tri?
        true  → Ghi Đè Postgres        (UPDATE ten cot DONG + RETURNING id,name,url)
        false → Lấy Thông Tin Task     (SELECT thuong, vd truong hop 'comment' khong co link)]
  → (2 nhánh hội tụ) Build Thông Báo   [Code — mode "Run Once for Each Item" BAT BUOC]
  → Notify                             [Telegram]
```

### 6 loại thay đổi nhận diện được (dựa theo `history_items[].field` từ webhook thật)

| `field` trong webhook | Cột Postgres ghi đè | Cách hiển thị trong thông báo |
|---|---|---|
| `comment` (có link OneDrive/Youtube) | `onedrive_link` / `youtube_link` | Link tìm được (đọc cả `comment[].attributes.link` lẫn `.bookmark.url`, fallback regex `text_content`) |
| `comment` (không có link) | *(không ghi DB)* | "Có comment mới trên task" |
| `content` (mô tả) | `description` | Text đã parse từ Quill Delta `{"ops":[...]}`, cắt 200 ký tự |
| `custom_field` | Tra theo `custom_field.name` qua `CUSTOM_FIELD_TO_COLUMN` | Tên field thật + giá trị mới |
| `assignee_add` | `phu_trach` | Username người được gán |
| `name` | `name` | Tên task mới |
| `status` | `status` | `<trạng thái cũ> ➜ <trạng thái mới>` |

Field khác (`due_date`, `priority`, `assignee_rem`...) không nằm trong danh sách → bỏ qua, không thông báo.

### Cấu hình Admin Chat ID
Node `⚙️ Config (Admin Chat ID)` — **không còn** query `gateway.config` qua Postgres (đã bỏ theo yêu cầu,
tránh lỗi kết nối). Sửa thẳng 1 dòng trong code:
```js
const ADMIN_CHAT_ID = "975005174"; // doi gia tri nay neu can gui sang chat/group khac
```

### ⚠️ Các lỗi đã gặp khi build + cách đã sửa (tham khảo nếu tái phát)
1. **`httpRequestWithAuthentication` không hỗ trợ trong Code node** trên instance này — đã đổi sang đọc
   trực tiếp `history_items[].comment` (payload webhook ĐÃ có sẵn toàn bộ nội dung comment mới, không
   cần gọi lại API).
2. **"No connection back to node"** — do 1 node (Lay Admin Chat ID cũ) nằm ở nhánh song song thay vì nối
   tuần tự. Bài học: mọi node được tham chiếu qua `$('TenNode')` PHẢI nằm trên đường nối thật tới node
   gọi nó, không chỉ "chạy cùng execution".
3. **"Multiple matches" / chỉ xử lý được 1 item dù nhiều item vào`** — do quên set
   `"mode": "runOnceForEachItem"` cho Code node viết theo kiểu xử lý từng item. Áp dụng cho cả
   `Nhận Diện & Format Thay Đổi` và `Build Thông Báo`.
4. **`Split Out Updates` bị dừng không lý do** (bản cũ) — do `field: "custom_field"` không được nhận diện
   (code cũ chỉ biết `status/name/content`). Đã sửa đọc `history_items[].custom_field.name` (có sẵn
   trong payload) thay vì cố map theo `field` (luôn là chuỗi cố định `"custom_field"`).

### Cách hoạt động chung (áp dụng mọi lần sửa)
- Kích hoạt (Active) workflow — bắt buộc, vì đây là webhook trigger, "Test workflow" không hoạt động.
- Đang sửa nhỏ để test: chỉ dán từng node vào canvas n8n, không import lại cả file.
