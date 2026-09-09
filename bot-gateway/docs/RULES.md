# RULES.md — Quy tắc BẮT BUỘC khi sửa/build workflow n8n (dự án Bot Gateway)

> File này gộp lại TOÀN BỘ quy tắc đã rút ra qua nhiều phiên làm việc. ĐỌC FILE NÀY TRƯỚC khi sửa
> bất kỳ workflow nào. Vi phạm các quy tắc này đã gây lỗi lặp lại nhiều lần trong dự án.

## 1. ⚠️ Gateway COMMAND_MAP (có điều kiện)
Mỗi khi thêm/sửa 1 lệnh mới trong sub-workflow: kiểm tra sub-workflow đó có **Trigger riêng** hay không.
- Nếu gọi qua Gateway (Execute Workflow Trigger, ví dụ `Telebot_ClickUp_Reader.json`): BẮT BUỘC cập nhật
  `COMMAND_MAP` trong node `⚙️ Config` của `GW_Gateway_Telegram.json`.
- Nếu có Trigger riêng (ví dụ `Telebot_Admin_System.json` — Telegram Trigger trực tiếp trên System Bot):
  KHÔNG cần đụng Gateway.

## 2. ⚠️ KHÔNG BAO GIỜ dùng `$json` trần cho dữ liệu quan trọng
`$json` trong 1 node CHỈ lấy từ output của node NỐI TRỰC TIẾP — không đảm bảo field cần (chatId,
message_id...) có mặt. LUÔN tham chiếu tường minh qua tên node:
```
{{ $('Phân tích lệnh').first().json.chatId }}
{{ $('GW-01 Envelope').first().json.chat_id }}
```
Áp dụng cho CẢ `chatId` LẪN `reply_to_message_id` (để bot trả lời đúng group/topic khi được thêm vào
group — không dùng field `chatId` trần bao giờ).

## 3. ⚠️ KHÔNG dùng inline keyboard — mặc định LUÔN dùng deep-link dạng text
Deep-link: `https://t.me/<bot>?start=<param>` (giống `chitiet_<id>` đã chạy ổn định từ đầu dự án).
- Deep-link Telegram CHỈ cho phép ký tự `[A-Za-z0-9_-]` — dùng `_` làm dấu phân cách, KHÔNG dùng `:`.
- Inline keyboard đã gây lỗi lặp lại NHIỀU LẦN qua nhiều nguyên nhân khác nhau (Gateway route callback
  sai luồng; n8n không lưu được field `inlineKeyboard` khi `replyMarkup` là expression động...). Dù
  từng nguyên nhân đã fix được, tổng thể vẫn KHÔNG đáng tin bằng deep-link.
- CHỈ dùng inline keyboard khi user yêu cầu RÕ RÀNG — hỏi lại lý do + cảnh báo lịch sử không ổn định.

## 4. ⚠️ Node ClickUp native — 2 lưu ý bắt buộc
- Dùng THAM SỐ PHẲNG (`team: "9018351620"`), KHÔNG dùng resource-locator `{__rl:true,...}`.
- Operation `getAll` BẮT BUỘC có field `"filters": {}` trong parameters (dù để rỗng) — thiếu sẽ chặn
  Publish workflow với lỗi khó hiểu.
- Field `team`/`space`: nếu bị kẹt "Error fetching options from ClickUp" trên UI — đổi giá trị đó
  thành EXPRESSION (`={{ '9018351620' }}` hoặc tham chiếu từ node Config) thay vì giá trị chữ thường
  trần — n8n sẽ không cố tải dropdown gợi ý cho field dạng expression.

## 5. ⚠️ `.item` vs `.first()`
Không dùng `$('TenNode').item` nếu chuỗi xử lý phía trước có node Postgres/ClickUp làm mất pairedItem
— lỗi "Multiple matching items". Dùng `.first()` khi chỉ có đúng 1 item cần lấy.

## 6. Code node & node bị "im lặng" không chạy
- Code node mặc định "Run Once for All Items" — nếu code viết theo kiểu từng item (`$json`,
  `return {json:{...}}`), phải set `"mode": "runOnceForEachItem"`.
- n8n bỏ qua (skip) hoàn toàn 1 node nếu nhận 0 item đầu vào, kéo theo mọi node phía sau. Set
  `"alwaysOutputData": true` cho node nào cần LUÔN chạy dù có thể ra 0 kết quả.

## 7. Postgres
- `queryReplacement` LUÔN dùng mảng `={{ [$json.x] }}`, kể cả chỉ 1 tham số `$1`.
- Sau khi qua 1 node Postgres, `$json` bị GHI ĐÈ hoàn toàn bằng kết quả SQL — tham chiếu dữ liệu từ
  trước đó qua tên node, không dùng `$json`.

## 8. Quy trình sửa file
- Sửa JSON lớn: Composio remote workbench (fetch GitHub → sửa Python → commit), không dán nguyên
  workflow vào chat.
- Validate TRƯỚC khi commit: check connections orphan, dup id, surrogate pairs lỗi encoding.
- Đang debug/thử nghiệm 1 thay đổi: KHÔNG tự động commit — đưa nội dung node cho user tự copy/paste
  test trong n8n. Chỉ commit sau khi user xác nhận chạy ổn.
- Rủi ro cao: commit file `_v2`/`_wip` riêng, merge vào file chính sau khi xác nhận.
- Rút gọn/mở rộng hoạt động 1 workflow: LUÔN đối chiếu checklist tính năng trước/sau để không bỏ sót.
- Sau khi 1 thay đổi được xác nhận thành công: cập nhật `CHANGELOG.md` + file này nếu có bài học mới.

## 9. Bot Telegram — 3 loại, không được nhầm
| Bot | Vai trò |
|---|---|
| `@elite_n8n_test_bot` (DEV) | Gateway đang lắng nghe — user thường |
| `@Elite_clickup_bot` (PROD) | Sẽ thay bot DEV ở Giai đoạn 4 cutover |
| `@elite_n8n_system_bot` (System) | Admin control panel (`Telebot_Admin_System.json`, Trigger riêng) + thông báo nền (Full Reconcile/Live Update Notify) |

Mỗi khi thêm node Telegram reply mới: xác nhận đúng credential ứng với bot dự định — không suy luận,
kiểm tra `result.from.username` khi test thực tế.


## 10. ⚠️ Test với vài item KHÔNG đảm bảo đúng khi xử lý HÀNG LOẠT (batch)
Tham chiếu `$('TenNode').first()` hoặc `.item` giữa các node CÁCH NHAU 2 BƯỚC trở lên (đặc biệt khi có
Postgres DELETE/UPDATE không RETURNING ở giữa) có thể chạy "đúng" khi test với vài item, nhưng SAI hoàn
toàn khi xử lý hàng loạt (vd 612 task) — `.first()` luôn lấy item ĐẦU TIÊN bất kể đang xử lý item nào;
`.item` có thể mất pairedItem qua nhiều bước, gây "Multiple matching items" hoặc âm thầm cắt còn 1 item.
**Cách sửa triệt để:** GỘP các bước Postgres liên quan (DELETE+INSERT, UPDATE+SELECT...) thành **1 câu
query duy nhất** (dùng CTE: `WITH x AS (DELETE...) INSERT...`) để chỉ cần tham chiếu THẲNG từ node
TRỰC TIẾP đứng trước (1 bước, luôn an toàn) — không tham chiếu chéo qua 2+ bước.
**Luôn test với DATASET THẬT (đủ lớn) trước khi coi 1 luồng Postgres nhiều bước là ổn định** — test
với 5 item không đủ để phát hiện lỗi loại này.


## 11. ⚠️ Cách ĐÚNG để dữ liệu "sống sót" qua chuỗi nhiều node Postgres — "đi nhờ" thay vì "tham chiếu ngược"
Khi 1 chuỗi có NHIỀU node Postgres liên tiếp (mỗi node đều xoá `$json`), đừng cố tham chiếu ngược
(`.item`/`.first()`) — dù chỉ 1-2 bước cũng có thể lỗi nếu ở giữa có Postgres không giữ pairedItem.
**Cách đúng: cho field cần dùng "đi nhờ" qua TỪNG bước bằng `$json` trực tiếp (node ngay trước, luôn
an toàn), không nhảy cóc qua nhiều node.**
- Ở Code node (mode `runOnceForEachItem`): thêm field cần giữ vào chính `return {json:{...}}` của nó,
  đọc từ `$json` (input của chính nó) — KHÔNG đọc từ node xa hơn.
- Ở Postgres node (executeQuery) cần GHI dữ liệu nhưng vẫn phải giữ field khác đi tiếp: bọc INSERT/
  UPDATE trong CTE, rồi `SELECT` ra các giá trị pass-through ở cuối:
  ```sql
  WITH ins AS ( INSERT INTO ... SELECT ... )
  SELECT $1::text AS id, $3::text AS truong_can_giu;
  ```
  Cách này đảm bảo LUÔN ra đúng 1 dòng output (bất kể câu INSERT bên trong ghi bao nhiêu dòng), mang
  theo đúng field cần thiết — không cần tham chiếu ngược ở bất kỳ node nào phía sau.

## 12. ⚠️ Workflow ACTIVE (có Trigger đang lắng nghe) — BẮT BUỘC publish sau mỗi lần sửa qua MCP
`update_workflow` qua MCP chỉ tạo ra 1 **bản nháp (draft, `versionId` mới)** — nếu workflow đang
**active** (có Telegram Trigger/Webhook đang chạy thật), draft này **KHÔNG tự động áp dụng**, bản
đang chạy vẫn là `activeVersionId` CŨ cho tới khi gọi `publish_workflow`. Đã từng sửa xong 1 tính năng,
báo "xong" với user, nhưng user test vẫn ra kết quả cũ hoàn toàn — vì quên bước publish này (xảy ra
với cả `GW_Gateway_Telegram.json` lẫn `Telebot_ClickUp_Reader.json` cùng lúc, 08/09/2026).
**Quy tắc: sau MỌI lần `update_workflow` trên 1 workflow đang `active`, gọi `publish_workflow` ngay
lập tức trước khi báo hoàn tất với user.** Nếu `publish_workflow` báo lỗi vì tham chiếu tới 1
sub-workflow (`→ Sub: ...`) CHƯA publish — publish sub-workflow đó trước.
Nếu gặp lỗi "Cannot modify workflow while it is being edited by a user in the editor" — user đang mở
workflow đó trong tab n8n, đợi họ đóng tab/chuyển tab rồi thử lại (không phải lỗi thật).

## 13. ⚠️ Tham số ĐÚNG cho `addConnection`/`removeConnection` qua n8n MCP là `sourceIndex`/`targetIndex`, KHÔNG PHẢI `sourceOutput`/`targetInput`
Đã dùng nhầm tên tham số `sourceOutput`/`targetInput` (nghe hợp lý nhưng SAI) khi nối dây cho node
IF/Switch nhiều output qua `update_workflow`. Hậu quả: tool **ÂM THẦM bỏ qua giá trị index truyền
vào và luôn mặc định output/input = 0** — không báo lỗi, không cảnh báo gì trong response. Đây
chính là nguyên nhân gốc của lỗi "tất cả connection dồn hết vào 1 output" đã gặp nhiều lần với
`Switch (Admin Extras)` (08-09/09/2026) — tưởng là lỗi build tay/tool, thực ra là sai tên field.
**Cách xác nhận đúng tên field**: gọi operation với object rỗng/thiếu field bắt buộc để tool trả về
lỗi liệt kê đúng tên field (vd gọi `addNode` với `node:{}` → lỗi liệt kê `name`/`type`/`typeVersion`
là bắt buộc). Với `addConnection`/`removeConnection`, chỉ `source`/`target` là bắt buộc — `sourceIndex`
và `targetIndex` là optional (mặc định 0 nếu không truyền, ĐÚNG cho node chỉ có 1 output/input).
**Quy tắc bắt buộc**: bất cứ khi nào nối dây cho 1 node có ≥2 output (IF, Switch) qua `addConnection`,
LUÔN dùng đúng tên `sourceIndex` (không phải `sourceOutput`) — và sau khi nối xong 1 batch lớn, gọi
lại `get_workflow_details` (hoặc test 1 route thật) để xác nhận từng output THỰC SỰ trỏ đúng node,
không tin tưởng riêng response `appliedOperations` (nó không phát hiện được lỗi loại này).

## 14. ⚠️ Auto-xóa tin nhắn cũ (UX) BẮT BUỘC kiểm tra `reply_to_message_id` phía sau — nếu không, tin nhắn mới sẽ gửi LỖI hoàn toàn
Khi thêm cơ chế "xóa tin nhắn panel cũ trước khi gửi panel mới" (xoá bằng `callback.message_id`),
BẤT KỲ node Telegram nào phía sau trong CÙNG luồng đó mà còn đặt `additionalFields.reply_to_message_id`
trỏ tới CHÍNH message_id vừa xoá sẽ nhận lỗi thật từ Telegram API: `400 - Bad Request: message to
be replied not found`. Hậu quả nhìn từ phía user: tin nhắn cũ biến mất, tin nhắn mới KHÔNG BAO GIỜ
xuất hiện (node lỗi, dừng luôn workflow tại đó) — trông giống "xoá tin nhưng chưa gửi tin mới", đã
xảy ra thật với luồng Upload OneDrive (`Send OD Menu`, `Send OD Menu (Keyboard)`, `Reply Ask File
(Pick)`, `Reply Ask Custom Name` trong `Telebot ClickUp Reader`, 09/09/2026).

**Quy tắc bắt buộc**: mỗi khi thêm auto-delete-tin-cũ vào 1 luồng callback nào, PHẢI rà lại TOÀN BỘ
node Telegram gửi tin phía sau trong luồng callback đó — nếu `reply_to_message_id` của node đó trỏ
tới CÙNG message_id vừa bị xoá (thường là `$json.messageId`, `$('Phân tích lệnh').first().json.messageId`,
hoặc tương đương), phải bỏ tham chiếu đó (đặt `reply_to_message_id: "={{ undefined }}"` — n8n sẽ bỏ
qua field khi expression trả về `undefined`, không gửi field này lên Telegram API — hoặc xoá hẳn field
đó khỏi `additionalFields` nếu build node mới từ đầu). Non-callback (tin nhắn gõ tay) KHÔNG xoá tin
cũ nên không bị ảnh hưởng — chỉ áp dụng rà soát này cho các route có `isCallback === true`.

**Lưu ý kỹ thuật khi sửa qua n8n MCP**: `update_workflow` với `updateNodeParameters` chỉ MERGE (không
thay thế toàn bộ) đối tượng `additionalFields` — nếu bạn muốn "xoá" 1 field, việc chỉ truyền lại
`additionalFields` KHÔNG CÓ field đó sẽ KHÔNG xoá được field cũ (field cũ vẫn còn nguyên do merge sâu).
Phải truyền lại field đó với giá trị MỚI tường minh (vd `"={{ undefined }}"`) để thực sự ghi đè.

## 15. ⚠️ `update_workflow` nhiều operation lỗi giữa chừng → CẢ BATCH rollback, không chỉ operation lỗi
Khi 1 lệnh `update_workflow` gồm nhiều operation và 1 operation ở giữa/cuối bị lỗi (vd sai
`sourceIndex`, sai tên node), TOÀN BỘ operation trong batch đó — kể cả những operation đứng TRƯỚC
operation lỗi và đã "đáng lẽ" thành công — đều bị rollback, không được lưu. Đã gây bug thật 2 lần
trong cùng 1 ngày (09/09/2026): cập nhật node `Send Upload Result` (thêm nút forward) và node
`Admin Extras Router` (fix route `/user_list`) đều nằm chung batch với 1 operation lỗi phía sau, chỉ
phần lỗi được sửa lại sau đó — phần cập nhật node kia bị bỏ quên, gây ra 2 lỗi "biến mất" tưởng như
không liên quan (nút không hiện, route sai) nhưng cùng 1 nguyên nhân gốc.

**Quy tắc bắt buộc**: khi 1 batch `update_workflow` báo lỗi ở operation thứ N, coi TẤT CẢ operation
0..N-1 trong batch đó là CHƯA ĐƯỢC ÁP DỤNG — phải gửi lại toàn bộ batch (đã sửa operation lỗi), không
chỉ gửi lại phần từ operation lỗi trở đi. Sau khi batch cuối cùng báo `appliedOperations` khớp đúng
số lượng operation gửi lên, NÊN gọi lại `get_workflow_details` để xác nhận TẤT CẢ thay đổi mong muốn
(cả node params lẫn connections) đã thực sự có mặt — không chỉ tin vào response thành công của lần
gọi SAU (vì nó chỉ xác nhận các operation trong CHÍNH lần gọi đó, không xác nhận lại các operation đã
"tưởng như" thành công ở lần gọi trước đó bị rollback).

## 16. ⚠️ Sửa 1 node ĐANG TỒN TẠI qua `updateNodeParameters`/`setNodeParameter` KHÔNG đáng tin (không chỉ credential) — dùng `removeNode` + `addNode`

**Cập nhật 09/09/2026**: lỗi này KHÔNG CHỈ xảy ra với `credentials` (phát hiện ban đầu) mà còn xảy
ra với tham số THƯỜNG (vd `jsonBody` của node `httpRequest`). Gặp lại y hệt khi thêm field
`secret_token` vào `jsonBody` của node `Call Zalo setWebhook` (workflow `Zalo API - Webhook Test`):
gọi `setNodeParameter` với `path: "/parameters/jsonBody"` → response thành công, nhưng
`get_workflow_details` lại cho thấy giá trị bị lồng SAI CHỖ (`node.parameters.parameters.jsonBody`
thay vì `node.parameters.jsonBody`) — n8n đọc field ở vị trí gốc nên hoàn toàn không có gì thay đổi.
Thử lại lần 2 bằng `updateNodeParameters` với `replace: true` (đúng cú pháp, đúng vị trí top-level)
— response VẪN báo thành công, nhưng đọc lại `get_workflow_details` thì field mới **vẫn không có**,
không có lời giải thích nào từ response. Cả 2 lần đều không có warning/error gì để nhận biết.

**Kết luận chung (áp dụng cho MỌI lần sửa node đã tồn tại, không riêng credential)**: đừng tin
`appliedOperations` khớp số lượng = đã áp dụng đúng. Sau BẤT KỲ `updateNodeParameters`/
`setNodeParameter` nào sửa 1 node đã có sẵn (không phải `addNode` mới), **BẮT BUỘC gọi lại
`get_workflow_details` để xác nhận giá trị mới thực sự có mặt ĐÚNG VỊ TRÍ** trước khi `publish_workflow`. Nếu xác nhận sai/thiếu — đừng thử `updateNodeParameters`/`setNodeParameter` lần
2 cho CÙNG node đó (có vẻ dễ gặp lại cùng lỗi) — chuyển thẳng sang cách dưới đây, đã xác nhận hoạt
động 100% cả 2 lần gặp lỗi này:

**Cách ĐÚNG, đã xác nhận hoạt động (2/2 lần)**: `removeNode` node đó rồi `addNode` lại với **cùng
`id`**, copy nguyên các field khác (`parameters`, `webhookId`, `position`, `credentials` nếu giữ
nguyên) như cũ, chỉ thay đúng phần cần sửa, trong CÙNG 1 batch `update_workflow` (kèm
`addConnection` để nối lại các connection đã mất do `removeNode` xoá theo — `removeNode` xoá cả
connection tới/từ node đó, phải nối lại thủ công). Luôn `get_workflow_details` lại lần nữa để xác
nhận trước khi `publish_workflow`.

### Trường hợp cụ thể ban đầu (CREDENTIAL) — giữ nguyên tham khảo
Gọi `updateNodeParameters` với `parameters: {}` (hoặc rỗng) kèm field `credentials` để chỉ đổi
credential của 1 node — response báo `appliedOperations` thành công, KHÔNG có warning, nhưng khi
`get_workflow_details` lại thì credential **vẫn là credential CŨ**, hoàn toàn không đổi. Gặp bug
này 2 lần (09/09/2026): lúc gán credential OpenRouter cho 2 node `Call OpenRouter (...)` (workflow
Bot Xử Lý Ảnh), và lúc đổi credential Telegram cho 4 node `Notify Backup ... Xong` (workflow
SQL - Backup System) từ `Telegram System Bot` sang `Elite Crawl Bot`. `setNodeCredential` cũng
không dùng được cho node `httpRequest` với credential type không thuộc danh sách generic auth
chuẩn (báo lỗi rõ ràng, ít nhất báo lỗi thay vì âm thầm không đổi).

**Cách ĐÚNG, đã xác nhận hoạt động**: `removeNode` node đó rồi `addNode` lại với **cùng `id`**,
copy nguyên `parameters`/`webhookId`/`position` như cũ, chỉ thay `credentials`, trong CÙNG 1 batch
`update_workflow` (kèm `addConnection` để nối lại các connection đã mất do `removeNode` xoá theo).
Luôn `get_workflow_details` lại để xác nhận `credentials` đã đổi thật trước khi `publish_workflow`
— đừng tin response `appliedOperations` của `updateNodeParameters` cho việc đổi credential.

## 17. ⚠️ Token/secret hardcode TRỰC TIẾP trong tham số node (không qua credential vault) — BẮT BUỘC redact trước khi commit lên git

Một số API (vd Zalo Bot API — token nằm ngay trong URL path `.../bot<TOKEN>/sendMessage`, không
phải header/query nên KHÔNG credential type nào của n8n inject được vào đúng chỗ) buộc phải hardcode
giá trị bí mật thẳng vào tham số node (thường là `url` của node `httpRequest`) thay vì dùng
credential vault hay biến môi trường — quyết định 09/09/2026 vì user dùng n8n Community, không tiện
sửa biến môi trường qua docker-compose.

**Hệ quả bắt buộc phải nhớ**: file JSON export của workflow đó (khi commit vào repo
`workflows/new_architecture/...` để lưu lịch sử) sẽ chứa NGUYÊN VĂN secret nếu không xử lý — repo
này **public**. Quy tắc:

1. **Claude KHÔNG BAO GIỜ tự gõ/dán giá trị secret thật vào tham số node** — luôn để lại 1 placeholder
   rõ ràng dạng `PASTE_YOUR_<TEN_SERVICE>_TOKEN_HERE` ngay trong chuỗi URL/tham số, để user tự vào n8n
   UI điền giá trị thật. Không hỏi user gõ token vào chat để Claude điền hộ.
2. **Trước khi `git add`/`git commit` bất kỳ file JSON export nào của workflow có node loại này**:
   BẮT BUỘC `grep`/tìm trong file JSON sắp commit xem có đoạn nào KHÔNG PHẢI placeholder (tức đã bị
   user điền giá trị thật rồi export ra) — nếu thấy, thay thế bằng đúng placeholder gốc
   (`PASTE_YOUR_<TEN_SERVICE>_TOKEN_HERE`) TRƯỚC khi add/commit, không commit nguyên văn.
3. Danh sách các node/workflow hiện đang dùng cách hardcode này (cập nhật khi thêm mới):
   - `Telebot ClickUp Reader` (`9JJRrh36H2rLwtnu`), node `Send Zalo Notify` — URL chứa
     `PASTE_YOUR_ZALO_BOT_TOKEN_HERE`.
   - `Zalo API - Webhook Test` (`eFH2UIbQirfXSH1b`), node `Call Zalo setWebhook` + `Call Zalo getMe`
     — cùng placeholder trên.
4. Vì giá trị thật CHỈ tồn tại trong chính n8n instance (không có ở đâu khác), file JSON trong git
   không cần khớp 100% với bản đang chạy — mục đích của git ở đây là lưu CẤU TRÚC workflow (node,
   connection, logic), không phải bản backup runtime đầy đủ. Backup runtime thật đã có cơ chế riêng
   (`/backup_n8n`, mã hoá credential) — không dùng git repo cho việc đó.

## 18. 🔴 `addNode` thêm node MỚI vào 1 chuỗi đang chạy sống — BẮT BUỘC kèm `setNodeSettings` TRONG CÙNG BATCH nếu node đó có thể trả 0 dòng/lỗi

**Đã lặp lại lỗi này 3 LẦN trong dự án** (08/09 — Gateway pending-check làm sập TOÀN BỘ bot cho mọi
user; 08/09 cùng ngày — OD Task Lookup/Resolve/Upload HTTP; 09/09 — `Ensure Notify Queue Columns`
làm gãy bước cuối Upload OneDrive, "xóa hết tin cũ nhưng không thấy tin mới"). Nguyên nhân LUÔN
GIỐNG NHAU: thao tác `addNode` của n8n MCP **KHÔNG nhận** `alwaysOutputData`/`onError` như field cấp
1 của object `node` — dù không báo lỗi/warning gì, 2 field này bị ÂM THẦM BỎ QUA. Hậu quả: node DDL
(`CREATE TABLE`/`ALTER TABLE`, không có `RETURNING`) hoặc gọi API ngoài có thể lỗi, khi trả về 0 kết
quả sẽ làm **toàn bộ chuỗi phía sau ngừng chạy** mà không có execution nào ghi nhận lỗi — vì bản
thân node đó vẫn "success", chỉ là 0 item.

**Quy tắc bắt buộc, không có ngoại lệ**: mỗi khi `addNode` thêm 1 node kiểu sau vào ĐÚNG con đường mà
1 luồng đang sống đi qua (không phải nhánh test/manual riêng biệt):
- Postgres DDL (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`) không có
  `RETURNING` → luôn cần `alwaysOutputData: true`.
- HTTP Request gọi API bên ngoài (Zalo, Microsoft Graph, OpenRouter...) mà lỗi tạm thời không nên
  làm gãy cả chuỗi → cân nhắc `onError: "continueRegularOutput"`.

PHẢI thêm `setNodeSettings` cho node đó làm operation NGAY TIẾP THEO, **TRONG CÙNG 1 lần gọi
`update_workflow`** (không tách thành 2 lần gọi riêng — thực tế cho thấy tách ra rất dễ QUÊN làm
bước 2, đã quên 3/3 lần). Sau đó BẮT BUỘC `get_workflow_details` xác nhận `alwaysOutputData`/
`onError` đã có mặt thật ở node đó trước khi `publish_workflow` — không tin `appliedOperations`.

Mẫu đúng (viết trong 1 batch operations):
```json
[
  { "type": "addNode", "node": { "id": "...", "name": "Ensure X", "type": "n8n-nodes-base.postgres", ... } },
  { "type": "setNodeSettings", "nodeName": "Ensure X", "settings": { "alwaysOutputData": true, "onError": "continueRegularOutput" } }
]
```

## 19. 🔴 Thêm 1 cột dữ liệu mới "đi nhờ" qua NHIỀU workflow — PHẢI liệt kê ĐỦ mọi điểm ĐỌC lẫn GHI, không dựa vào trí nhớ

Xảy ra thật 09/09/2026 khi thêm `student_name`/`task_url` cho tin nhắn forward Upload OneDrive: nhớ
sửa đủ 2 điểm GHI (`Upsert Pending Upload (Pick)` và `(Custom Prompt)` trong `Telebot ClickUp
Reader`) nhưng **quên mất 1 điểm ĐỌC** — `GW-04 Check Pending Upload` trong `GW Gateway - Telegram`
vẫn SELECT các cột CŨ từ `clickup.pending_uploads`, nên giá trị mới luôn `undefined` khi tới bước
build tin nhắn (hiện "Không rõ"). Không có lỗi/warning nào báo — vì SELECT thiếu cột không phải lỗi,
chỉ đơn giản trả về `undefined` cho field không có trong câu SELECT.

Tương tự, cùng đợt việc còn quên ALTER 1 trong 2 bảng dùng chung tên cột (`pending_uploads` vs
`upload_notify_queue`) — xem RULES.md #18, lỗi khác nhưng CÙNG GỐC: quên rà hết các nơi liên quan
khi mở rộng 1 cấu trúc dữ liệu đang "đi nhờ" qua nhiều workflow/bảng.

**Quy tắc bắt buộc**: trước khi coi việc "thêm 1 cột dữ liệu mới cho tính năng X" là XONG, phải:
1. `grep`/liệt kê TOÀN BỘ workflow + bảng có liên quan tới tính năng đó (không chỉ workflow đang
   sửa) — tính năng nào đi qua ranh giới Gateway ↔ sub-workflow gần như CHẮC CHẮN có ít nhất 1 điểm
   Gateway cần cập nhật theo (xem kiến trúc ở `ARCHITECTURE.md` mục 4b).
2. Với MỖI bảng bị ảnh hưởng, liệt kê cả 2 loại điểm: nơi GHI (INSERT/UPDATE) và nơi ĐỌC (SELECT) —
   dễ nhớ ghi, dễ quên đọc, vì đọc thường nằm ở 1 workflow KHÁC (Gateway) so với nơi đang sửa chính
   (sub-workflow nghiệp vụ).
3. Sau khi sửa xong, test bằng dữ liệu thật đi hết đường (không chỉ test riêng lẻ từng workflow) —
   hoặc dùng `test_workflow`/`prepare_workflow_pin_data` để mô phỏng input thật xuyên node logic
   (Code/IF/Switch chạy thật, Postgres/HTTP/Telegram bị pin nên an toàn không gửi tin thật) khi
   không thể test qua Telegram thật ngay lúc đó.

## 20. ⚙️ Quy trình bắt buộc build/sửa workflow (quyết định 09/09/2026 — xem đầy đủ ở `PROJECT_STATUS.md` mục "QUY TRÌNH BẮT BUỘC")

Tóm tắt (bản đầy đủ + lý do ở PROJECT_STATUS.md, luôn đọc ở đó trước — file này chỉ trỏ lại):
1. Đọc RULES.md + FAQ.md liên quan TRƯỚC khi sửa (không lướt tiêu đề).
2. Gọi n8n skill phù hợp (`n8n-workflow-patterns`, `n8n-node-configuration`, `n8n-validation-expert`,
   `n8n-code-javascript`, `n8n-subworkflows`...) TRƯỚC khi viết code/thiết kế node.
3. Thêm cột dữ liệu mới/đụng ranh giới Gateway↔sub-workflow → liệt kê ĐỦ điểm đọc + ghi trước (#19).
4. `addNode` cho node DDL/API ngoài → `setNodeSettings` NGAY TRONG CÙNG batch (#18).
5. Sau khi sửa, `get_workflow_details` xác nhận đúng giá trị TRƯỚC khi publish — không tin
   `appliedOperations` (#16). Sai → `removeNode`+`addNode` lại, không thử lại y hệt.
6. Trigger không execute trực tiếp qua MCP được → `prepare_workflow_pin_data`+`test_workflow` mô
   phỏng trước khi để user tự test qua Telegram thật.
7. `publish_workflow` ngay sau mỗi update trên workflow active (#12).
8. Thay đổi vừa/lớn (≥3 node, đụng ranh giới Gateway↔sub-workflow, hoặc thêm cột dữ liệu mới) → dùng
   tool `Agent` spawn 1 subagent ĐỘC LẬP audit lại so với RULES.md/FAQ.md sau khi publish, trước khi
   báo "xong" cho user — không tự chấm điểm chính mình bằng đúng các bước vừa làm.
9. Cập nhật `PROJECT_STATUS.md` + `CHANGELOG.md` ngay, dù chưa có xác nhận test thật qua Telegram.
