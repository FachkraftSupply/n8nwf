# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để nắm được trạng thái hiện tại mà
> không cần đọc lại lịch sử debug dài của các phiên trước — file này chỉ giữ TRẠNG THÁI HIỆN TẠI,
> không giữ tường thuật quá trình (tường thuật đầy đủ nằm ở `docs/CHANGELOG.md`, mới nhất lên trên).
>
> **Trước khi sửa bất kỳ workflow nào**: đọc `docs/RULES.md` — đặc biệt mục 12-15 (publish sau khi
> update, tên tham số đúng cho addConnection, batch rollback, bẫy inlineKeyboard động). Đây là 4
> nguyên nhân gây bug im lặng đã gặp NHIỀU LẦN, không phải lý thuyết suông.
>
> Tài liệu khác: `docs/ARCHITECTURE.md` (thiết kế hệ thống + mục 9 nợ kỹ thuật/refactor),
> `docs/GUIDE_SQL_CLICKUP_SYNC.md` (vận hành sync), `docs/GO_LIVE_CHECKLIST.md`,
> `docs/FEATURE_CATALOG.md` (bảng đầy đủ tính năng theo từng bot), `docs/FAQ.md`.
>
> **⚠️ Rủi ro đã xảy ra thật**: 2 phiên chat khác nhau từng sửa CÙNG 1 workflow song song mà không
> biết về nhau, gây lệch dữ liệu (xem CHANGELOG 09/09/2026). Nếu thấy `nodeCount`/`connections` khác
> con số bạn nhớ — ĐỪNG cho là mình nhớ nhầm, hãy đọc lại file này (bản mới nhất trên GitHub, không
> tin bộ nhớ hội thoại) trước khi sửa tiếp.

## 🟡 MỚI (09/09/2026, phiên tiếp) — Mirror thông báo Upload OneDrive sang nhóm Zalo

Đã đọc tài liệu `https://bot.zapps.me/docs` — API Bot Zalo có cấu trúc gần giống hệt Telegram Bot
API: `POST https://bot-api.zaloplatforms.com/bot<BOT_TOKEN>/sendMessage`, body
`{chat_id, text, parse_mode: "markdown"|"html"}`, token nằm ngay trong URL (không phải header).

**Đã build xong (workflow `Telebot ClickUp Reader`, `9JJRrh36H2rLwtnu`)**: khi admin bấm nút forward
thông báo Upload OneDrive vào 1 trong 3 nhóm Telegram (🏛️ Kammer/BAV, 🧾 Hóa đơn, 📄 Giấy tờ khác),
workflow giờ CŨNG gửi thêm cùng nội dung đó sang 1 nhóm Zalo tương ứng (nếu có cấu hình) — cơ chế
best-effort, không chặn luồng chính nếu gọi Zalo lỗi.
- Bảng `gateway.notify_targets` có thêm cột `zalo_chat_id` (tự tạo qua node "Ensure Zalo Notify
  Column", cũng có ghi lại ở `sql/07_gateway_notify_targets_zalo.sql`).
- Node mới: `Has Zalo Target?` (IF, chỉ chạy tiếp nếu `zalo_chat_id` có giá trị) → `Send Zalo
  Notify` (HTTP Request, `onError: continueRegularOutput`).
- **CHƯA thể test/hoạt động thật vì thiếu 2 thứ, cần user cung cấp:**
  1. **Zalo Bot Token** — tạo bot qua Zalo Bot Creator (`bot.zapps.me`) rồi lấy token. **KHÔNG dán
     token vào chat với Claude** — thêm biến môi trường `ZALO_BOT_TOKEN=<token>` vào docker-compose
     của n8n (cùng chỗ với các biến môi trường khác của container n8n trên VPS) rồi restart
     container n8n. Node `Send Zalo Notify` đã trỏ sẵn tới `{{ $env.ZALO_BOT_TOKEN }}` — chỉ cần
     set đúng tên biến này là chạy được ngay, không cần sửa lại workflow.
  2. **Zalo group chat_id** cho từng category (Kammer/BAV, Hóa đơn, Giấy tờ khác) — sau khi thêm
     bot vào nhóm Zalo và nhắn thử 1 tin, có thể lấy chat_id qua Zalo Bot Creator dashboard hoặc
     gọi `getUpdates`. Cho tôi biết chat_id (không phải bí mật, có thể gửi thẳng trong chat) để
     tôi `UPDATE gateway.notify_targets SET zalo_chat_id = '...' WHERE target_key = '...'` — xem
     câu lệnh mẫu trong `sql/07_gateway_notify_targets_zalo.sql`. Có thể dùng CHUNG 1 chat_id cho
     cả 3 category nếu chỉ có 1 nhóm Zalo, hoặc chat_id riêng từng nhóm nếu có nhiều nhóm.
- Việc còn lại sau khi có đủ 2 thứ trên: điền `zalo_chat_id`, gửi thử 1 lượt forward thật, xác nhận
  tin nhắn tới đúng nhóm Zalo với format hiển thị đúng (thẻ `<b>` HTML — cần xác nhận Zalo render
  đúng, tài liệu ghi hỗ trợ `parse_mode: html` nhưng chưa test thật).

## Trạng thái theo bot / workflow (09/09/2026)

| Bot / Workflow | Trạng thái | Ghi chú |
|---|---|---|
| **Gateway** (`GW Gateway - Telegram`, `xmEKeIUnzxm2F7dF`) | ✅ Hoạt động, PROD (`@Elite_clickup_bot`) | Auth, router, callback whitelist (`od_`, `odfwd_`, `odhelp`, `chitiet_`, `sync_`) |
| **Telebot ClickUp Reader** (`9JJRrh36H2rLwtnu`, chạy qua Gateway, `bot_key: telebot_main`) | ✅ Hoạt động đầy đủ · 🟡 Mirror Zalo MỚI build, chưa hoạt động | `/task`, chi tiết task, Upload OneDrive (chọn tên/preset/tùy chỉnh/giữ gốc, forward thông báo vào nhóm Telegram, `/cancel`) — TẤT CẢ đã user xác nhận chạy thật. Mirror thông báo forward sang nhóm Zalo — đã build, ĐANG CHỜ `ZALO_BOT_TOKEN` + `zalo_chat_id` từ user (xem mục ngay trên) |
| **Bot Xử Lý Ảnh** (`6I4MnJiJCiv2JOIr`, qua Gateway, `bot_key: image_bot`) | ✅ `/xoanen`, `/tomtat` hoạt động OK · ⏸️ AI xoá nền/upscale TẠM DEACTIVATE | Tính năng 🤖 AI xoá nền / 🔍 Upscale đã build xong nhưng đang **tạm tắt** (2 node `Call OpenRouter (...)` set `disabled`, 2 nút bấm đã gỡ khỏi tin nhắn kết quả) theo yêu cầu 09/09/2026 — chờ user tạo credential rồi bật lại. Xem mục checklist |
| **Telebot Admin System** (`eWtu7Qs85Hes0HuP`, bot riêng `@elite_n8n_system_bot`) | ✅ Hoạt động đầy đủ | `/task`, `/sync`, `/sync_status`, `/db_status`, `/backup_n8n`, `/backup_db`, `/version`, `/cancel`, `/user_list` (danh sách + panel quản lý quyền đầy đủ 13 route) |
| **SQL - ClickUp Full Reconcile** (`G1R0okF0rUziySu9`) | ✅ Hoạt động, đã fix DKPV/PVTC | Xem mục "DKPV/PVTC" bên dưới |
| **SQL - ClickUp Sync Scheduler** (`loCm8Tg8Sqfj7ygy`) | ✅ Hoạt động | Điều phối đa-List theo `clickup.sync_targets`, chạy mỗi 5 ngày |
| **SQL - ClickUp Live Update (Webhook)** (`uqTqjtHYieotPZuc`) | ✅ Hoạt động, đã fix 2 lỗi | Ghi đè Postgres real-time khi sửa trên ClickUp; thông báo → nhóm topic 2 |
| **SQL - Backup System** (`iVtOA9LEtjpLDkln`) | ✅ Hoạt động | `/backup_*` trả lời trực tiếp admin; chạy tự động (Chủ nhật 2h sáng) báo vào nhóm topic 6 |
| **GW Error Handler** (`34ccboHpyoY2r691`) | ✅ Hoạt động | Báo lỗi vào nhóm topic 4 + ghi `gateway.error_logs` |
| **GW Weekly Error Report** (`ZJvP7L2aVPpeCGGW`, MỚI) | 🟡 Đã build, CHƯA test thật | Thứ 2 8h sáng, DM admin — xem checklist |
| **Help Bot GPT** | ⏳ Code xong, CHƯA gắn Gateway | Chờ Workflow ID thật (placeholder `REPLACE_HELP_BOT_ID`) |
| ~~Crawl Bot (khái niệm lệnh `/crawl`)~~ | ❌ Lệnh đã bỏ hẳn (09/09/2026) | `/crawl` không còn tồn tại. Nhưng Ý TƯỞNG "bot lắng nghe + ghi Postgres" đã tách thành workflow riêng `GW Crawl Bot - Group Capture` (dùng credential `Elite Crawl Bot`) — xem dòng "Nhóm chat capture" bên dưới |
| **Nhóm chat capture + tóm tắt AI** | 🟡 Điều kiện tiên quyết ĐÃ XONG (Privacy Mode tắt + bot đã vào nhóm) — CHƯA test qua Telegram thật | Ghi log giờ do workflow RIÊNG `GW Crawl Bot - Group Capture` (`SNNrXneenXVnLHh6`, bot `Elite Crawl Bot`) đảm nhiệm — nhánh ghi log cũ trong Gateway (bot Elite Clickupbot) đã bị `disabled` để tránh ghi trùng 2 lần/tin nhắn. Tóm tắt hàng đêm (`GW Daily Chat Summary`, DeepSeek) + retention tự động (raw message giữ 14 ngày, bảng tóm tắt giữ 365 ngày). `/lichsu`/`/timkiem` dạng bấm nút 3 bước (Admin System = mọi nhóm; ClickUp Reader = filtered theo user) + `/sum` (chỉ ClickUp Reader). **Phiên sau: chạy tiếp Bước 1-4 trong mục "🧪 Hướng dẫn test" bên dưới** (test ghi log thật → tóm tắt đêm → `/lichsu` admin → `/lichsu`/`/timkiem`/`/sum` user có lọc) |

## ✅ Đã xác nhận SỬA XONG — Phương án A cho DKPV/PVTC (quyết định 09/09/2026)

Kiểm tra trực tiếp Postgres xác nhận **đã được triển khai đúng, không cần sửa gì thêm**:
- Khóa chính `clickup.task_links` hiện là `(student_task_id, order_task_id, link_type, year)` —
  cho phép 1 đơn hàng xuất hiện ở NHIỀU năm khác nhau (học sinh apply lại) mà không bị lỗi
  "duplicate key" như trước.
- Node `Trích Xuất Task Links` (trong `SQL_ClickUp_Full_Reconcile.json`) nhận diện CẢ `DKPV <năm>`
  lẫn `PVTC <năm>` bằng regex tự động, không hardcode tên field theo năm.
- Đã xác nhận 0 dòng trùng lặp thật trong bảng.

## 🔴 Việc còn tồn đọng thật sự (đã lọc bỏ mục đã xong/lỗi thời)

0. **⏸️ Tính năng AI xoá nền/upscale (Bot Xử Lý Ảnh) — TẠM DEACTIVATE 09/09/2026, chờ user rảnh
   quay lại.** Đã build xong node gọi OpenRouter Image API (`https://openrouter.ai/api/v1/images`,
   model `google/gemini-2.5-flash-image`, ~$0.0003/ảnh input + ~$0.00003/ảnh output — giá tra trực
   tiếp từ API OpenRouter, không đoán), nhưng 2 node `Call OpenRouter (AI Bỏ Xoá Nền)` và
   `Call OpenRouter (Upscale)` trong workflow `Bot Xử Lý Ảnh` (`6I4MnJiJCiv2JOIr`) đang bị
   `disabled: true` và 2 nút bấm dẫn tới chúng đã bị gỡ khỏi tin nhắn kết quả `/xoanen` (cả 2
   trường hợp thành công và remove.bg lỗi) — để tránh user bấm phải nút dẫn tới lỗi. **Lý do tạm
   dừng**: node HTTP Request gọi endpoint này CẦN 1 credential (Claude không tự tạo credential
   chứa API key được), và đã thử phương án dùng credential OpenRouter có sẵn (đang gán cho node
   model LangChain) qua `predefinedCredentialType` để đỡ phải tạo credential mới — **n8n từ chối
   thẳng**, vì credential loại `openRouterApi` chỉ đăng ký cho node LangChain, không dùng chung
   được với HTTP Request thường (xem CHANGELOG "tiếp 15"). Cũng đã xác nhận rõ **không thể** thay
   bằng cặp node `chainLlm` + `lmChatOpenRouter` (đầu ra của cặp node đó luôn là text, không có
   khả năng trả về binary ảnh — đã tra schema thật của n8n để xác nhận, không phải suy đoán).
   **Để làm tiếp khi rảnh**: (a) tạo 1 credential loại "Simplified Custom Auth"
   (`httpTemplatedCustomAuth`) tên gợi ý "OpenRouter HTTP", Auth Template
   `{"headers":{"Authorization":"Bearer {{api_key}}"}}`, dán OpenRouter API key vào ô secret;
   (b) gán credential đó vào ĐÚNG 2 node trên trong n8n UI; (c) bỏ `disabled: true` ở 2 node đó;
   (d) thêm lại 2 nút "🤖 Xoá nền bằng AI" / "🔍 Upscale cho sắc nét" vào 2 tin nhắn
   `Gửi Ảnh Đã Xóa Nền` và `Báo Lỗi Remove.bg` (cấu trúc nút cũ xem CHANGELOG "tiếp 14" hoặc git
   history workflow). **CHƯA test thật** lượt nào (trigger callback không execute được qua MCP).
1. **Nhóm chat capture + tóm tắt AI** — đã build xong toàn bộ 3 phần (ghi log, tóm tắt đêm, lệnh
   xem lại có bấm nút cho cả admin lẫn user thường) nhưng **CHƯA test qua Telegram thật lượt nào**.
   Xem mục "🧪 Hướng dẫn test" ngay bên dưới để biết chính xác cách test và các điểm rủi ro cần
   để ý (đặc biệt bộ lọc theo user, tránh lộ chat nhóm khác).
2. **`GW Weekly Error Report`** (mới tạo 09/09/2026) — chưa test thật qua Telegram (chạy thử sẽ gửi
   tin nhắn thật cho admin nên chưa tự chạy). Cần user tự bấm "Execute workflow" trong n8n để xem
   trước, hoặc đợi tới Thứ 2 tới. **Bổ sung 09/09/2026**: giờ có thể test tương đương ngay lập tức
   qua `/error_logs` (xem, không đổi DB) hoặc `/error_log_now` (xem + đánh dấu `status='reported'`)
   ở Admin System — không cần đợi Thứ 2 hay vào n8n UI nữa. Cả 2 lệnh đều kèm sẵn 1 prompt copy
   thẳng vào Claude Code để bắt đầu sửa lỗi ngay (có context repo + docs cần đọc trước, không cần
   dò lại toàn bộ dự án). **CHƯA test qua Telegram thật lượt nào** (cùng lý do: Trigger không
   execute được qua MCP).
3. **Help Bot GPT** — code đã viết, chưa gắn vào Gateway vì chưa có Workflow ID thật.
4. **`restore.sh`** (script khôi phục thảm họa) — chưa test trên 1 n8n instance trống thật sự.

> **Đã đóng hẳn 09/09/2026** (không còn theo dõi):
> - "Nền trắng"/"chèn logo" cho Bot Xử Lý Ảnh — user xác nhận không cần thiết ở thời điểm này,
>   chưa từng build gì nên không cần dọn workflow.
> - **Crawl Bot** — user xác nhận ý tưởng ban đầu của nó (bot lắng nghe tin nhắn nhóm/topic + lưu
>   Postgres) **chính là** tính năng "Nhóm chat capture" ở mục 1 — không phải 2 việc khác nhau.
>   Việc capture đã chạy ngay trong `GW Gateway - Telegram` (nhánh `Là Tin Nhắn Nhóm?` → `Ghi Log
>   Tin Nhắn Nhóm`, áp dụng cho MỌI nhóm bot có mặt, không cần sub-workflow riêng) — nên không cần
>   xây gì thêm. Đã dọn: bỏ `sum`/`crawl` khỏi `COMMAND_MAP` và bỏ `crawl_bot` khỏi
>   `AVAILABLE_BOTS` (2 lệnh này trước đó route vào node `→ Sub: Crawl Bot` đang bị disabled →
>   im lặng không phản hồi gì, một bug nhỏ chưa ai báo — giờ sẽ trả lời "❓ Lệnh không hợp lệ" tử
>   tế thay vì im lặng). Node `→ Sub: Crawl Bot` giữ nguyên (đã disabled từ trước, vô hại, không
>   xoá để tránh động vào `Switch (Route bot?)` không cần thiết.

> Đã bỏ hẳn (không còn theo dõi): ý tưởng "nền trắng"/"chèn logo" cho Bot Xử Lý Ảnh — user xác
> nhận 09/09/2026 là không cần thiết ở thời điểm này, chưa từng build gì nên không cần dọn workflow.

## 🧪 Hướng dẫn test tính năng MỚI (09/09/2026) — Nhóm chat capture + `/lichsu` + `/timkiem`

Tính năng này gồm 3 phần liên kết: (1) ghi log tin nhắn nhóm, (2) tóm tắt AI hàng đêm, (3) lệnh
xem lại có bấm nút. Cả 3 đã publish nhưng **chưa ai test qua Telegram thật** — Trigger không
execute được qua MCP nên phần này bắt buộc phải test tay. Làm đúng thứ tự dưới đây.

### Bước 0 — Điều kiện tiên quyết (bắt buộc, làm trước tất cả) — ✅ ĐÃ XONG (09/09/2026)

1. ✅ Đã tắt Privacy Mode qua @BotFather cho bot **`Elite Crawl Bot`** (KHÔNG PHẢI Elite Clickupbot
   — từ 09/09/2026 việc ghi log đã tách sang bot riêng này, xem CHANGELOG "tiếp 21").
2. ✅ Đã thêm `Elite Crawl Bot` vào các nhóm/supergroup cần ghi log.

**Việc còn lại cho phiên sau (chưa làm)**: Bước 1-4 bên dưới (test ghi log thật, test tóm tắt AI
đêm, test `/lichsu` bản Admin, test `/lichsu`+`/timkiem`+`/sum` bản User có lọc theo user) — vẫn
CHƯA test qua Telegram thật lượt nào, chỉ mới xong phần điều kiện tiên quyết.

### Bước 1 — Test ghi log tin nhắn nhóm

1. Nhắn vài tin nhắn thường (không phải lệnh) trong 1 nhóm có bot.
2. Kiểm tra trong Postgres:
   ```sql
   SELECT chat_id, chat_title, user_id, message_text, ts
   FROM gateway.group_chat_log ORDER BY ts DESC LIMIT 20;
   ```
3. Nếu bảng trống → khả năng cao Privacy Mode chưa tắt đúng bot (Bước 0.1), hoặc bot chưa thực sự
   là admin/thành viên nhóm đó.

### Bước 2 — Test tóm tắt AI hàng đêm (`GW Daily Chat Summary`, id `ElSGQgdHPMtrzwME`)

Workflow này chạy tự động 1h sáng. Để test ngay không cần đợi:
1. Mở workflow trong n8n UI → bấm "Execute workflow" thủ công (hoặc dùng `test_workflow` qua MCP
   với `method: "prepared"` nếu instance hỗ trợ MCP server nội bộ).
2. Kiểm tra bảng:
   ```sql
   SELECT chat_id, chat_title, summary_date, message_count, summary_text
   FROM gateway.daily_chat_summary ORDER BY summary_date DESC;
   ```
   **Lưu ý (09/09/2026)**: workflow này giờ chạy thêm 2 job dọn dẹp song song mỗi lần chạy (kể cả
   chạy tay) — xóa `gateway.group_chat_log` cũ hơn 14 ngày và `gateway.daily_chat_summary` cũ hơn
   365 ngày. Vô hại lúc mới test (chưa đủ dữ liệu cũ để xóa) nhưng cần nhớ về sau: `/timkiem`
   (tìm nội dung tin nhắn gốc) sẽ KHÔNG còn tìm thấy gì cũ hơn 14 ngày.
3. Nếu không có dòng nào cho nhóm đã nhắn tin ở Bước 1 → kiểm tra credential DeepSeek
   (`lmChatDeepSeek`, id `F7tLItIIVtzpZGqS`) còn hợp lệ không, và `gateway.group_chat_log` có dữ
   liệu của NGÀY HÔM ĐÓ hay không (query nhóm theo `message_count > 0`).

### Bước 3 — Test `/lichsu` (bản Admin — mọi nhóm)

1. Nhắn `/lichsu` cho **System Bot** (`@elite_n8n_system_bot`, chat riêng với admin).
2. Kỳ vọng: hiện 4 nút số ngày (1/3/5/7) + nút ❌ Hủy.
3. Bấm 1 nút ngày → kỳ vọng: hiện danh sách nhóm dạng link (bấm được) + "🌐 Tất cả nhóm" + nút Hủy.
4. Bấm 1 link nhóm (hoặc "Tất cả nhóm") → kỳ vọng: nhận tóm tắt đúng nhóm/khoảng ngày đã chọn.
5. Test nút ❌ Hủy ở cả bước 2 và 3 → kỳ vọng: nhận "❌ Đã hủy" (dùng chung reply với `/cancel`).
6. (Tùy chọn) Test cú pháp gõ tay cũ vẫn hoạt động: `/lichsu 7` (tất cả nhóm) và
   `/lichsu 7 <chat_id>` (1 nhóm cụ thể, lấy `chat_id` từ bước 3).
7. Test `/timkiem` không tham số → kỳ vọng: liệt kê nhóm (dạng `<code>` để copy `chat_id`) + nút
   Hủy. Sau đó gõ `/timkiem <chat_id> <từ khóa>` → kỳ vọng: trả về các tin nhắn gốc chứa từ khóa.

### Bước 4 — Test `/lichsu` + `/timkiem` (bản User thường — CÓ LỌC, quan trọng nhất)

Đây là phần rủi ro cao nhất vì liên quan bảo mật dữ liệu chat.

1. Dùng **2 tài khoản Telegram khác nhau** (User A và User B), cả 2 đều đã được cấp quyền
   `telebot_main` qua `/user_list`.
2. User A nhắn vài tin trong Nhóm X (bot có mặt). User B KHÔNG nhắn gì trong Nhóm X, chỉ nhắn
   trong Nhóm Y.
3. Đợi qua đêm (hoặc chạy tay `GW Daily Chat Summary` như Bước 2) để có tóm tắt cho cả 2 nhóm.
4. User A nhắn `/lichsu` cho **Elite Clickupbot** (bot chính) → bấm 1 số ngày → **kỳ vọng: chỉ
   thấy Nhóm X trong danh sách chọn nhóm, KHÔNG thấy Nhóm Y**.
5. User B lặp lại tương tự → **kỳ vọng: chỉ thấy Nhóm Y, KHÔNG thấy Nhóm X**.
6. **Test cố tình vượt rào**: User B tự gõ tay `/timkiem <chat_id_của_Nhóm_X> việc` (dùng đúng
   `chat_id` thật của Nhóm X mà họ không tham gia) → **kỳ vọng: trả về "Không tìm thấy" (0 dòng)**,
   KHÔNG được trả nội dung thật của Nhóm X. Đây là test quan trọng nhất — nếu User B nhìn thấy nội
   dung Nhóm X là có lỗ hổng lộ dữ liệu, cần báo ngay để vá (xem cách lọc trong CHANGELOG
   09/09/2026 "tiếp 14" — dùng `EXISTS` join `gateway.group_chat_log` theo `user_id`).
7. Kiểm tra `/help` của Elite Clickupbot có liệt kê đúng `/lichsu` + `/timkiem` cho user.

### Nếu có lỗi khi test

- Không thấy nút nào cả (tin nhắn gửi ra nhưng trơn) → kiểm tra lại đúng bẫy RULES.md #14
  (inlineKeyboard set bằng 1 expression động cho cả field).
- Bấm nút không phản hồi gì (không có execution mới trong n8n) → khả năng callback prefix chưa có
  trong whitelist của `GW-03 Router` (với bot User) hoặc route chưa khớp trong `Phân tích lệnh`/
  `Switch` (cả 2 bot) — xem RULES.md #13/#15 về batch rollback và `sourceIndex`/`targetIndex`.
- `/lichsu`/`/timkiem` báo "Lệnh không hợp lệ" ngay từ bot User → kiểm tra `COMMAND_MAP` trong
  node `⚙️ Config` của `GW Gateway - Telegram` có đủ `lichsu`/`timkiem` không (lỗi này đã xảy ra
  1 lần trong lúc build, đã fix — xem CHANGELOG).

## 📇 Index thay đổi/lỗi đã fix gần đây (đọc CHANGELOG.md để biết chi tiết đầy đủ từng mục)

Danh sách tra nhanh — mỗi dòng trỏ tới mục tương ứng trong `CHANGELOG.md` (tìm theo ngày/tiêu đề):

- **09/09/2026 (tiếp 14)**: button hóa `/lichsu` (3 bước: chọn ngày → chọn nhóm → xem tóm tắt,
  dùng deep-link hyperlink cho danh sách nhóm thay vì inline keyboard động — tránh bẫy RULES.md
  #14) · mở `/lichsu` + `/timkiem` cho user thường qua `Telebot ClickUp Reader`, có lọc theo
  `user_id` (chỉ thấy/tìm được nhóm mình từng nhắn tin, kể cả khi cố gõ tay `chat_id` khác) · phát
  hiện + fix Gateway thiếu `lichsu`/`timkiem` trong `COMMAND_MAP` (lệnh sẽ báo "không hợp lệ" nếu
  thiếu) · thêm whitelist callback `ulchs_` vào `GW-03 Router`.
- **09/09/2026**: fix nút `/user_list` bị lệch route do 2 phiên sửa song song · phát hiện tên tham
  số đúng cho `addConnection` là `sourceIndex`/`targetIndex` (RULES.md #13) · thêm `/version` ·
  fix Upload OneDrive không hiện nút (bẫy inlineKeyboard động, RULES.md #14) · thêm auto-delete tin
  nhắn cũ (ClickUp Reader + Admin System) · fix bug xóa-tin-trước-khi-gửi-tin-mới do mất envelope ·
  thêm forward thông báo upload vào nhóm/topic (`gateway.notify_targets`) · fix Gateway thiếu
  whitelist `odfwd_`/`odhelp` khiến nút forward không phản hồi · phát hiện lỗi batch-rollback khi 1
  operation lỗi giữa chừng làm mất luôn các operation trước đó trong cùng batch (RULES.md #15) ·
  thêm `/cancel` cho Admin System + nút Hủy cho các menu · sanitize tên file upload (5 từ, không
  emoji/số/ký tự đặc biệt) · định tuyến 3 loại thông báo hệ thống (ClickUp update/lịch/lỗi) vào
  nhóm riêng · phát hiện + fix credential sai (Telegram Dev Bot cũ) trên 4 node backup · phát hiện
  + fix thiếu dấu `=` khiến ghi đè Postgres từ ClickUp Live Update luôn lỗi cú pháp · fix thông báo
  hiện "—" khi task chưa từng đồng bộ vào Postgres · thêm `gateway.error_logs` + workflow
  `GW Weekly Error Report` · xác nhận DKPV/PVTC (Phương án A) đã được 1 phiên trước làm đúng.
- **08/09/2026**: cutover PROD bot toàn bộ · `/xoanen` + `/tomtat` test thật OK · chuyển OCR sang
  Mistral native · backup Postgres qua SSH thật (pg_dump) · redesign format `/task chitiet_<id>` ·
  fix credential sai bot ở nhiều node · xây `Telebot Admin System` tách riêng bot admin.
- **Trước 08/09/2026**: xem trực tiếp `CHANGELOG.md` — các mốc Phase 0-3 (schema DB, Gateway, Full
  Reconcile, Live Update, Sync Scheduler) đều đã hoàn tất và đang chạy ổn định.

## Repo

`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua `gh` CLI (đã auth sẵn trong môi
trường Claude Code) hoặc Composio (OAuth) tuỳ phiên.

## Cấu trúc repo hiện tại

```
bot-gateway/
├── README.md
├── docs/
│   ├── CHANGELOG.md          <- lịch sử thay đổi chi tiết theo ngày (nguồn sự thật đầy đủ)
│   ├── PROJECT_STATUS.md     <- file này (trạng thái hiện tại + index tra nhanh)
│   ├── ARCHITECTURE.md       <- thiết kế hệ thống + mục 9: nợ kỹ thuật/refactor
│   ├── RULES.md              <- quy tắc bắt buộc, ĐỌC TRƯỚC khi sửa workflow (15 mục)
│   ├── FEATURE_CATALOG.md    <- bảng đầy đủ tính năng theo từng bot
│   ├── BOT_INVENTORY.md, GUIDE_DEPLOY_DATABASE.md, SETUP_PHASE_0_1.md
│   ├── GUIDE_SQL_CLICKUP_SYNC.md, GO_LIVE_CHECKLIST.md, FAQ.md
├── sql/
│   ├── 01_gateway_schema.sql, 02_clickup_tasks_schema.sql
│   ├── 03_gateway_changelog.sql          <- bảng cho lệnh /version
│   ├── 04_gateway_notify_targets.sql     <- cấu hình forward OneDrive
│   ├── 05_gateway_notify_targets_system.sql  <- cấu hình thông báo hệ thống
│   └── 06_gateway_error_logs.sql         <- log lỗi cho Weekly Error Report
├── scripts/restore.sh        <- khôi phục thảm họa, CHƯA test trên instance trống
├── original/                 5 workflow production NGUYÊN BẢN (tham khảo, không sửa)
└── workflows/new_architecture/
    ├── GW_Gateway_Telegram.json, GW_Error_Handler.json
    ├── SQL_ClickUp_Full_Reconcile.json, SQL_ClickUp_Sync_Scheduler.json,
    │   SQL_ClickUp_Live_Update.json
    └── sub_workflows_modernized/
        ├── Elite_Help_Bot_GPT.json        (chờ Workflow ID để gắn Gateway)
        ├── Telebot_ClickUp_Reader.json    (đang dùng)
        ├── Telebot_Admin_System.json      (đang dùng, bot riêng)
        └── Bot_Image_Processing.json      (đang dùng, /xoanen + /tomtat)
```

## Ghi nhớ kỹ thuật quan trọng nhất

Đã chuyển toàn bộ vào `docs/RULES.md` (15 mục, cập nhật liên tục) để tránh trùng lặp nội dung giữa
2 file. Luôn đọc RULES.md trước khi sửa bất kỳ workflow nào — đặc biệt các mục về ClickUp node dùng
tham số phẳng (không phải resource-locator), `SplitInBatches`, và 4 bẫy kỹ thuật mới phát hiện
09/09/2026 (mục 12-15).
