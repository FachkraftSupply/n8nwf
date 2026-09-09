# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Đọc file này (hoặc link GitHub của nó) vào đầu chat mới để nắm được trạng thái hiện tại mà
> không cần đọc lại lịch sử debug dài của các phiên trước — file này chỉ giữ TRẠNG THÁI HIỆN TẠI,
> không giữ tường thuật quá trình (tường thuật đầy đủ nằm ở `docs/CHANGELOG.md`, mới nhất lên trên).

## ⚙️ QUY TRÌNH BẮT BUỘC khi build/sửa workflow (áp dụng MỌI phiên, không có ngoại lệ)

Đúc kết sau nhiều lần dính lỗi im lặng (xem RULES.md, hiện 19 mục) — quy trình dưới đây tồn tại vì
LÝ DO CỤ THỂ, không phải thủ tục hình thức. Bỏ qua bước nào cũng từng gây hậu quả thật (có lần sập
toàn bộ bot cho mọi user).

**Trước khi sửa:**
1. Đọc `docs/RULES.md` (toàn bộ, không chỉ lướt tiêu đề) + `docs/FAQ.md` — đặc biệt các mục liên
   quan trực tiếp tới loại thay đổi sắp làm (thêm node mới → mục 18; sửa node cũ → mục 16; thêm cột
   dữ liệu đi qua nhiều workflow → mục 19; sửa inline keyboard → mục 14).
2. Gọi **n8n skill** phù hợp trước khi viết code/thiết kế node (dùng tool `Skill`, KHÔNG tự đoán
   cú pháp/pattern từ trí nhớ) — tối thiểu 1 trong số: `n8n-workflow-patterns` (chọn đúng pattern
   trước khi build), `n8n-node-configuration` (tham số chính xác của node cụ thể), `n8n-validation-expert`
   (đọc hiểu lỗi validate), `n8n-code-javascript` (viết Code node đúng chuẩn), `n8n-subworkflows`
   (khi động tới ranh giới Gateway ↔ sub-workflow), `n8n-expression-syntax`, `n8n-error-handling`.
3. Nếu tính năng đi qua ranh giới Gateway ↔ sub-workflow, hoặc thêm 1 cột dữ liệu mới — liệt kê rõ
   TẤT CẢ điểm đọc + ghi liên quan (RULES.md #19) trước khi bắt đầu sửa, không sửa xong rồi mới nhớ ra.

**Trong lúc sửa:**
4. Node mới (DDL/gọi API ngoài) → `setNodeSettings` (`alwaysOutputData`/`onError`) TRONG CÙNG batch
   `update_workflow` với `addNode` (RULES.md #18) — không tách 2 lần gọi.
5. Sửa tham số/credential của node ĐÃ TỒN TẠI → ưu tiên `updateNodeParameters`/`setNodeParameter`,
   nhưng KHÔNG tin ngay — xem bước 6.

**Sau khi sửa, TRƯỚC khi publish:**
6. `get_workflow_details` đọc lại workflow, xác nhận ĐÚNG giá trị mới có mặt ở ĐÚNG vị trí — không
   tin `appliedOperations` khớp số lượng nghĩa là đã áp dụng đúng (RULES.md #16). Nếu sai/thiếu →
   `removeNode` + `addNode` lại (đã xác nhận hoạt động 100%), không thử lại y hệt thao tác cũ.
7. Nếu trigger không execute trực tiếp qua MCP được (Telegram Trigger, `executeWorkflowTrigger`) —
   dùng `prepare_workflow_pin_data` + `test_workflow` mô phỏng input thật (Code/IF/Switch chạy logic
   thật, Postgres/Telegram/HTTP tự động bị pin nên an toàn không gửi tin/ghi DB thật) để xác nhận
   OUTPUT đúng trước khi để user tự test qua Telegram thật.
8. `publish_workflow` — BẮT BUỘC ngay sau mỗi lần update workflow đang active (RULES.md #12).

**Sau khi publish, trước khi báo "xong" cho user:**
9. Với thay đổi vừa/lớn (≥3 node bị sửa, hoặc đụng ranh giới Gateway↔sub-workflow, hoặc thêm cột dữ
   liệu mới) — dùng tool `Agent` (subagent_type mặc định, chạy độc lập/background) giao nhiệm vụ
   AUDIT LẠI: đọc RULES.md/FAQ.md mới nhất, đọc lại CHÍNH workflow vừa sửa qua `get_workflow_details`
   (không tin mô tả của phiên chính, tự tra JSON thật), đối chiếu từng thay đổi có đúng ý định không,
   báo PASS/FAIL kèm bằng chứng cụ thể (tên node + giá trị field). Đây là lớp kiểm tra ĐỘC LẬP thứ 2,
   không phải lặp lại bước 6 — subagent không có ngữ cảnh "tin tưởng sẵn" vào các bước trước.
10. Cập nhật `PROJECT_STATUS.md` (mục mới lên đầu) + `CHANGELOG.md` ngay, dù user chưa test xong —
    ghi rõ "ĐÃ BUILD, CHƯA TEST THẬT" nếu chưa có xác nhận qua Telegram thật.

> Tài liệu khác: `docs/ARCHITECTURE.md` (thiết kế hệ thống, mục 4b tính năng Upload OneDrive/Zalo,
> mục 9 nợ kỹ thuật/refactor), `docs/GUIDE_SQL_CLICKUP_SYNC.md` (vận hành sync), `docs/GO_LIVE_CHECKLIST.md`,
> `docs/FEATURE_CATALOG.md` (bảng đầy đủ tính năng theo từng bot), `docs/FAQ.md`, `docs/RULES.md`
> (19 mục, cập nhật liên tục — đọc TRƯỚC bước 1 ở trên, không phải đọc lướt qua).
>
> **⚠️ Rủi ro đã xảy ra thật**: 2 phiên chat khác nhau từng sửa CÙNG 1 workflow song song mà không
> biết về nhau, gây lệch dữ liệu (xem CHANGELOG 09/09/2026). Nếu thấy `nodeCount`/`connections` khác
> con số bạn nhớ — ĐỪNG cho là mình nhớ nhầm, hãy đọc lại file này (bản mới nhất trên GitHub, không
> tin bộ nhớ hội thoại) trước khi sửa tiếp.

## 🚧 ĐANG BUILD DỞ (09/09/2026, phiên tiếp 14) — Xóa file OneDrive vừa upload + thu hồi tin forward

**QUAN TRỌNG NẾU ĐỌC LẠI FILE NÀY Ở PHIÊN MỚI**: tính năng này ĐANG XÂY DỞ, chia làm 4 stage, mỗi
stage publish riêng để không mất tiến độ nếu hết token giữa chừng. Đọc đúng mục "Stage nào đã xong"
bên dưới trước khi tiếp tục — ĐỪNG build lại từ đầu.

**Yêu cầu user (nguyên văn ý)**: 2 nút mới —
1. Trên tin nhắn kết quả upload (`Send Upload Result`, chat riêng, TRƯỚC khi forward): nút
   "🗑️ Xóa file vừa upload" → xóa file OneDrive.
2. Trên tin nhắn "bản lưu riêng" (`Send Forward Copy To User`, SAU khi đã forward): nút
   "🗑️ Xóa & thu hồi" → xóa file OneDrive + xóa tin đã forward trong nhóm Telegram + (Zalo không có
   API xóa/thu hồi theo tài liệu chính thức → gửi tin mới báo "đã xóa" vào đúng nhóm Zalo thay vì
   thử gọi API không có thật).

**Thiết kế** (đã trình bày cho user, user đã OK "bắt đầu build cho tôi nhé"):
- Callback mới: `od_del_<queueId>` (xóa trước forward), `od_delfwd_<queueId>` (xóa sau forward) —
  CỐ Ý bắt đầu bằng `od_` để tự khớp whitelist Gateway có sẵn (`resolveBotKeyForCallback` đã check
  `startsWith('od_')`) → KHÔNG cần sửa `GW Gateway - Telegram` (`xmEKeIUnzxm2F7dF`).
- 6 cột mới trên `clickup.upload_notify_queue`: `drive_id`, `item_id` (lưu lúc upload, vì lúc xóa là
  1 execution KHÁC hẳn, không còn truy cập node cũ), `fwd_chat_id`, `fwd_message_id` (lưu lúc forward
  thành công, để sau xóa đúng tin trong nhóm), `zalo_chat_id_used` (để biết gửi tin báo xóa vào đúng
  nhóm Zalo nào), `deleted_at` (chặn bấm xóa 2 lần + chặn forward 1 file đã xóa).
- Guard quan trọng: `Build Forward Message` sẽ được sửa để từ chối forward nếu `deleted_at` đã có
  giá trị (báo "File đã bị xóa, không thể forward").
- Xóa OneDrive/Telegram/Zalo đều dùng `onError: continueRegularOutput` — thiết kế "best-effort":
  1 bước lỗi (vd file đã bị xóa tay trước đó trên OneDrive) không chặn các bước dọn dẹp còn lại.

### Stage đã xong (KHÔNG làm lại):
- ✅ **Stage 1/4** (publish `activeVersionId: c51dd030-5884-4593-bc88-1f81e78cce1d`): ALTER 6 cột
  mới vào `clickup.upload_notify_queue` (node `Ensure Notify Queue Columns`, đã giữ nguyên
  `alwaysOutputData`/`onError` cũ). `Queue Upload Notify` INSERT thêm `drive_id`/`item_id` lấy từ
  `$('Upload To OneDrive').item.json.parentReference.driveId` / `.id`. `Send Upload Result` thêm
  hàng nút thứ 5 "🗑️ Xóa file vừa upload" → `od_del_{{ $json.id }}`. **Callback này CHƯA có handler
  — bấm vào lúc này sẽ rơi vào "Lệnh không hợp lệ" (bình thường, do stage 3-4 chưa build) — KHÔNG
  phải bug, đừng test nút này cho tới khi thấy dòng "Stage 4/4 XONG" ở dưới.**

### Stage CHƯA làm (làm tiếp theo đúng thứ tự):
- ✅ **Stage 2/4 XONG** (publish `activeVersionId: bd48c9cd-6dfb-44a0-8b4c-534c2b0e4ddc`):
  `Build Forward Message` trả thêm `queueId` + từ chối forward nếu `deleted_at` đã có. Chèn
  `OD Fwd: Extract Send Result` (Code, đọc `message_id`/`chat.id` từ response `Send Forward Message`,
  có fallback đọc `result.message_id` phòng n8n trả khác shape — **CHƯA xác nhận được shape thật**
  vì `test_workflow` pin node Telegram, phải chờ user test thật, xem log/execution nếu
  `fwd_chat_id`/`fwd_message_id` bị NULL sau khi forward) → `OD Fwd: Save Message Info` (Postgres
  UPDATE `fwd_chat_id`/`fwd_message_id`/`zalo_chat_id_used`, có `alwaysOutputData`+`onError`) — chèn
  GIỮA `Send Forward Message` và `Confirm Forward Sent`. `Send Forward Copy To User` đã có nút
  "🗑️ Xóa & thu hồi" → `od_delfwd_{{ $json.queueId }}` (`replyMarkup` TĨNH, đúng Rule #21). Có 1 lỗi
  nhỏ tự phát hiện qua `validationWarnings` (`removeNode` xoá mất connection ĐẦU VÀO của `Build
  Forward Message`, chỉ nối lại được đầu ra ở lần gọi đầu) — đã fix ngay, verify lại connections đầy
  đủ trước khi publish. **Callback `od_delfwd_` vẫn CHƯA có handler — bình thường tới hết Stage 3.**
- ✅ **Stage 3/4 XONG** (publish `activeVersionId: 8f861731-ecc9-4220-9dfd-61c92e15c155`):
  `Phân tích lệnh` parse thêm `od_del_(\d+)` → route `od_del`, `od_delfwd_(\d+)` → route `od_delfwd`
  (check TRƯỚC `unknown_command`, không đụng logic cũ). `Switch` (router chính) thêm 2 rule mới
  `od_del`/`od_delfwd` — đúng như dự đoán, thêm 2 rule đã ĐẨY index fallback (`extra`) từ 17 lên 19,
  đã nối lại đủ 17 output gốc (0-16, giữ nguyên target) + fallback ở vị trí MỚI (19 → `Reply Unknown
  Command`). Output 17 (`od_del`)/18 (`od_delfwd`) ĐANG ĐỂ TRỐNG có chủ đích — sẽ nối vào node xử lý
  thật ở Stage 4. **Lưu ý cho subagent audit / phiên sau**: response `update_workflow` báo 1 warning
  `SWITCH_FALLBACK_OUTPUT_DISABLED` dù `options.fallbackOutput` đã đúng là `"extra"` — đã tự
  `get_workflow_details` đọc lại JSON THẬT ngay sau đó và xác nhận cấu hình + toàn bộ 20 connection
  (index 0-16 đúng target cũ, 17/18 null, 19→Reply Unknown Command) đều ĐÚNG — kết luận đây là
  validator false-positive tại thời điểm response (có thể do check chạy giữa lúc áp connection),
  KHÔNG phải lỗi thật. Vẫn nên audit lại 1 lần nữa cho chắc khi Stage 4 xong.
- ⬜ **Stage 4/4**: build 2 chuỗi node xử lý thật:
  - `od_del` (7 node): Get Queue (SELECT `drive_id,item_id,fwd_message_id,deleted_at,final_name`) →
    Build Result (Code, guard: không tìm thấy / đã forward rồi (phải dùng nút kia) / đã xóa rồi) →
    IF ok → [true] Graph API `DELETE /drives/{driveId}/items/{itemId}` (onError continue) → Postgres
    `SET deleted_at=now()` (alwaysOutputData+onError) → Reply "✅ Đã xóa"; [false] Reply lỗi tương ứng.
  - `od_delfwd` (10 node): Get Queue (thêm `fwd_chat_id`/`zalo_chat_id_used`) → Build Result (guard
    tương tự, thêm case "chưa forward") → IF ok → [true] Graph API DELETE → Telegram `deleteMessage`
    (chat=`fwd_chat_id`, message=`fwd_message_id`, onError continue) → IF có `zalo_chat_id_used` →
    [true] HTTP POST Zalo Bot API báo "File '<final_name>' vừa bị xóa" (dùng đúng token hardcode như
    `Send Zalo Notify`, KHÔNG gõ token thật — xem Rule #17) / [false] bỏ qua → cả 2 nhánh gộp về 1
    Postgres `SET deleted_at=now()` → Reply "✅ Đã xóa & thu hồi"; [false ở IF đầu] Reply lỗi.
  - Test qua `test_workflow`+`prepare_workflow_pin_data`, `get_workflow_details` xác nhận, publish,
    spawn subagent audit độc lập (đặc biệt kiểm tra: index Switch đúng, `deleted_at` guard hoạt động,
    KHÔNG có `replyMarkup` động, các HTTP DELETE có `onError` đúng) — rồi mới cập nhật CHANGELOG.md
    và xoá bỏ toàn bộ mục "ĐANG BUILD DỞ" này, thay bằng mục "✅ BUILD XONG" như các mục dưới.
  - **Sau khi xong hết, thêm 1 file SQL lịch sử** `bot-gateway/sql/08_upload_notify_queue_delete.sql`
    ghi lại 6 cột mới (giống style file `04_gateway_notify_targets.sql`).

## ✅ BUILD MỚI (09/09/2026, phiên tiếp 13) — Gửi bản lưu riêng vào chat cá nhân khi forward tin nhắn

User xác nhận fix "❓ Trợ giúp" (phiên tiếp 12) đã hoạt động ("ok đã hoạt động rồi"). Yêu cầu mới:
mỗi khi bot forward tin nhắn thông báo upload OneDrive vào 1 nhóm Telegram (qua nút Kammer/BAV,
Hóa đơn, Giấy tờ khác), cũng gửi CÙNG NỘI DUNG đó vào chat riêng (private) của chính user đã upload,
để họ lưu lại làm hồ sơ cá nhân.

**Đã build** trong `Telebot ClickUp Reader` (`9JJRrh36H2rLwtnu`):
- Node mới `Send Forward Copy To User` (Telegram, id `send-forward-copy-to-user`), `chatId: ={{
  $json.adminChatId }}`, `text` = tiền tố "📋 (Bản lưu riêng cho bạn)" + nguyên văn `{{ $json.text }}`
  (đã được `Build Forward Message` escape HTML sẵn, không escape lại 2 lần), dùng credential
  `Elite Clickupbot` (giống hệt node `Send Forward Message` — không bị auto-assign nhầm bot).
- Nối thêm 1 connection từ output TRUE (index 0) của node IF `Forward OK?` sang node mới — chạy
  SONG SONG với 2 connection có sẵn (`Send Forward Message`, `Has Zalo Target?`), không đụng/xoá
  connection nào cũ.
- Không cần sửa Gateway (`xmEKeIUnzxm2F7dF`): tính năng này không tạo/đổi callback_data nào, chỉ là
  1 side-effect tự động của nhánh IF đã tồn tại sẵn — nên KHÔNG dính bug loại "quên cập nhật
  whitelist" như phiên tiếp 12.
- Sau audit độc lập (subagent, PASS toàn bộ 6 mục kiểm tra + 1 gợi ý hardening), đã thêm
  `onError: continueRegularOutput` cho node mới — nếu gửi tin nhắn riêng lỗi (VD: user đã chặn bot)
  thì không ảnh hưởng tới việc forward vào nhóm/Zalo (đã publish, `activeVersionId`
  `48441cac-286f-41f9-ba4f-7c40d5b02ff0`).

**Trạng thái**: ĐÃ BUILD + ĐÃ AUDIT (PASS) + ĐÃ PUBLISH, **CHƯA TEST THẬT** qua Telegram — cần user
thử upload + forward 1 lần để xác nhận tin nhắn riêng xuất hiện đúng trong chat cá nhân.

**Đề xuất chưa build (chờ user quyết định)**: tính năng "xoá file OneDrive vừa upload" (phòng trường
hợp chọn nhầm file) — đã tư vấn hướng triển khai (lưu `drive_id`+`item_id` vào
`clickup.upload_notify_queue`, UI xác nhận 2 bước kiểu "Xoá hoàn toàn user", gọi Graph API
`DELETE /drives/{driveId}/items/{itemId}`, nhớ thêm prefix callback mới VD `oddel_` vào whitelist
Gateway theo đúng bài học phiên tiếp 12), độ khó ước tính Thấp-Trung bình. Chưa build, chờ user chốt.

## 🔴 SỬA (09/09/2026, phiên tiếp 12) — Bug THẬT SỰ ở Gateway: quên cập nhật whitelist callback

User test qua Telegram thật, xác nhận: bấm "❓ Trợ giúp" → **stuck, không có phản hồi gì**. Tra
execution thật (Gateway `1528`/`1529`) lộ ra: `GW-03 Router` tính `route: "help_bot"` thay vì
`"telebot_main"` — callback rơi vào `→ Sub: Help Bot`, một sub-workflow **ĐANG BỊ DISABLE** (chưa có
Workflow ID thật), nên im lặng không phản hồi gì — không phải lỗi ClickUp Reader (workflow đó thậm
chí KHÔNG CÓ execution mới nào sau khi user bấm, xác nhận callback chưa từng tới được đó).

**Nguyên nhân**: hàm `resolveBotKeyForCallback` trong `GW-03 Router` (`xmEKeIUnzxm2F7dF`) check
`data === 'odhelp'` (SO KHỚP TUYỆT ĐỐI) — nhưng nút đã đổi callback_data thành `odhelp_<queueId>`
(mang theo id) ở "phiên tiếp 10". Chuỗi mới không khớp `=== 'odhelp'` VÀ cũng không khớp
`startsWith('od_')` (ký tự thứ 3 là 'h' không phải '_') → rơi xuống `DEFAULT_BOT` = `help_bot`.
**Đây là bug ĐÚNG LOẠI mà chính comment trong code đã tự cảnh báo** ("đã gây bug im lặng 1 lần
trước đó" — về `odfwd_`/`odhelp` không khớp `od_`) — tôi lặp lại loại lỗi này lần 2 vì đổi FORMAT
của 1 callback_data đã có (từ tĩnh sang có tham số) mà quên rà lại whitelist Gateway, dù chính tay
tôi đã thêm dòng comment cảnh báo này trước đó trong cùng phiên.

**Đã sửa**: đổi `data === 'odhelp'` → `data.startsWith('odhelp')` (khớp cả 2 dạng cũ/mới). Verify +
publish. **Việc cần user làm**: test lại nút "❓ Trợ giúp" 1 lần nữa qua Telegram thật.

**Bài học bổ sung cho RULES.md #1** (đã làm ngay dưới đây): quy tắc "đổi COMMAND_MAP khi thêm lệnh
mới" cần mở rộng thành "đổi/thêm CALLBACK_DATA FORMAT (không chỉ lệnh gõ tay) cũng phải rà lại
whitelist callback ở Gateway `GW-03 Router`" — đặc biệt khi ĐỔI FORMAT của 1 callback_data ĐÃ CÓ
SẴN (không phải thêm mới), vì dễ quên hơn thêm mới (thêm mới thì phải nghĩ tới whitelist, đổi format
1 cái cũ thì dễ quên vì "tưởng đã có trong whitelist rồi").

## ✅ QUY TRÌNH MỚI ĐÃ CHỨNG MINH HOẠT ĐỘNG (09/09/2026, phiên tiếp 11) — Subagent audit bắt đúng 1 bug thật mà tự test bỏ sót

Lần ĐẦU TIÊN áp dụng bước 9 của quy trình mới (spawn subagent độc lập audit sau khi publish) — và nó
bắt được đúng 1 bug thật trong chính fix "Trợ giúp" vừa làm ở "phiên tiếp 10":

**Bug bị bắt**: node `Send Help Text` dùng `replyMarkup`/`inlineKeyboard` bằng EXPRESSION ĐỘNG
(`={{ $json.hasKeyboard ? 'inlineKeyboard' : 'none' }}`) — ĐÚNG bẫy đã từng gặp và tưởng đã hiểu rõ
(RULES.md #14), nhưng lần này lặp lại vì tôi lầm tưởng node `Send OD Menu` (nhìn thấy dùng pattern
tương tự) là "đã proven hoạt động" — thực ra pattern THẬT SỰ đã fix và đang chạy ổn định là
`Has OD Menu Keyboard?` (IF) → 2 nhánh TĨNH (`Send OD Menu (Keyboard)` có `replyMarkup` là chuỗi CỐ
ĐỊNH `"inlineKeyboard"`, KHÔNG phải expression) — tôi đã đọc nhầm/không kiểm tra kỹ node liên quan
trước khi tái sử dụng "pattern tưởng đã đúng".

**⚠️ Bài học quan trọng nhất**: `test_workflow` (bước 7 trong quy trình) **KHÔNG PHÁT HIỆN ĐƯỢC lỗi
này** dù đã chạy và báo "success" — vì node Telegram bị "pin" (giả lập) nên không thực sự gọi API
Telegram để biết reply_markup có render đúng hay không; `test_workflow` chỉ xác nhận DỮ LIỆU đưa vào
node đúng, không xác nhận Telegram có HIỂN THỊ đúng nút hay không. Chỉ có (a) đọc kỹ cấu trúc node so
với 1 pattern ĐÃ CHỨNG MINH hoạt động thật trong CHÍNH workflow đó, hoặc (b) subagent audit đọc lại
JSON thật đối chiếu FAQ.md, mới bắt được loại lỗi này.

**Đã sửa đúng theo pattern đã proven** (`Has OD Menu Keyboard?`/`Send OD Menu (Keyboard)`): thêm IF
`Has OD Help Keyboard?` → 2 nhánh tĩnh (`Send Help Text (Keyboard)` với `replyMarkup: "inlineKeyboard"`
cố định + `inlineKeyboard` là object tĩnh, các nút Kammer/BAV=1/Hóa đơn=2/Giấy tờ khác=3 hardcode y
hệt `Send Upload Result`) / (`Send Help Text` không có `replyMarkup` cho trường hợp không có
`queueId`). Verify + test lại bằng `test_workflow` (giờ true branch được gọi đúng, dữ liệu `queueId`
đi đúng) rồi mới publish. Cũng phát hiện thêm lỗi phụ: `addNode` tự gán NHẦM credential
(`@csfsintbot` thay vì `Elite Clickupbot`) cho node Telegram mới — đã sửa bằng `setNodeCredential`.

**Cập nhật RULES.md/FAQ.md cần làm tiếp** (chưa làm ở dòng này, cần làm ngay sau): ghi rõ giới hạn
của `test_workflow` — không phát hiện được lỗi render UI (inline keyboard) vì Telegram node bị pin,
chỉ xác nhận đúng LOGIC/DỮ LIỆU, không xác nhận đúng HIỂN THỊ. Trước khi dùng pattern
`replyMarkup`/`inlineKeyboard` động, LUÔN tìm 1 node THẬT trong CHÍNH workflow đã publish + có
execution thật gần đây dùng ĐÚNG pattern đó và xem `reply_to_message` phía callback tiếp theo có
`reply_markup.inline_keyboard` thật hay không — không suy luận từ tên node giống nhau.

## ✅ SỬA (09/09/2026, phiên tiếp 10) — Nút "❓ Trợ giúp" giờ có nút forward, đã test trước khi publish

User báo: bấm "❓ Trợ giúp" trên tin upload OneDrive → hiện hướng dẫn nhưng KHÔNG có nút nào để bấm
tiếp, phải quay lại tin gốc mới forward được.

**Nguyên nhân**: nút "❓ Trợ giúp" có `callback_data` TĨNH `"odhelp"`, không mang theo `queueId` —
nên khi bấm vào, bot không biết đây là hướng dẫn cho lượt upload nào, không thể tự dựng lại đúng 3
nút `odfwd_<queueId>_<targetId>`.

**Đã sửa** (`Telebot ClickUp Reader`, `9JJRrh36H2rLwtnu`): đổi nút thành `odhelp_{{ $json.id }}`
(mang theo queueId, giống pattern 3 nút forward) → `Phân tích lệnh` parse thêm regex `odhelp_(\d+)`
→ `OD Help: Query Targets` thêm cột `id` vào SELECT → `Build Help Text` dựng lại đúng 3 nút forward
+ nút ❌ Hủy → `Send Help Text` dùng pattern `replyMarkup` động đã proven (`Send OD Menu`).

**Đã test bằng `prepare_workflow_pin_data`+`test_workflow` TRƯỚC KHI publish** (đúng quy trình mới ở
đầu file) — xác nhận `Build Help Text` dựng đúng cả text lẫn 3 nút với `queueId` giữ nguyên
(`odfwd_999_1`/`odfwd_999_2`/`odfwd_999_3`), không cần đợi user test qua Telegram thật mới biết
đúng/sai. Verify param qua `get_workflow_details` xong mới publish.

**Đã lập quy trình chính thức** (xem mục "⚙️ QUY TRÌNH BẮT BUỘC" đầu file — user yêu cầu 09/09/2026):
mọi lần build/sửa lớn từ nay LUÔN gọi n8n skill trước khi code, đọc RULES.md/FAQ.md trước khi sửa,
verify + test trước khi publish, và với thay đổi vừa/lớn — spawn 1 Agent độc lập audit lại toàn bộ
so với RULES.md/FAQ.md sau khi publish (không phải tự mình tự chấm điểm mình). Đã chạy thử ngay
trong phiên này cho đúng fix "Trợ giúp" ở trên — kết quả audit: xem CHANGELOG/lần chạy kế tiếp khi
subagent trả lời (job chạy nền, chưa có kết quả tại thời điểm ghi dòng này).

## ✅ (09/09/2026, phiên tiếp 9) — Luồng ổn định, sửa nốt "Học sinh: Không rõ" + đổi hashtag

User xác nhận luồng Upload OneDrive → forward giờ CHẠY ỔN ĐỊNH, chỉ còn tin nhắn hiện
"🎓 Học sinh: Không rõ" thay vì đúng tên.

**Nguyên nhân**: khi nối dữ liệu `student_name`/`task_url` xuyên workflow (phiên tiếp 6), tôi CHỈ sửa
bảng `pending_uploads` + `upload_notify_queue` bên `Telebot ClickUp Reader`, **quên mất bước Gateway
đọc lại `pending_uploads`** (`GW-04 Check Pending Upload` trong `xmEKeIUnzxm2F7dF`) — query đó vẫn
chỉ SELECT các cột cũ (`task_id, filename, mode, onedrive_link`), nên `pendingUpload.student_name`
luôn `undefined` khi tới bước build tin nhắn, hiển thị "Không rõ". Đã thêm `student_name, task_url`
vào SELECT đó, verify + publish.

**Đổi hashtag theo yêu cầu**: bỏ hẳn `#UploadOneDrive`, giữ `#CapNhatHoSo`, thêm hashtag theo loại
giấy tờ đã chọn — lấy từ phần chữ trước dấu `" - "` trong tên file cuối cùng, so khớp với 5 preset
(`BAV/Kammer/EZB/Schulbestätigung/Spateinstieg`, bỏ dấu để so sánh) → ra đúng `#BAV`/`#EZB`/...;
nếu là tên tùy chỉnh hoặc giữ tên gốc (không khớp preset nào) → fallback `#GIAYTOKHAC`.

**Bài học lặp lại (đã có ở "phiên tiếp 8")**: mỗi khi thêm 1 cột dữ liệu mới cần "đi nhờ" qua nhiều
workflow, phải liệt kê ĐỦ MỌI ĐIỂM đọc/ghi cột đó trước khi coi là xong — lần này bỏ sót đúng 1 điểm
đọc (Gateway) dù đã nhớ sửa đủ 2 điểm ghi (2 bảng ở ClickUp Reader). Nên cân nhắc: mỗi khi thêm cột
mới, `grep` tên cột đó xuyên suốt code TRƯỚC khi publish, không chỉ dựa vào trí nhớ danh sách các
chỗ cần sửa.

**Việc cần user làm**: test lại 1 lượt upload+forward mới, xác nhận tên học sinh hiện đúng và
hashtag đúng loại giấy tờ đã chọn.

## 🔴 (09/09/2026, phiên tiếp 8) — Lỗi THẬT SỰ khác: quên thêm cột vào `pending_uploads`

User báo tiếp tục bị "xóa tin cũ nhanh hơn hiện tin mới", đề xuất thử thêm node Wait 10s. Tra lại
execution thật (1474, 1480 — SAU khi publish fix "phiên tiếp 7") lộ ra **đây KHÔNG PHẢI race
condition/timing** — là lỗi Postgres THẬT: `column "student_name" of relation "pending_uploads"
does not exist`. Ở "phiên tiếp 6" (thêm tin nhắn forward chi tiết hơn), tôi có thêm cột
`student_name`/`task_url` vào `clickup.upload_notify_queue` (qua node `Ensure Notify Queue
Columns`) nhưng **QUÊN làm y hệt cho bảng `clickup.pending_uploads`** — trong khi cả 2 node
`Upsert Pending Upload (Pick)` và `(Custom Prompt)` đều ghi vào ĐÚNG 2 cột đó của bảng này. Kết quả:
`Delete Old Message (Reader)` xóa tin cũ THÀNH CÔNG → bước Upsert ngay sau đó LỖI THẬT (không phải
0-row) → toàn luồng dừng → không tin nhắn mới nào được gửi. Wait 10s sẽ KHÔNG sửa được lỗi này (đây
là lỗi cứng, không phải chậm).

**Đã sửa**: thêm node `Ensure Pending Upload Columns` (ALTER TABLE `pending_uploads` ADD COLUMN IF
NOT EXISTS `student_name`/`task_url`) chèn giữa `Switch` (3 output od_start/od_pick/od_custom_prompt)
→ `OD Task Lookup` — vị trí này AN TOÀN vì `OD Task Lookup` không phụ thuộc `$json` của node liền
trước (chỉ dùng `$('Phân tích lệnh').first().json.taskId`), nên chèn node DDL vào giữa không làm
mất dữ liệu task row cho các bước sau. Đã set `alwaysOutputData`/`onError` NGAY TRONG CÙNG BATCH
(đúng RULES.md #18 mới thêm) và verify bằng `get_workflow_details` trước khi publish. Đã publish.

**Bài học thêm cho RULES.md #18**: mỗi khi thêm cột mới cho 1 tính năng, phải rà lại XEM CÓ BAO
NHIÊU BẢNG cùng cần cột đó — phiên trước chỉ nhớ sửa 1/2 bảng (`upload_notify_queue`), quên bảng
kia (`pending_uploads`) dù cả 2 đều dùng chung tên cột `student_name`/`task_url`. Nên grep toàn bộ
workflow tìm tên cột mới trước khi coi là "đã xong" việc thêm cột.

## 🔴 (09/09/2026, phiên tiếp 7) — LẶP LẠI lỗi RULES.md #16 lần thứ 3, làm gãy bước cuối Upload OneDrive

User báo: sau khi làm tin nhắn forward chi tiết hơn (mục "phiên tiếp 6"), luồng Upload OneDrive bị
"xóa hết tin cũ nhưng chưa chuyển sang tin nhắn mới". Nguyên nhân: node MỚI thêm vào lúc đó
(`Ensure Notify Queue Columns`, chèn giữa `Clear Pending Upload` → `Queue Upload Notify`) được tạo
qua `addNode` **THIẾU `alwaysOutputData`/`onError`** — ĐÚNG lỗi đã ghi trong RULES.md #16 (addNode
âm thầm bỏ qua 2 field này), lần thứ 3 trong dự án dính lỗi này (2 lần trước: Gateway pending-check
gây sập toàn bộ bot 08/09; và OD Task Lookup/Resolve/Upload HTTP nodes cùng ngày). Node ALTER TABLE
không có `RETURNING` → trả về 0 dòng → không có `alwaysOutputData` → toàn bộ chuỗi sau đó (bao gồm
`Queue Upload Notify` và tin nhắn "✅ Đã upload..." kèm nút forward) **không chạy** — trong khi các
bước xóa tin nhắn cũ trước đó (điều hướng menu chọn tên) vẫn chạy bình thường → đúng triệu chứng
"xóa hết tin cũ, không thấy tin mới" user mô tả.

**Đã sửa bằng `setNodeSettings`** (không phải sửa lại `addNode`), verify lại bằng
`get_workflow_details` xác nhận `alwaysOutputData:true`/`onError:"continueRegularOutput"` đã có
thật trước khi publish. Đã publish.

**⚠️ Cần 1 quy trình CHẮC CHẮN hơn để không lặp lại lần thứ 4** — đề xuất thêm vào RULES.md #16:
BẤT KỲ lúc nào dùng `addNode` để thêm 1 node Postgres/HTTP loại "ensure"/"DDL"/gọi API ngoài (không
có `RETURNING` hoặc phụ thuộc external service có thể lỗi) VÀO GIỮA 1 chuỗi đang chạy sống — PHẢI
LUÔN kèm `setNodeSettings` (`alwaysOutputData:true` cho DDL, `onError:"continueRegularOutput"` cho
gọi API ngoài) làm operation NGAY SAU trong CÙNG 1 batch `update_workflow`, không tách làm 2 lần gọi
riêng (dễ quên lần thêm mới, đã quên tới lần thứ 3). Xem RULES.md #16 đã cập nhật.

## 🟡 (09/09/2026, phiên tiếp 6) — Tin nhắn forward chi tiết hơn (người upload, học sinh, giờ, link)

User xác nhận đã tự test full luồng Upload OneDrive → forward, thành công cả Telegram lẫn Zalo (mục
"phiên tiếp 5" bên dưới). Sau đó yêu cầu nâng cấp nội dung tin nhắn forward — đã build xong, CHƯA
test thật (cần user thử lại 1 lượt upload+forward mới để thấy format mới, vì phiên trước đã test
xong với format cũ).

**Format mới** (giống nhau cho Telegram + Zalo, chỉ khác cách hiển thị tên học sinh):
```
📢 Thông báo cập nhật hồ sơ

👤 Người upload: <tên hiển thị Telegram của người thao tác>
📁 Tên file: <tên file đã đặt lúc upload>
🎓 Học sinh: <tên học sinh — HYPERLINK>
🕒 Thời gian: <giờ upload, định dạng vi-VN, timezone Asia/Ho_Chi_Minh>
🔗 Link: <link OneDrive>

#UploadOneDrive #CapNhatHoSo
```
- **Hyperlink tên học sinh KHÁC NHAU theo nền tảng** (đúng yêu cầu user): bản Telegram trỏ tới
  deep-link `chitiet_<taskId>` (mở lại chi tiết task ngay trong bot); bản Zalo trỏ tới **link
  ClickUp** (`task.url`) — vì hyperlink chỉ áp dụng cho HTML gửi qua node Telegram, Zalo dùng link
  khác theo đúng yêu cầu "nếu Zalo hỗ trợ hyperlink thì cho link ClickUp".
- ⚠️ **CHƯA XÁC NHẬN Zalo có thực sự RENDER `<a href>` thành link bấm được hay không** — tài liệu
  Zalo chỉ nói `parse_mode: html` được hỗ trợ, không có ví dụ cụ thể về thẻ `<a>`. Cần user tự nhìn
  tin nhắn Zalo thật sau khi test để xác nhận: nếu tên học sinh hiện ra ĐÃ GẠCH CHÂN/BẤM ĐƯỢC → OK;
  nếu hiện nguyên văn thẻ HTML (`<a href="...">...</a>`) hoặc bot báo lỗi gửi → cần đổi sang gửi
  plain text kèm link riêng 1 dòng thay vì hyperlink cho bản Zalo.
- **Dữ liệu mới phải "đi nhờ" xuyên suốt** từ lúc mở chi tiết task tới lúc forward (đúng RULES.md
  #11): thêm cột `student_name`, `task_url` vào `clickup.pending_uploads`; thêm cột `uploader_name`,
  `student_name`, `task_url` vào `clickup.upload_notify_queue` (tự tạo qua node mới `Ensure Notify
  Queue Columns`, chèn giữa `Clear Pending Upload` → `Queue Upload Notify`). `uploader_name` lấy từ
  `display_name` trong envelope Gateway (đã có sẵn, giờ mới expose ra trong node `Phân tích lệnh`).
- Đã verify TOÀN BỘ node param bằng `get_workflow_details` trước khi publish (đúng RULES.md #16),
  không lặp lại lỗi "báo thành công nhưng không áp dụng" của phiên trước.
- **Việc cần user làm**: test lại 1 lượt Upload OneDrive → forward mới, xác nhận: (1) tin nhắn có
  đủ 5 trường đúng dữ liệu thật (tên mình, tên học sinh đúng task, giờ đúng, link đúng); (2) bấm thử
  tên học sinh trên Telegram có mở lại đúng chi tiết task không; (3) xem tin Zalo có hyperlink bấm
  được không hay chỉ là chữ thường/lỗi thẻ HTML.

## ✅ (09/09/2026, phiên tiếp 5) — Mirror OneDrive forward sang Zalo: TEST THẬT OK, hoạt động

Đã test thật qua `execute_workflow` (chạy thật, không phải giả lập) trên `Zalo API - Webhook Test`:
1. **Webhook production đã đăng ký thành công** — `Call Zalo setWebhook` trả về
   `{"ok":true,"result":{"url":"https://n8n.toididuhoc.net/webhook/zalo-test","verification":{"ok":true,"outcome":"webhook.ok"}}}`.
   Trước đó Zalo đang trỏ vào URL **test** (chỉ sống khi mở editor bấm Listen) — user tự phát hiện
   và hỏi, đã xác nhận đúng là rủi ro thật rồi sửa lại URL production ngay.
2. **`chat_id` nhóm Zalo thật** lấy từ execution `1438`: `zgr-891bfa57540ebd50e41f` (`chat_type:
   "GROUP"`, khác `"PRIVATE"` của chat 1-1). Đã `UPDATE gateway.notify_targets SET zalo_chat_id =
   'zgr-891bfa57540ebd50e41f'` cho CẢ 3 category (`od_kammer_bav`, `od_hoadon`, `od_giayto`) — user
   xác nhận Zalo chỉ có 1 nhóm, không chia topic, nên dùng chung 1 chat_id là đúng.
3. **Gửi tin nhắn thật vào nhóm Zalo — THÀNH CÔNG**, user tự xác nhận đã nhận được trong nhóm.
   `sendMessage` trả `{"ok":true,"result":{"message_id":"...","date":...}}`.
4. Tính năng "Mirror thông báo forward sang Zalo" (`Send Zalo Notify` trong `Telebot ClickUp
   Reader`) giờ **CÓ ĐỦ ĐIỀU KIỆN HOẠT ĐỘNG THẬT** khi user thực hiện 1 lượt Upload OneDrive →
   forward vào nhóm Telegram → tự động mirror sang Zalo. **CHƯA test qua đúng luồng Telegram thật**
   (chỉ mới test isolate cuộc gọi Zalo trực tiếp) — cần user tự đi hết luồng thật 1 lần: Upload
   OneDrive 1 file → bấm forward vào 1 trong 3 category → xác nhận tin nhắn đến CẢ Telegram VÀ Zalo.

**Ghi chú kỹ thuật phát sinh trong lúc test (đã thêm RULES.md #16 mở rộng)**: sửa `jsonBody` thêm
`secret_token` qua `setNodeParameter` rồi `updateNodeParameters(replace:true)` ĐỀU báo thành công
nhưng **không hề áp dụng** — chỉ `removeNode`+`addNode` mới thực sự sửa được. Đã dọn sạch 4 node
tạm (`TEMP ...`) dùng để verify qua `execute_workflow` (nodes có credential — Postgres, Telegram —
bị "pinned"/giả lập khi dùng `test_workflow`, phải dùng `execute_workflow` với
`executionMode:"manual"` mới chạy thật kể cả gọi external API/DB thật).

## 🔴 (09/09/2026, phiên tiếp 4) — `secret_token` KHÔNG hề được áp dụng 2 lần liên tiếp

User báo "không thấy dòng secret_token ở đâu" sau khi phiên trước báo đã sửa xong — kiểm tra lại
`get_workflow_details` xác nhận ĐÚNG: cả 2 lần sửa trước (`setNodeParameter` rồi
`updateNodeParameters replace:true`) đều báo `appliedOperations` thành công nhưng **thực tế không
áp dụng gì cả** — đây là lỗi CÙNG LOẠI với RULES.md #16 (trước chỉ biết xảy ra với `credentials`,
giờ xác nhận xảy ra cả với tham số thường như `jsonBody`). Đã cập nhật RULES.md #16 mở rộng phạm vi
cảnh báo. **Đã sửa dứt điểm bằng `removeNode`+`addNode`** (cách duy nhất xác nhận hoạt động), verify
lại bằng `get_workflow_details` TRƯỚC khi publish lần này — xác nhận đúng, đã publish.

Node `Call Zalo setWebhook` giờ gửi `secret_token: "Haianhtran89"` đúng thật (dạng expression
`={{ {...} }}` thay vì object tĩnh, để tránh nghi ngờ object tĩnh là nguyên nhân — chưa rõ nguyên
nhân gốc của bug này, chỉ biết cách né).

**Việc tiếp theo cho user**: bấm lại "Register Webhook Trigger" → `Call Zalo setWebhook` 1 lần nữa
(lần này chắc chắn có secret_token) → xác nhận `ok:true` → thêm bot vào 1 nhóm Zalo, nhắn thử → lấy
`chat_id` dạng nhóm gửi cho tôi.

## 🟡 (09/09/2026, phiên tiếp 3) — Đã xác nhận schema payload Zalo thật qua execution

User đã hardcode token Zalo vào workflow (xong). Đọc lại 2 execution thật của `Zalo API - Webhook
Test` (`eFH2UIbQirfXSH1b`) — execution `1428` và `1432` — phát hiện:

1. **Schema payload webhook Zalo thật** (execution 1428, tin nhắn 1-1 test):
   ```json
   {"event_name":"message.text.received","message":{"chat":{"chat_type":"PRIVATE","id":"ca7abe8023cfca9193de"},"from":{"id":"ca7abe8023cfca9193de","display_name":"Hải Anh"},"text":"té"}}
   ```
   `chat_id` là CHUỖI CHỮ+SỐ dài (KHÔNG phải số như Telegram), nằm ở `body.message.chat.id`. Nhóm
   sẽ có `chat_type: "GROUP"` thay vì `"PRIVATE"` — **CHƯA có mẫu thật của 1 nhóm**, cần user thêm
   bot vào 1 nhóm Zalo + nhắn thử để xác nhận field `id` tương tự.
2. **`setWebhook` API của Zalo BẮT BUỘC phải kèm `secret_token`** trong body (khác Telegram — ở đó
   optional). Execution 1432 báo lỗi `"Bad request: The secret_token must not be empty"` khi gọi
   thiếu field này. Đồng thời header tin nhắn đến (`x-bot-api-secret-token: Haianhtran89`) cho thấy
   trước đó ĐÃ CÓ 1 lượt đăng ký thành công với secret này (trỏ về URL **test**, chỉ sống khi mở
   editor bấm Listen — chưa phải URL production).
   - **Đã sửa**: node `Call Zalo setWebhook` giờ gửi kèm `{"url": "https://n8n.toididuhoc.net/webhook/zalo-test", "secret_token": "Haianhtran89"}`, đã publish. User cần bấm lại
     "Register Webhook Trigger" → nhánh `Call Zalo setWebhook` 1 lần nữa để webhook trỏ đúng về URL
     PRODUCTION (workflow đã active nên URL này giờ sống thật, không cần mở editor).
   - ⚠️ Việc còn treo: CHƯA thêm bước xác thực header `x-bot-api-secret-token` ở phía node nhận
     (`Zalo Webhook Test`) để chặn request giả mạo không có đúng secret — nên làm khi dọn tính năng
     này để dùng thật lâu dài (không gấp cho việc lấy chat_id nhóm).
3. **Việc tiếp theo (đang chờ user)**: sau khi đăng ký lại webhook vào URL production, thêm bot Zalo
   vào 1 NHÓM thật, nhắn thử 1 tin trong nhóm đó → đọc tin Telegram báo về (hoặc query
   `gateway.zalo_webhook_test_log`) để lấy đúng `chat_id` dạng nhóm (`chat_type: "GROUP"`) → gửi
   cho tôi để điền vào `gateway.notify_targets.zalo_chat_id`.

## 🟡 (09/09/2026, phiên tiếp 2) — Cách nạp token Zalo (Community, không dùng env var) + workflow test riêng

User dùng n8n **Community**, không tiện set biến môi trường qua docker-compose. Đã đổi cách tiếp
cận: **hardcode token trực tiếp vào tham số node trong n8n UI** (user tự dán, Claude không thấy giá
trị thật) thay vì `{{ $env.ZALO_BOT_TOKEN }}`. Node `Send Zalo Notify` (`Telebot ClickUp Reader`,
`9JJRrh36H2rLwtnu`) hiện có URL dạng:
`https://bot-api.zaloplatforms.com/botPASTE_YOUR_ZALO_BOT_TOKEN_HERE/sendMessage` — user cần tự mở
node trong n8n, thay `PASTE_YOUR_ZALO_BOT_TOKEN_HERE` bằng token thật.

**⚠️ Đã thêm RULES.md mục 17** (đọc trước khi commit bất kỳ workflow nào chứa cách hardcode này):
vì repo git public, TRƯỚC KHI commit file export JSON của workflow có node dạng này, PHẢI kiểm tra
lại xem đoạn token trong file có phải vẫn là placeholder `PASTE_YOUR_..._TOKEN_HERE` hay không —
nếu user đã điền thật rồi export ra, phải thay lại thành placeholder trước khi add/commit. Danh
sách node đang dùng cách này: xem RULES.md mục 17 (2 workflow, cập nhật khi thêm mới).

**Workflow mới**: `Zalo API - Webhook Test` (n8n ID `eFH2UIbQirfXSH1b`, project cá nhân
"Hai Anh Tran <haianhtran89@live.de>") — dựng riêng để khám phá format payload thật của Zalo
webhook (tài liệu `bot.zapps.me/docs` không liệt kê đầy đủ schema `getUpdates`/webhook), đặc biệt
là tìm đúng field chứa `chat_id` của 1 GROUP Zalo (khác với chat 1-1). Gồm 2 nhánh:
- **Nhánh Webhook** (`Zalo Webhook Test`, path `/webhook/zalo-test`, POST, `responseMode: onReceived`
  tự trả 200 ngay): mọi update Zalo gửi tới đây được ghi vào bảng mới `gateway.zalo_webhook_test_log`
  (cột `payload JSONB`, tự tạo bảng qua node `Ensure Zalo Log Table`) VÀ báo cho admin qua Telegram
  System Bot kèm preview payload (cắt 600 ký tự đầu) + câu SQL sẵn để xem đầy đủ.
- **Nhánh Manual Trigger** (`Register Webhook Trigger`, bấm tay trong n8n): 2 nhánh song song —
  `Call Zalo getMe` (kiểm tra token còn sống, trả về username/id bot) và `Call Zalo setWebhook`
  (đăng ký `https://n8n.toididuhoc.net/webhook/zalo-test` làm webhook nhận update cho bot Zalo).
- Có sticky note hướng dẫn 5 bước ngay trong workflow (điền token → test getMe → đăng ký webhook →
  thêm bot vào nhóm Zalo + nhắn thử → đọc payload thật để tìm field chat_id → điền vào
  `gateway.notify_targets.zalo_chat_id`).
- **CHƯA test được gì cả** — vẫn đang chờ đúng 1 thứ: token Zalo thật do user điền vào 2 node
  `Call Zalo setWebhook`/`Call Zalo getMe` trong workflow test này VÀ node `Send Zalo Notify` trong
  ClickUp Reader (3 chỗ, cùng 1 token — xem RULES.md #17 để không nhầm chỗ nào).
- ⚠️ Lưu ý: URL webhook `/webhook/zalo-test` chỉ hoạt động ở chế độ **production** (workflow phải
  active/published) — n8n cũng có URL `/webhook-test/zalo-test` riêng chỉ sống khi đang mở editor
  bấm "Listen for test event", KHÔNG dùng URL đó để `setWebhook` (sẽ chết ngay khi đóng editor).

## 🟡 (09/09/2026, phiên tiếp 1) — Mirror thông báo Upload OneDrive sang nhóm Zalo

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
  1. **Zalo Bot Token** — tạo bot qua Zalo Bot Creator (`bot.zapps.me`) rồi lấy token.
     ⚠️ **ĐÃ ĐỔI CÁCH LÀM** (xem mục "phiên tiếp 2" ngay bên trên — user dùng n8n Community, không
     tiện set biến môi trường): KHÔNG còn dùng `{{ $env.ZALO_BOT_TOKEN }}` nữa. Giờ user tự hardcode
     token thẳng vào URL của node `Send Zalo Notify` ngay trong n8n UI (thay đoạn
     `PASTE_YOUR_ZALO_BOT_TOKEN_HERE`). Xem RULES.md #17 về việc redact trước khi commit workflow
     này lên git.
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
| **Telebot ClickUp Reader** (`9JJRrh36H2rLwtnu`, chạy qua Gateway, `bot_key: telebot_main`) | ✅ Hoạt động đầy đủ · ✅ Mirror Zalo đủ điều kiện chạy thật (test isolate OK, chưa test full luồng Telegram) | `/task`, chi tiết task, Upload OneDrive (chọn tên/preset/tùy chỉnh/giữ gốc, forward thông báo vào nhóm Telegram, `/cancel`) — TẤT CẢ đã user xác nhận chạy thật. Mirror thông báo forward sang nhóm Zalo — token đã hardcode, `zalo_chat_id` đã điền cho cả 3 category, gửi thử trực tiếp tới Zalo THÀNH CÔNG (xem mục "phiên tiếp 5" ở trên) — còn thiếu 1 lượt test qua ĐÚNG luồng Upload OneDrive → forward Telegram thật |
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
