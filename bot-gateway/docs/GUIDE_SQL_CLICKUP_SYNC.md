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

## `SQL_ClickUp_Live_Update.json` — Cấu hình

### Cách hoạt động
- Kích hoạt (Active) workflow — bắt buộc, vì đây là webhook trigger, không dùng "Test workflow" được.
- `ClickUp Trigger` đăng ký webhook cho toàn bộ Space `90183192291`, lắng nghe 3 sự kiện:
  `taskUpdated`, `taskCommentPosted`, `taskCommentUpdated`.
- Field thường đổi (status/name/description) → UPDATE thẳng cột đó, dùng giá trị có sẵn trong webhook
  (`history_items[].after`) — KHÔNG gọi lại ClickUp API.
- Custom field / comment đổi → gọi lại Get Comments để trích link mới.

### ⚠️ Hạn chế đã biết — cần payload thật để hoàn thiện
`FIELD_TO_COLUMN` trong node "Phân tích Webhook Payload" hiện chỉ map được `status/name/description`.
Custom field trong `history_items` trả về dạng ID/uuid — cần 1 payload webhook thật (sửa thử 1 custom
field trên ClickUp, xem Execution log) để hoàn thiện map này.

## Quy tắc chung khi debug 2 workflow này
- Sửa nhỏ đang test: chỉ dán từng node vào canvas n8n, không import lại cả file.
- Sau khi user xác nhận chạy ổn: Claude commit lên GitHub, cập nhật CHANGELOG + PROJECT_STATUS.
