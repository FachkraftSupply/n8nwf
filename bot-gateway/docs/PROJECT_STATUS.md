# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm được ngữ cảnh
> mà không cần lại lịch sử debug dài ở phiên trước.
> Lịch sử thay đổi chi tiết theo ngày: xem `docs/CHANGELOG.md`.
> Hướng dẫn vận hành chi tiết SQL ClickUp Sync (Full Reconcile + Live Update): xem `docs/GUIDE_SQL_CLICKUP_SYNC.md`.

## Repo
`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua Composio (OAuth, không dùng token).

## Cấu trúc repo hiện tại
```
bot-gateway/
├── README.md
├── docs/
│   ├── CHANGELOG.md          <- lịch sử thay đổi chi tiết theo ngày
│   ├── PROJECT_STATUS.md     <- file này
│   ├── ARCHITECTURE.md, BOT_INVENTORY.md, GUIDE_DEPLOY_DATABASE.md, SETUP_PHASE_0_1.md
│   ├── GUIDE_SQL_CLICKUP_SYNC.md    <- huong dan van hanh Full Reconcile + Live Update
├── sql/
│   ├── 01_gateway_schema.sql
│   └── 02_clickup_tasks_schema.sql
├── original/                 5 workflow production NGUYÊN BẢN (tham khảo, không sửa)
│   └── Telebot_sql.json      <- QUAN TRỌNG: mẫu tham số ClickUp node ĐÚNG (xem bên dưới)
└── workflows/new_architecture/
    ├── GW_Gateway_Telegram.json       (Gateway, đang chạy trên bot DEV)
    ├── GW_Error_Handler.json
    ├── SQL_ClickUp_Full_Reconcile.json    <- ✅ HOÀN TẤT (21 node, có chống rate-limit)
    ├── SQL_ClickUp_Live_Update.json       <- ⚠️ CHƯA TEST, khả năng cần fix giống Full Reconcile
    └── sub_workflows_modernized/
        ├── Elite_Help_Bot_GPT.json        (✅ nhận Envelope, chờ Workflow ID để gắn Gateway)
        ├── Telebot_ClickUp_Reader.json    (✅ đã deploy, đọc/tìm task + xem file OneDrive)
        └── Telebot_main.json              (⚠️ KHÔNG dùng nữa, giữ tham khảo logic xử lý ảnh)
```

## QUY TẮC LÀM VIỆC (áp dụng cho mọi phiên chat)
- Sửa file JSON lớn: dùng Composio remote workbench (fetch GitHub → sửa Python trong sandbox → commit),
  không dán nguyên workflow vào chat.
- **Khi đang debug/thử nghiệm 1 thay đổi:** KHÔNG tự động commit vào file chính trên GitHub. Chỉ đưa
  nội dung node cần sửa (JSON đầy đủ nếu node thường, chỉ code nếu Code node) để user tự copy/paste
  test trong n8n. Chỉ commit sau khi user xác nhận chạy ổn.
- Thay đổi lớn/rủi ro cao: cân nhắc commit thành file `_v2`/`_wip` riêng trước, merge vào file chính
  sau khi xác nhận — tránh phải rollback file đang dùng.
- Khi rút gọn/đơn giản hoá 1 workflow: LUÔN đối chiếu checklist tính năng bản trước để không bỏ sót
  (từng quên node Notify Start khi đơn giản hoá SQL sync — xem CHANGELOG 2026-09-05).
- Luôn cập nhật CHANGELOG.md + file này sau khi 1 thay đổi được xác nhận thành công.

## ⚠️ GHI NHỚ KỸ THUẬT QUAN TRỌNG NHẤT (tránh lặp lại lỗi đã tốn nhiều vòng debug)

**Node ClickUp native trên n8n của user dùng THAM SỐ PHẲNG, không phải resource-locator.**
```js
// ĐÚNG (đã xác nhận chạy ổn, xem original/Telebot_sql.json node "lay task"/"lay comment1"):
{ team: "9018351620", space: "90183192291", folderless: true, list: "={{ $json.id }}" }
{ resource: "comment", operation: "getAll", commentsOn: "task", id: "={{ $json.id }}", limit: 50 }
// SAI (gây lỗi liên tục trước đây):
{ team: {"__rl": true, "value": "...", "mode": "id"} }  // resource-locator - KHÔNG dùng cho instance này
```
- `ClickUp - Get Comments` KHÔNG tự lặp qua nhiều item — bắt buộc bọc trong `SplitInBatches(batchSize=1)`.
- Link OneDrive/Youtube trong comment ClickUp: đọc CẢ `comment[].bookmark.url` LẪN `comment[].attributes.link`
  (2 nguồn khác nhau tùy cách dán link) + regex trên `comment_text` làm fallback cuối.
- ClickUp đã đổi định dạng Task ID (số → chữ+số, vd `z908826jhz`) — luôn để cột `id` trong Postgres là
  `TEXT` không giới hạn.
- `gateway.config` là bảng key-value (`key`, `value`), KHÔNG có cột riêng `admin_chat_id` — query đúng:
  `SELECT value AS admin_chat_id FROM gateway.config WHERE key = 'admin_chat_id'`.
- Code node mặc định "Run Once for All Items" — nếu code viết theo kiểu xử lý từng item (`$json`,
  `return {json:{...}}`), PHẢI set `"mode": "runOnceForEachItem"` trong parameters, nếu không chỉ xử
  lý được 1 item dù đầu vào nhiều hơn.
- `SplitInBatches` output "done" (index 0) trả về TOÀN BỘ item gốc đã đưa vào loop (không phải 1 tín
  hiệu đơn) — nếu nối thẳng sang bước gửi Telegram sẽ lặp/dài tin nhắn, cần chèn `Limit(maxItems=1)`
  trước bước thông báo cuối cùng.

## Trạng thái hiện tại theo Phase (roadmap đầy đủ ở ARCHITECTURE.md mục 8)
| Phase | Việc | Trạng thái |
|---|---|---|
| 0-1 | Schema DB + Gateway + Error Handler | ✅ Xong (7/7 test) |
| 2 | Help Bot GPT nhận Envelope | ✅ Code xong, ⏳ chờ Workflow ID thật để gắn Gateway |
| 2b | Telebot ClickUp Reader (đọc/tìm task + xem file) | ✅ Đã deploy, chờ gắn Workflow ID vào Gateway |
| 2c | SQL Sync ClickUp ↔ Postgres | ✅ Full Reconcile HOÀN TẤT (kèm chống rate-limit); 🔵 Live Update (webhook) ĐANG TEST |
| 3 | Backup Postgres → OneDrive (Phương án B — SQL export thuần n8n) | Chưa bắt đầu |
| 3 | Chuyển Crawl Bot | Chưa bắt đầu |
| 4 | Cutover Gateway sang bot PROD | Chưa bắt đầu |
| — | Bot System Main (xử lý ảnh, tách từ Telebot_main.json cũ) | Chưa bắt đầu |
| — | Tính năng mới: `/sync` admin-only chọn Folder/List qua Telegram, tự lưu để auto-sync | 🟡 CODE XONG (`Telebot_ClickUp_Reader_v2_with_sync.json`, 45 node), CHƯA TEST — làm sau |
| — | Rate-limit khi Full Reconcile lấy comment (nhiều task) | 🔵 Đang thiết kế (xem chat 05/09/2026) |

## CHECKLIST — Việc tiếp theo (theo thứ tự ưu tiên)
1. **Đang làm**: test `SQL_ClickUp_Live_Update.json` (đã fix tham số phẳng cho ClickUp Trigger, commit
   0f78891) — active workflow, thử sửa 1 task/comment trên ClickUp, xem execution + Postgres +
   Telegram.
3. Hoàn thiện tính năng `/sync` (đã code xong, CHƯA TEST — file
   `Telebot_ClickUp_Reader_v2_with_sync.json`):
   - Test 3 bước: chọn Folder → chọn List → lưu `clickup.sync_targets`.
   - Thêm Execute Workflow Trigger vào `SQL_ClickUp_Full_Reconcile.json` để nhận `list_id` truyền từ
     nút "Đồng bộ ngay" (hiện `Execute Full Reconcile` đang để `workflowId` placeholder).
   - Sau khi ổn: merge đè lên `Telebot_ClickUp_Reader.json` chính, xoá file `_v2_with_sync`.
4. Cung cấp Workflow ID thật (n8n live) cho Help Bot GPT + Telebot ClickUp Reader để gắn vào Gateway.
5. Khi rảnh: Bot System Main (xử lý ảnh) và Backup Postgres → OneDrive (Phase 3).
