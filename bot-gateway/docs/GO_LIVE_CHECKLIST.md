# CHECKLIST GO-LIVE — Đổi Credential khi Cutover sang Bot PROD (Giai đoạn 4)

Dùng file này khi chính thức chuyển từ bot DEV (`@elite_n8n_test_bot`) sang bot PROD
(`@Elite_clickup_bot`) — soát từng dòng, tick xong mới chuyển dòng tiếp theo.

> Lý do phải đổi tay từng node: n8n KHÔNG cho gán credential động qua expression (giới hạn nền tảng,
> không phải do thiết kế) — token bot phải chọn cố định trong dropdown ở mỗi node. Xem thêm ở
> `docs/GUIDE_SQL_CLICKUP_SYNC.md` / lịch sử trong `CHANGELOG.md` (06/09/2026) nếu muốn tự động hoá
> sau này bằng cách nhân đôi node + IF theo Config (Phương án A đã thảo luận).

---

## 1. `GW_Gateway_Telegram.json`

- [ ] Node **`Telegram Trigger Gateway`** — đổi credential từ bot DEV sang bot PROD.
- [ ] **10 node reply/notify sau đây** — TẤT CẢ phải dùng ĐÚNG credential bot PROD giống Trigger ở trên
      (không được để lẫn bot, nếu không phản hồi sẽ gửi nhầm bot):
  - `Báo user chờ duyệt`
  - `Báo admin duyệt user`
  - `Nhắc đang chờ duyệt`
  - `Thông báo từ chối`
  - `Không có quyền bot này`
  - `Hướng dẫn lệnh`
  - `Xác nhận với admin`
  - `Báo user được duyệt`
  - `Báo user bị từ chối`
  - `Bỏ qua (không phải admin)`
- [ ] Node **`⚙️ Config`**: kiểm tra lại `ADMIN_CHAT_ID` vẫn đúng (thường không đổi khi cutover).

## 2. `Telebot_ClickUp_Reader.json`

- [ ] Node **`⚙️ Config`**: đổi `USE_PROD_BOT` từ `false` → `true` (dòng đầu code) — việc này tự động
      sửa link deep-link (`botUsername`) trong toàn bộ tin nhắn tìm kiếm/chi tiết task/sync, KHÔNG cần
      sửa code ở đâu khác.
- [ ] **11 node Telegram sau đây** — đổi credential sang bot PROD:
  - `Reply Unknown Command`
  - `help`
  - `no content in task command`
  - `Telegram` (dùng chung cho nhánh tìm task + chi tiết task)
  - `Reply Taotask Placeholder`
  - `Reply Không Có Quyền`
  - `Telegram - Danh sách Folder`
  - `Telegram - Danh sách List`
  - `Telegram - Hỏi Đồng Bộ`
  - `Reply Đang Đồng Bộ`
  - `Reply Chờ Lần Sau`
- [ ] Node **`Execute Full Reconcile`**: xác nhận `workflowId` vẫn trỏ đúng workflow Full Reconcile
      (không đổi theo bot, chỉ xác nhận không bị mất khi import).
- [ ] Credential ClickUp + Postgres: KHÔNG đổi (không liên quan tới bot Telegram nào).

## 3. `SQL_ClickUp_Full_Reconcile.json`

- [ ] Node **`Notify Start`** và **`Notify Done`**: dùng credential **Telegram System Bot**
      (`@elite_n8n_system_bot`) — đây là bot THÔNG BÁO NỀN, tách biệt hoàn toàn khỏi bot DEV/PROD của
      Gateway. **KHÔNG cần đổi khi cutover Gateway.**
- [ ] Node **`⚙️ Config`**: xác nhận `notifyChatId` (để trống = lấy từ `gateway.config.admin_chat_id`)
      vẫn đúng người nhận khi go-live.
- [ ] Xác nhận `testMode: false` trước khi chạy live thật (không giới hạn `testTaskLimit`).

## 4. `SQL_ClickUp_Live_Update.json`

- [ ] Node **`Notify`**: dùng credential **Telegram System Bot** — tương tự Full Reconcile,
      **KHÔNG cần đổi khi cutover Gateway.**
- [ ] Node **`⚙️ Config (Admin Chat ID)`**: xác nhận `ADMIN_CHAT_ID` đúng.
- [ ] Xác nhận workflow đã **Active** (bắt buộc cho webhook trigger, không dùng "Test workflow" được).

## 5. `Elite_Help_Bot_GPT.json`

- [ ] Xác nhận Workflow ID thật đã gắn đúng vào node `→ Sub: Help Bot` trong Gateway.
- [ ] Kiểm tra credential Telegram (nếu sub-workflow này có tự gửi tin trực tiếp, không qua Gateway trả
      lời) — đổi sang bot PROD nếu có.

---

## Tổng kết nhanh — 3 loại bot, không được nhầm lẫn

| Bot | Dùng cho | Đổi khi cutover? |
|---|---|---|
| `@elite_n8n_test_bot` (DEV) | Gateway + mọi sub-workflow user-facing khi đang test | ✅ Đổi sang PROD |
| `@Elite_clickup_bot` (PROD) | Gateway + sub-workflow khi đã go-live chính thức | (là đích đến) |
| `@elite_n8n_system_bot` (System) | Thông báo NỀN (SQL sync Full Reconcile/Live Update) | ❌ Không đổi, luôn cố định |

**Cách xác nhận đã đổi đúng (không cần đoán):** sau khi đổi 1 node, chạy thử, mở Output của node
Telegram đó, kiểm tra `result.from.username` — phải khớp đúng tên bot mong muốn cho node đó.
