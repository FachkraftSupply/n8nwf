# CHANGELOG — Bot Gateway (bàn giao sang phiên chat mới đọc `docs/PROJECT_STATUS.md`)

Ghi theo ngày, mới nhất lên trên. Chỉ ghi thay đổi có ý nghĩa (workflow/schema/kiến trúc),
không ghi từng lần sửa lỗi vặt trong 1 phiên debug — xem chi tiết trong PROJECT_STATUS.md
nếu cần.

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
