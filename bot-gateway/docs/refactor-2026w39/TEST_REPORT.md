# TEST_REPORT — refactor 2026-W39

## REG — 2026-09-25T03:40:00Z

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| REG-LU-01 | — | prod | STATIC | JSON Live Update | `⚙️ Config`: retry 5x, 5000ms | `"retryOnFail":true,"maxTries":5,"waitBetweenTries":5000` | — | ✅ PASS |
| REG-OCR-02 | — | prod | STATIC | JSON Bot Xử Lý Ảnh | Tham chiếu `$('Tóm Tắt Bằng AI').item.json.text` | `"text":"={{ $('Tóm Tắt Bằng AI').item.json.text }}"` | — | ✅ PASS |
| REG-OCR-03 | — | prod | STATIC | exec 8453 runData | Send Ack < Call OCR startTime | 1790239555239 < 1790239556141 | 8453 | ✅ PASS |
| REG-OCR-04 | — | prod | PIN | `/tomtat` + ảnh, OCR error pin | Chạy Delete Ack (Failed) → Reply Failed | Format OCR Result chạy (output 0) | 9207 | ⚠️ PENDING: pin data cần output index 1 |
| REG-OCR-05 | — | — | Harness | LangChain node | 1 item in = 1 item out | exec 9207: Tóm Tắt Bằng AI 1 item | 9207 | ✅ PASS |
| REG-OCR-01 | — | — | REAL | Telegram getFile + Code + extractFromFile | `data` > 50,000 ký tự | Chưa test (TEMP workflow cần) | — | ⏳ PENDING |
| REG-VPS-01..05 | — | — | PIN | Admin System routes | Đúng node đích | Chưa test | — | ⏳ PENDING |
| REG-VPS-06 | — | — | MANUAL | Restart container portainer | Tin xác nhận | — | — | ⏳ PENDING |

## REG vòng 2 — 2026-09-25T02:00:00Z

Chuẩn bị: `search_workflows` tên chứa "TEMP" trong project `5cL5BKorhKAQ2ONI` chỉ thấy `TEMP - List Sheet Tabs (xoá sau khi dùng)` (`JaJwjr8482unTjZw`, tạo `2026-09-21`) — KHÔNG phải TEMP tạo hôm nay (25/09) → không đụng, đúng chỉ dẫn "chỉ archive TEMP tạo hôm nay". Không có rác TEMP nào của tester trước cần dọn.

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| REG-OCR-04 | — | prod (cấu trúc) | PIN thử lại + TEMP repro | Xác nhận lại: `prepare_workflow_pin_data` cho `Call Qwen OCR` trả schema output-lỗi (`{error, error_description}`) nhưng n8n pinData không có trường output-index — không có cách chọn output 1 qua PIN chuẩn (đã xác nhận lại bằng exec `9207` của tester trước: pin data hình lỗi vẫn chạy qua output 0). Dựng TEMP `soUk4P2DVwbIhkxW` tái hiện đúng connections thật của `Call Qwen OCR` (trích từ `get_workflow_details` prod: `"Call Qwen OCR":{"main":[[{"node":"Format OCR Result"}],[{"node":"Delete Processing Ack (Failed)"}]]}`): HTTP Request GET `https://httpbin.org/status/500`, `onError:"continueErrorOutput"` → output0→`Format OCR Result (copy)`→`Tom Tat Bang AI (ghi lại)`; output1→`Delete Processing Ack (Failed) (ghi lại)`→`Reply OCR Failed (ghi lại)` | Chạy Delete Ack (Failed) → Reply Failed; KHÔNG chạy Tóm Tắt Bằng AI | Node "Call Qwen OCR (TEMP repro)" trả lỗi thật (`"status":500`, `AxiosError`) đi ra **output 1**; runData chỉ có `Delete Processing Ack (Failed) (ghi lai)` và `Reply OCR Failed (ghi lai)` — KHÔNG có `Format OCR Result (copy)` / `Tom Tat Bang AI (ghi lai)` trong runData | exec `9245`, TEMP `soUk4P2DVwbIhkxW` (đã archive) | ✅ PASS |
| REG-OCR-01 | — | prod (logic thật) | REAL (TEMP) | `file_id` ảnh từ exec `7931` (`AgACAgUAAyEFAAS1ep7DAAJY_Wq0gR8DbtHBvK7aPk9COeoNEslkAAJpEmsbiNehVdR6Y4TXpy9kAQADAgADeAADPQQ`), credential `Elite Clickupbot` (`BHVAx8GV38yQEn1I`) copy từ node `Tải Ảnh Về (Vision)` prod | `data` (base64) tồn tại, độ dài > 50.000 ký tự | Telegram getFile thật OK: `"ok":true,"result":{"file_id":"AgAC...","file_size":75630,"file_path":"photos/file_365"}`. Set "Ack giả lập" xoá binary (includeOtherFields:false). Code `Đính Kèm Lại Ảnh (Sau Ack)` copy nguyên logic prod (chỉ đổi tên node tham chiếu từ `Tải Ảnh Về (Vision)` → `Tai Anh Ve (Vision) (TEMP)`) gắn lại binary OK (`binary: {"data": ...}` có mặt). `To Base64 (OCR) (TEMP)` (extractFromFile binaryToPropery, property `data`) chạy `success`, `json.data.length == 100840` (> 50.000) | exec `9248`, TEMP `2EBpel5ahWf6a8e1` (đã archive; lần tạo đầu `Qoq9odUZcLccKSAg` bị auto-assign nhầm credential `@csfsintbot` → archive luôn, không chạy) | ✅ PASS |
| REG-VPS-01 | — | prod | PIN (`test_workflow`, không đổi workflow) | `/vps` từ chat admin `975005174` (corpus `ADM-01_vps.json`); `Call VPS Info` pin = output thật exec `6791` (6 container thật, có `id`) | Text có `?start=vpsc_<12 hex>` cho mỗi container | `Send VPS Stats` chạy, text chứa `...?start=vpsc_0b13df56a8c2">🔍 chi tiết</a>`, `...vpsc_211ebda7fd24...`, `...vpsc_016d6fddd3b2...` (3 dòng mẫu, đủ 6 container) | exec `9239` | ✅ PASS |
| REG-VPS-02 | — | prod | PIN | `/start vpsc_0b13df56a8c2` từ chat admin (deep-link, ADM-02 dạng); `Call Container Info` pin = output thật exec `6792` (container `0b13df56a8c2`) | Tới `Send Container Detail`; nút `vpsrestart_0b13df56a8c2` + `vpscancel` | `Build Container Detail.json.containerId == "0b13df56a8c2"`; `Send Container Detail` chạy. Nút xác nhận bằng cấu hình node thật (`Send Container Detail.parameters.inlineKeyboard`: `callback_data:"={{ 'vpsrestart_' + $('Build Container Detail').first().json.containerId }}"` + nút cố định `callback_data:"vpscancel"`) đối chiếu corpus `ADM-03_callback_vpsrestart.json` (exec `6795` thật, cùng container khác id, cùng mẫu `vpsrestart_<id>` + `vpscancel`) | exec `9240` | ✅ PASS |
| REG-VPS-03 | — | prod | PIN | `/start vpsc_ffffffffffff` từ chat admin (deep-link id không tồn tại); `Call Container Info` pin = `{"error":"not_found"}` | Tới `Reply Container Info Failed` | `Container Info OK?` ra output 1 (false); `Reply Container Info Failed` chạy; `Build Container Detail` KHÔNG có trong runData | exec `9241` | ✅ PASS |
| REG-VPS-04 | — | prod | PIN | `/vps` từ chat `111111111` (không phải admin `975005174`) | Tới `Reply Không Có Quyền (VPS)`, không gọi `Call VPS Info` | `Check Admin (VPS)` ra output 1 (false, `chatId:"111111111"` ≠ `ADMIN_CHAT_ID:"975005174"`); `Reply Không Có Quyền (VPS)` chạy; `Call VPS Info` KHÔNG có trong runData | exec `9242` | ✅ PASS |
| REG-VPS-05 | — | prod | PIN | callback `vpscancel` từ chat admin (corpus `ADM-04_callback_vpscancel.json`) | Tới `Reply VPS Cancelled` | `Phân tích lệnh.json.route == "vps_cancel"`; `Switch` ra thẳng `Reply VPS Cancelled` (không qua `Check Admin (VPS Extra)` — route này không có cổng admin trong prod, đúng hành vi thật); `Reply VPS Cancelled` chạy | exec `9243` | ✅ PASS |
| REG-VPS-06 | — | — | MANUAL | Restart container portainer | Tin xác nhận | — (chưa làm, cần người trực + SSH/docker thật) | — | ⏳ PENDING (MANUAL) |

## Tóm tắt (sau REG vòng 2)

**Kết quả theo trạng thái:**
- ✅ PASS: 12 tests (REG-LU-01, OCR-01, OCR-02, OCR-03, OCR-04, OCR-05, VPS-01, VPS-02, VPS-03, VPS-04, VPS-05 — 11 mục trong bảng, REG-VPS-01..05 đếm là 5 dòng riêng)
- ⏳ PENDING (MANUAL, đúng theo PLAN — chỉ làm khi có người trực khung cutover): 1 test (REG-VPS-06)
- ❌ FAIL: 0

**Danh sách FAIL:** không có.

**Production checksum (versionId == activeVersionId, xác nhận lại cuối REG vòng 2 lúc 2026-09-25T02:00Z):**
- Bot Xử Lý Ảnh (`6I4MnJiJCiv2JOIr`): `435af575-e17f-488e-b616-20798790bbdf` ✓ (không đổi)
- Admin System (`eWtu7Qs85Hes0HuP`): `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f` ✓ (không đổi)
- Live Update: `42cfa99b-6659-47dd-8a84-f9fa4e977739` ✓ (không đụng lại trong vòng 2)

**TEMP workflows tạo trong REG vòng 2 + xác nhận archive:**
- `soUk4P2DVwbIhkxW` — "TEMP - REG-OCR-04 nhánh lỗi OCR (xoá sau khi dùng)" — archived ✓ (archive_workflow trả `"archived":true`)
- `Qoq9odUZcLccKSAg` — "TEMP - REG-OCR-01 getFile (xoá sau khi dùng)" — bản đầu bị auto-assign nhầm credential Telegram (`@csfsintbot` thay vì `Elite Clickupbot`), archive ngay không chạy — archived ✓
- `2EBpel5ahWf6a8e1` — "TEMP - REG-OCR-01 getFile (xoá sau khi dùng)" — bản sửa credential đúng (`BHVAx8GV38yQEn1I`), đã chạy REAL test thành công — archived ✓

**Ghi chú kỹ thuật:**
- Xác nhận: n8n `pinData` chuẩn (`prepare_workflow_pin_data` + `test_workflow`) không hỗ trợ chọn output index cho node nhiều output (HTTP Request `onError:continueErrorOutput`) — dữ liệu pin luôn chảy qua output 0 bất kể hình dạng dữ liệu giống output nào. Đây là giới hạn của cơ chế pin trong n8n, không phải lỗi workflow. REG-OCR-04 phải dùng TEMP tái hiện cấu trúc connection thật (bằng chứng: connections trích từ `get_workflow_details` production).
- REG-VPS-02: nút bấm được xác nhận bằng 2 nguồn — (1) `containerId` runtime từ PIN test (`0b13df56a8c2`), (2) cấu hình `callback_data` thật đọc tĩnh từ node `Send Container Detail` trong production, đối chiếu thêm với corpus thật `ADM-03` (exec `6795`, container khác nhưng cùng định dạng `vpsrestart_<id>` + `vpscancel`).
- REG-VPS-05: hành vi thật của prod là `vps_cancel` đi thẳng từ `Switch` sang `Reply VPS Cancelled`, KHÔNG qua cổng `Check Admin (VPS Extra)` — nghĩa là bất kỳ ai bấm nút Huỷ cũng được (không nhạy cảm). Ghi lại đúng hành vi quan sát được, không phải giả định từ PLAN.
- Không có test nào phải sửa PLAN hay đổi production. Không commit git.

## WP1 (một phần) — 2026-09-25T06:25:00Z

Workflow staging test: `GW Error Handler v2 (STAGING)` (`MaoEB8w8Un6UA01n`), `versionId` xác nhận
`4f7d5a4b-c6e3-436a-be87-b85793b039bf` (khớp yêu cầu). Không publish, không dùng mode production,
không sửa workflow. Bảng `gateway.error_alert_throttle` CHƯA tồn tại (WP2 chưa chạy migration, chờ
user) → ERR-01, ERR-02, ERR-05, ERR-07 (PROD-FAIL thật, cần bảng + publish harness) → PENDING.

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| ERR-03 | WP1 | v2 | STATIC | `get_workflow_details(MaoEB8w8Un6UA01n)` | 0 node `n8n-nodes-base.code` | `jq '[.nodes[]\|select(.type=="n8n-nodes-base.code")]\|length'` = `0`; `nodeCount=5`; `versionId="4f7d5a4b-c6e3-436a-be87-b85793b039bf"` | get_workflow_details (không có execution) | ✅ PASS |
| ERR-04 | WP1 | v2 | PIN | Pin `Error Trigger` = payload thật từ v1 exec `7143` (trích qua exec `7145` của `34ccboHpyoY2r691`, node `Error Trigger`); pin `Ghi Lỗi + Kiểm Tra Gộp` = `{"log_id":99999,"should_alert":true}`; pin `Báo admin Telegram` = `{"ok":true,"result":{"message_id":1,...}}` | Postgres chạy trước Telegram; IF → true; text Telegram = text `Chuẩn Hoá Lỗi` = đúng định dạng v1 | `Ghi Lỗi + Kiểm Tra Gộp` startTime `1790317413775` (executionIndex 2) < `Báo admin Telegram` startTime `1790317413780` (executionIndex 4); `Cần Gửi Cảnh Báo?` output0=1 item / output1=0 item (true); `Chuẩn Hoá Lỗi.text`="🚨 LỖI WORKFLOW\n📋 SQL - ClickUp Live Update (Webhook)\n📍 Node: ⚙️ Config (Admin Chat ID)\n❌ Task execution aborted because runner became unresponsive\n🔗 https://n8n.toididuhoc.net/workflow/uqTqjtHYieotPZuc/executions/7143" — **byte-giống hệt** v1 `Format lỗi.text` (exec 7145, cùng input): "🚨 LỖI WORKFLOW\n📋 SQL - ClickUp Live Update (Webhook)\n📍 Node: ⚙️ Config (Admin Chat ID)\n❌ Task execution aborted because runner became unresponsive\n🔗 https://n8n.toididuhoc.net/workflow/uqTqjtHYieotPZuc/executions/7143" | test_workflow exec `9503` (v2); đối chiếu v1 exec `7145` (`34ccboHpyoY2r691`) | ✅ PASS (param `text` thật của node Telegram không quan sát được trực tiếp vì node bị PIN theo luật 5.3 — chứng minh gián tiếp qua JSON node dùng `={{ $('Chuẩn Hoá Lỗi').first().json.text }}` tường minh + giá trị nguồn khớp v1) |
| ERR-04b | WP1 | v2 | PIN | Như ERR-04 nhưng `Ghi Lỗi + Kiểm Tra Gộp` = `{"log_id":99999,"should_alert":false}` | IF → false; Telegram KHÔNG chạy | `lastNodeExecuted`="Cần Gửi Cảnh Báo?"; runData KHÔNG có key "Báo admin Telegram"; `Cần Gửi Cảnh Báo?` output0=`[]`, output1=1 item (`should_alert:false`) | test_workflow exec `9504` | ✅ PASS |
| ERR-06 | WP1 | v2 | PIN | `Ghi Lỗi + Kiểm Tra Gộp` = `{"error":"connection refused"}` (không có `log_id`) | `!$json.log_id` → true; Telegram chạy với text đúng | `Cần Gửi Cảnh Báo?` output0=1 item (`{"error":"connection refused"}`), output1=`[]`; `Báo admin Telegram` có trong runData (executionIndex 4); `Chuẩn Hoá Lỗi.text` không đổi so với ERR-04 (cùng payload Error Trigger) | test_workflow exec `9505` | ✅ PASS |
| ERR-07 (một phần) | WP1 | v2 | PIN | Pin `Error Trigger.execution.error.message` = `a, b 'c' "d"`; pin Postgres = `{"log_id":99998,"should_alert":true}` | `Chuẩn Hoá Lỗi.errorMessage` giữ nguyên vẹn dấu phẩy/nháy; `queryReplacement` dùng mảng tham số hoá $1..$6 (không nối chuỗi SQL) | `Chuẩn Hoá Lỗi.errorMessage` = `"a, b 'c' \"d\""` (nguyên vẹn, không bị cắt/escape sai); STATIC: `query` node Postgres dùng `VALUES ($1,$2,$3,$4,$5,$6)` + `queryReplacement="={{ [ $json.workflowName, $json.workflowId, $json.nodeName, $json.errorMessage, ... ] }}"` — `errorMessage` ở vị trí `$4`, truyền qua tham số hoá driver (không nối chuỗi) nên về mặt cấu trúc an toàn với dấu phẩy/nháy | test_workflow exec `9506` | ✅ PASS một phần — **chưa chứng minh được** dòng `error_logs` thật ghi đúng 6 cột vì node Postgres bị PIN (không có DB); phần DB thật thuộc ERR-07 đầy đủ, PENDING chờ WP2 |
| ERR-01 | WP1 | v2 | PROD-FAIL | — | 1 execution handler success; `error_logs` +1 dòng; đúng 1 tin topic lỗi | — | — | ⏳ PENDING — chờ WP2 chạy migration tạo bảng `gateway.error_alert_throttle`; test PROD-FAIL cần publish harness TEMP (bị cấm trong lượt test này) |
| ERR-02 | WP1 | v2 | PROD-FAIL | 20 lần gọi burst | ≤1 tin/phút, `suppressed_count` đúng | — | — | ⏳ PENDING — chờ WP2 chạy migration + publish harness |
| ERR-05 | WP1 | v2 | PROD-FAIL | Harness 2 tầng (Execute Workflow lỗi) | Handler v2 nhận lỗi của sub | — | — | ⏳ PENDING — chờ WP2 chạy migration + publish harness |

**Tóm tắt WP1 (một phần):**
- ✅ PASS: 5 (ERR-03, ERR-04, ERR-04b, ERR-06, ERR-07-một-phần)
- ❌ FAIL: 0
- ⏳ PENDING: 3 (ERR-01, ERR-02, ERR-05 — đều PROD-FAIL thật, chặn bởi bảng `gateway.error_alert_throttle` chưa tạo (WP2 chưa chạy, chờ user) + không được publish workflow trong lượt test này)

**TEMP workflow đã tạo:** không có — toàn bộ test dùng `prepare_workflow_pin_data` + `test_workflow` trên
chính workflow staging `MaoEB8w8Un6UA01n`, không tạo/publish/archive workflow nào khác. Không gửi
Telegram thật, không ghi DB thật, không đổi node nào của `MaoEB8w8Un6UA01n` (chỉ đọc qua
`get_workflow_details` + `test_workflow` với pinData truyền trực tiếp, không `update_workflow`).

## WP1 (phần 1: STATIC + PIN) — 2026-09-25T06:25:31Z

Bối cảnh: migration WP2 (bảng `gateway.error_alert_throttle`) CHƯA chạy (chờ user duyệt). ERR-01, ERR-02,
ERR-04 (phần runtime), ERR-05, ERR-07 (chính) → PENDING, lý do "chờ WP2 migration được duyệt". Không tạo
harness Webhook, không publish gì. Workflow test: `MaoEB8w8Un6UA01n` — `GW Error Handler v2 (STAGING)`.

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| ERR-03 | WP1 | v2 staging (`4f7d5a4b-c6e3-436a-be87-b85793b039bf`) | STATIC | `get_workflow_details` → `jq -r '.nodes[].type'` | 0 node `n8n-nodes-base.code` | `["n8n-nodes-base.errorTrigger","n8n-nodes-base.set","n8n-nodes-base.postgres","n8n-nodes-base.if","n8n-nodes-base.telegram"]`; `jq '[...code...] | length'` = `0` | (STATIC, không execution) | ✅ PASS |
| ERR-04 (STATIC) | WP1 | v2 staging | STATIC | `connections` JSON | Postgres đứng trước Telegram trên đồ thị: Error Trigger → Chuẩn Hoá Lỗi → Ghi Lỗi + Kiểm Tra Gộp → Cần Gửi Cảnh Báo? → (output 0) Báo admin Telegram | `"Error Trigger":{"main":[[{"node":"Chuẩn Hoá Lỗi"...}]]},"Chuẩn Hoá Lỗi":{"main":[[{"node":"Ghi Lỗi + Kiểm Tra Gộp"...}]]},"Ghi Lỗi + Kiểm Tra Gộp":{"main":[[{"node":"Cần Gửi Cảnh Báo?"...}]]},"Cần Gửi Cảnh Báo?":{"main":[[{"node":"Báo admin Telegram","index":0}]]}` | (STATIC, không execution) | ✅ PASS |
| ERR-04 (runtime) | WP1 | v2 staging | PROD-FAIL | — | Postgres chạy trước Telegram trong runData thật (execution burst) | — | — | ⏳ PENDING (chờ WP2 migration được duyệt) |
| ERR-06 | WP1 | v2 staging | PIN | Pin `Error Trigger` = envelope lỗi mẫu (`execution.error.message`="TEST WP1, a 'b' \"c\"", `workflow.name`="TEMP - Cố Ý Lỗi (xoá sau khi dùng)", `execution.lastNodeExecuted`="Cố Ý Lỗi"); pin `Ghi Lỗi + Kiểm Tra Gộp` = `{"error":"connection refused"}` (không `log_id`); pin `Báo admin Telegram` = response Telegram mẫu | IF ra nhánh true; `Báo admin Telegram` có trong runData; `Chuẩn Hoá Lỗi`.text đúng định dạng | `Cần Gửi Cảnh Báo?` output: `[[{"error":"connection refused"}],[]]` (nhánh 0 = true, có item; nhánh 1 rỗng); `Báo admin Telegram` có trong runData (pinned response echo `"message_id":24681`); `Chuẩn Hoá Lỗi.text` = `"🚨 LỖI WORKFLOW\n📋 TEMP - Cố Ý Lỗi (xoá sau khi dùng)\n📍 Node: Cố Ý Lỗi\n❌ TEST WP1, a 'b' \"c\"\n🔗 https://n8n.fachkraft.internal/workflow/xmEKeIUnzxm2F7dF/executions/9990001"` | exec `9507` | ✅ PASS |
| ERR-06b | WP1 | v2 staging | PIN | Pin `Ghi Lỗi + Kiểm Tra Gộp` = `{"log_id":1,"should_alert":true}`; pin Error Trigger + Telegram tương tự ERR-06 | IF true → Telegram chạy | `Cần Gửi Cảnh Báo?` data: `[[{"log_id":1,"should_alert":true}],[]]`; `Báo admin Telegram` CÓ trong runData, `"text":"pinned-telegram-response-06b"` | exec `9509` | ✅ PASS |
| ERR-06c | WP1 | v2 staging | PIN | Pin `Ghi Lỗi + Kiểm Tra Gộp` = `{"log_id":2,"should_alert":false}`; pin Error Trigger + Telegram tương tự | IF false → Telegram KHÔNG chạy | `Cần Gửi Cảnh Báo?` data: `[[],[{"log_id":2,"should_alert":false}]]`; `runData` KHÔNG có key `"Báo admin Telegram"`; `lastNodeExecuted`="Cần Gửi Cảnh Báo?" | exec `9510` | ✅ PASS |
| ERR-07 (phụ, evidence cho ERR-06) | WP1 | v2 staging | PIN (bằng chứng phụ) | queryReplacement của node `Ghi Lỗi + Kiểm Tra Gộp` trong ERR-06 | 6 tham số đúng thứ tự, message có dấu phẩy/nháy không tách | Node Postgres BỊ PIN (bắt buộc theo luật PIN — không có node Postgres/Telegram nào chạy thật) → n8n không evaluate `queryReplacement` cho node pinned, không có `inputOverride`/resolved params trong runData exec 9507/9509/9510 để trích. `options.queryReplacement` (nguồn workflow JSON, chưa evaluate) = `={{ [ $json.workflowName, $json.workflowId, $json.nodeName, $json.errorMessage, $json.executionId, $json.executionUrl ] }}` — đúng 6 tham số, đúng thứ tự theo spec PLAN 6 WP1 bước 3; giá trị `errorMessage` đầu vào (`Chuẩn Hoá Lỗi.errorMessage`) = `"TEST WP1, a 'b' \"c\""` nguyên vẹn không bị tách bởi dấu phẩy/nháy (single string field) | exec 9507 | ⚠️ Bằng chứng gián tiếp (không PASS/FAIL — không thể trích giá trị resolved vì node bị pin theo luật; ERR-07 chính vẫn PENDING) |
| ERR-01 | WP1 | v2 staging | PROD-FAIL | — | — | — | — | ⏳ PENDING (chờ WP2 migration được duyệt) |
| ERR-02 | WP1 | v2 staging | PROD-FAIL | — | — | — | — | ⏳ PENDING (chờ WP2 migration được duyệt) |
| ERR-05 | WP1 | v2 staging | PROD-FAIL | — | — | — | — | ⏳ PENDING (chờ WP2 migration được duyệt) |
| ERR-07 (chính) | WP1 | v2 staging | PROD-FAIL | — | — | — | — | ⏳ PENDING (chờ WP2 migration được duyệt) |

**Tóm tắt WP1 (phần 1):** PASS 5 (ERR-03, ERR-04 STATIC, ERR-06, ERR-06b, ERR-06c) · FAIL 0 · PENDING 5
(ERR-01, ERR-02, ERR-04 runtime, ERR-05, ERR-07 chính — chờ WP2 migration được duyệt) · 1 bằng chứng phụ
không tính PASS/FAIL (ERR-07 queryReplacement, xem ghi chú ở trên). Không tạo workflow TEMP nào (không
dùng harness Webhook theo yêu cầu) → không có gì cần archive. `versionId` của `MaoEB8w8Un6UA01n` xác nhận
KHÔNG đổi: `4f7d5a4b-c6e3-436a-be87-b85793b039bf` (trước và sau test). Mọi node Postgres + Telegram đã
được pin ở cả 3 lần chạy PIN — không có ghi/gửi thật nào xảy ra.

## WP3 — GW Gateway v2 — 2026-09-25T06:30:00Z

Chuẩn bị: `search_workflows` tên chứa "TEMP" trong project `5cL5BKorhKAQ2ONI` chỉ thấy `TEMP - List Sheet Tabs (xoá sau khi dùng)` (`JaJwjr8482unTjZw`, tạo 2026-09-21) — không phải TEMP tạo hôm nay 25/09, không đụng. Không thấy TEMP nào của tester WP3 lượt trước cần archive (lượt trước bị ngắt trước khi tạo TEMP nào / trước khi ghi TEST_REPORT). Không thấy TEMP "WP2" nào đang chạy song song tại thời điểm bắt đầu — không đụng gì.

Phương pháp: DIFF, `prepare_workflow_pin_data` + `test_workflow` (không `update_workflow`/`publish_workflow` trên v1 `xmEKeIUnzxm2F7dF` hay v2 `hn0YZ85sXtfGACJ4`). Pin mọi lần: `Telegram Trigger Gateway` (=update từ corpus), `GW-02 Auth Lookup` (=trạng thái mong muốn), `GW-04 Check Pending Upload` (0 hoặc 1 dòng), `Check admin`, mọi node Telegram gửi/ghi, mọi Postgres/Supabase (Audit Log, Tạo pending user, Approve/Deny, Ghi Log Tin Nhắn Nhóm, Ensure Pending Uploads Table — chỉ v1), mọi `executeWorkflow` (`→ Sub: Telebot ClickUp Reader/Image Bot/Lock Bot`, `Trigger Mention Resolver (Gateway)`; `→ Sub: Help Bot`/`→ Sub: Crawl Bot` đã `disabled` sẵn từ v1, không cần pin).

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| GW-01 | WP3 | v1 | DIFF | `/task nguyễn thị thảo vân` (private, user active, bots=[telebot_main]) (synthetic: pin auth) | `route=telebot_main`; chạy `→ Sub: Telebot ClickUp Reader` | `"route":"telebot_main"`; `→ Sub: Telebot ClickUp Reader` có trong runData | exec 9512 | ✅ PASS |
| GW-01 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"`; `→ Sub: Telebot ClickUp Reader` có trong runData | exec 9513 | ✅ PASS |
| GW-02 | WP3 | v1 | DIFF | `/tomtat` + ảnh (synthetic, derived từ exec 6710), active bots=[image_bot] | `route=image_bot`; chạy `→ Sub: Image Bot` | `"route":"image_bot"`; `→ Sub: Image Bot` chạy (output index 5) | exec 9515 | ✅ PASS |
| GW-02 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"`; `→ Sub: Image Bot` chạy (output index 5) | exec 9516 | ✅ PASS |
| GW-03 | WP3 | v1 | DIFF | `/xoanen` + ảnh (thật, exec 6710 gốc), active bots=[image_bot] | `route=image_bot` | `"route":"image_bot"` | exec 9517 | ✅ PASS |
| GW-03 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"` | exec 9518 | ✅ PASS |
| GW-19 | WP3 | v1 | DIFF (trích từ exec GW-01) | bất kỳ (dùng GW-01) | v1: 2 node audit chạy | `Audit Log (Docker)` VÀ `Audit Log (Supabase)` đều có trong runData exec 9512 | exec 9512 | ✅ PASS |
| GW-19 | WP3 | v2 | DIFF (trích từ exec GW-01) | bất kỳ (dùng GW-01) | v2: đúng 1 node `Audit Log (Docker)` chạy | Chỉ `Audit Log (Docker)` có trong runData exec 9513; không có key `Audit Log (Supabase)` (node không tồn tại ở v2) | exec 9513 | ✅ PASS |
| GW-20 | WP3 | v1 | STATIC (trích từ exec GW-01) | bất kỳ | `⚙️ Config` kiểu thực tế: COMMAND_MAP object, AVAILABLE_BOTS array | `"ADMIN_CHAT_ID":"975005174"` (string), `"AVAILABLE_BOTS":["telebot_main","help_bot","image_bot","lock_bot"]` (array), `"COMMAND_MAP":{"task":"telebot_main",...}` (object), `"DEFAULT_BOT":"help_bot"` (string) | exec 9512 | ✅ PASS |
| GW-20 | WP3 | v2 | STATIC (trích từ exec GW-01) | bất kỳ | Set node cho ra cùng kiểu thực tế | `"ADMIN_CHAT_ID":"975005174"` (string), `"AVAILABLE_BOTS":["telebot_main","help_bot","image_bot","lock_bot"]` (array), `"COMMAND_MAP":{"task":"telebot_main",...}` (object), `"DEFAULT_BOT":"help_bot"` (string) — DEEP EQUAL với v1 | exec 9513 | ✅ PASS |

## WP3 — 2026-09-25T06:30:00Z (tester, chạy lại từ đầu sau rate-limit ở lượt trước)

Phương pháp DIFF cho GW-01..GW-19: pin `Telegram Trigger Gateway`=update từ `corpus/gateway/`, pin `GW-02 Auth Lookup`=trạng thái user mong muốn, pin `GW-04 Check Pending Upload`=0/1 dòng, pin `Check admin` (chỉ GW-18), và TOÀN BỘ node Telegram/Postgres/executeWorkflow còn lại bằng dummy `{ok:true}`/`{success:true}` (danh sách đã đối chiếu 100% với `get_workflow_details` live của v1 `xmEKeIUnzxm2F7dF`@`180005b7-a44a-4c95-ace6-24529ae46566` và v2 `hn0YZ85sXtfGACJ4`@`dbc644d4-7c8a-44e5-90dd-ec18b9aab157` — không thiếu node nào có tác động ngoài). v1 pin thêm `Audit Log (Supabase)`, `Tạo pending user (Supabase)`, `Ensure Pending Uploads Table` (không tồn tại ở v2). Không gửi Telegram/ghi DB thật nào. Không tạo workflow TEMP nào cho WP3 (chỉ dùng PIN trên chính v1/v2, đúng RULES #3 mục 5).

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| GW-01 | WP3 | v1 | DIFF | `/task abc`, user active [telebot_main] | `route=telebot_main`; chạy → Sub: Telebot ClickUp Reader | `"route":"telebot_main"`; runData có `"→ Sub: Telebot ClickUp Reader"` | exec 9511 | ✅ PASS |
| GW-01 | WP3 | v2 | DIFF | `/task abc`, user active [telebot_main] | `route=telebot_main`; chạy → Sub: Telebot ClickUp Reader | `"route":"telebot_main"`; runData có `"→ Sub: Telebot ClickUp Reader"` | exec 9514 | ✅ PASS |
| GW-02 | WP3 | v1 | DIFF | `/tomtat`+ảnh (synthetic), user active [image_bot] | `route=image_bot`; chạy → Sub: Image Bot | `"route":"image_bot"`; runData có `"→ Sub: Image Bot"` | exec 9519 | ✅ PASS |
| GW-02 | WP3 | v2 | DIFF | `/tomtat`+ảnh (synthetic), user active [image_bot] | `route=image_bot`; chạy → Sub: Image Bot | `"route":"image_bot"`; runData có `"→ Sub: Image Bot"` | exec 9520 | ✅ PASS |
| GW-03 | WP3 | v1 | DIFF | `/xoanen`+ảnh, user active [image_bot] | `route=image_bot` | `"route":"image_bot"` | exec 9521 | ✅ PASS |
| GW-03 | WP3 | v2 | DIFF | `/xoanen`+ảnh, user active [image_bot] | `route=image_bot` | `"route":"image_bot"` | exec 9522 | ✅ PASS |
| GW-04 | WP3 | v1 | DIFF | `/start mokhoa_sel_27300248`, user active [lock_bot] | `route=lock_bot` (không phải telebot_main) | `"route":"lock_bot"`; Route bot? output index 6 → `"→ Sub: Lock Bot"` | exec 9525 | ✅ PASS |
| GW-04 | WP3 | v2 | DIFF | `/start mokhoa_sel_27300248`, user active [lock_bot] | `route=lock_bot` | `"route":"lock_bot"`; output index 6 → `"→ Sub: Lock Bot"` | exec 9526 | ✅ PASS |
| GW-05 | WP3 | v1 | DIFF | `/mokhoa` trong chat `-5535257695`, user active bots=[] | `route=lock_no_permission`; chạy cả "Không có quyền bot này" và "Báo Admin Cấp Quyền Lock" | `"route":"lock_no_permission"`; runData có cả 2 node trên (output index 7) | exec 9528 | ✅ PASS |
| GW-05 | WP3 | v2 | DIFF | `/mokhoa` trong chat `-5535257695`, user active bots=[] | như trên | `"route":"lock_no_permission"`; cả 2 node có trong runData | exec 9529 | ✅ PASS |
| GW-06 | WP3 | v1 | DIFF | `/mokhoa` chat khác (private), user active bots=[] | `route=no_permission` | `"route":"no_permission"`; output index 3 → "Không có quyền bot này" | exec 9533 | ✅ PASS |
| GW-06 | WP3 | v2 | DIFF | `/mokhoa` chat khác (private), user active bots=[] | `route=no_permission` | `"route":"no_permission"`; output index 3 → "Không có quyền bot này" | exec 9535 | ✅ PASS |
| GW-20 | WP3 | v1 | DIFF (trích từ exec GW-01) | bất kỳ | `COMMAND_MAP` object, `AVAILABLE_BOTS` array | node `⚙️ Config` (Code) JSON output: `"AVAILABLE_BOTS":["telebot_main","help_bot","image_bot","lock_bot"]`, `"COMMAND_MAP":{"task":"telebot_main",...}` (JSON thực, không phải string) | exec 9511 | ✅ PASS |
| GW-20 | WP3 | v2 | DIFF (trích từ exec GW-01) | bất kỳ | `COMMAND_MAP` object, `AVAILABLE_BOTS` array | node `⚙️ Config` (Set) JSON output: `"AVAILABLE_BOTS":["telebot_main","help_bot","image_bot","lock_bot"]`, `"COMMAND_MAP":{"task":"telebot_main",...}` — giống hệt v1 | exec 9514 | ✅ PASS |
| GW-S1 | WP3 | v2 vs v1 | STATIC (script python tự viết, `gws1_diff.py` trong scratchpad, verify độc lập với AUDIT_REPORT WP3 audit #1) | JSON live v1 `180005b7…` (48 node) vs v2 `dbc644d4…` (44 node) | Ngoài C1–C4, node/params/credentials/connections giống hệt | `only in v1: ["Audit Log (Supabase)","Ensure Pending Uploads Table","GW-04b Merge Pending","Tạo pending user (Supabase)"]`; `only in v2: []`; common-node diffs chỉ tại `GW-03 Router` (jsCode, đúng C4) và `⚙️ Config` (code→set, đúng C3); connections chỉ-v1 6 cạnh (4 node bị xoá), chỉ-v2 2 cạnh (`Trạng thái user?[3]→GW-04`, `GW-04→GW-03 Router`, đúng C2/C4). Khác biệt phụ không thuộc C1–C4 (không chặn): `disabled:false`(v1)/`null`(v2) ở 2 node group-log (tương đương, không đổi hành vi); `webhookId` khác ở 12 node Telegram (bình thường khi clone lại, v2 chưa active nên không xung đột); settings v2 thiếu `timeSavedMode`/`binaryMode` (Gateway không có node binary → không ảnh hưởng, đã ghi risk note). | script `gws1_diff.py` (scratchpad) | ✅ PASS |
| GW-04 | WP3 | v1 | DIFF | `/start mokhoa_sel_27300248` (private, thật exec 9189), active bots=[lock_bot] | `route=lock_bot` (không phải telebot_main dù command=start) | `"route":"lock_bot"`, `"bot_key":"lock_bot"`; `→ Sub: Lock Bot` chạy | exec 9523 | ✅ PASS |
| GW-04 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"lock_bot"`; `→ Sub: Lock Bot` chạy | exec 9524 | ✅ PASS |
| GW-05 | WP3 | v1 | DIFF | `/mokhoa` chat `-5535257695` (thật exec 9181), active bots=[] (chưa có lock_bot) | `route=lock_no_permission`; chạy cả "Không có quyền bot này" + "Báo Admin Cấp Quyền Lock" | `"route":"lock_no_permission"`; cả 2 node có trong runData (message_id 90010, 90011) | exec 9530 | ✅ PASS |
| GW-05 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"lock_no_permission"`; cả 2 node có trong runData | exec 9531 | ✅ PASS |
| GW-06 | WP3 | v1 | DIFF | `/mokhoa` chat khác thlinh (thật exec 9179), active bots=[] | `route=no_permission` | `"route":"no_permission"`; chỉ "Không có quyền bot này" chạy (không có "Báo Admin Cấp Quyền Lock" trong runData) | exec 9532 | ✅ PASS |
| GW-06 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"no_permission"`; chỉ "Không có quyền bot này" chạy | exec 9534 | ✅ PASS |
| GW-07 | WP3 | v1 | DIFF | callback `odhelp_123` (synthetic, derived exec 3072), active bots=[telebot_main] | `route=telebot_main` (startsWith, không phải ===) | `"route":"telebot_main"`; lastNodeExecuted `→ Sub: Telebot ClickUp Reader` | exec 9536 | ✅ PASS |
| GW-07 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"` | exec 9537 | ✅ PASS |
| GW-08 | WP3 | v1 | DIFF | callback `odfwd_123` (synthetic, derived exec 3072), active bots=[telebot_main] | `route=telebot_main` | `"route":"telebot_main"` | exec 9538 | ✅ PASS |
| GW-08 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"` | exec 9539 | ✅ PASS |
| GW-09 | WP3 | v1 | DIFF | callback `imgai_5` (synthetic, derived exec 3072), active bots=[image_bot] | `route=image_bot` | `"route":"image_bot"`; lastNodeExecuted `→ Sub: Image Bot` | exec 9543 | ✅ PASS |
| GW-09 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"` | exec 9544 | ✅ PASS |
| GW-10 | WP3 | v1 | DIFF | callback `lockap:1` từ admin `975005174` (synthetic, derived exec 3072), active bots=[lock_bot,...] | `route=lock_bot` | `"route":"lock_bot"`; lastNodeExecuted `→ Sub: Lock Bot` | exec 9545 | ✅ PASS |
| GW-10 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"lock_bot"` | exec 9546 | ✅ PASS |
| GW-11 | WP3 | v1 | DIFF | callback `xyz_1` không khớp prefix nào (synthetic, derived exec 3072), active bots=[help_bot] | `bot_key=help_bot` (DEFAULT_BOT) | `"bot_key":"help_bot","route":"help_bot"`; lastNodeExecuted `→ Sub: Help Bot` (node disabled, không gọi thật) | exec 9550 | ✅ PASS |
| GW-11 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"bot_key":"help_bot","route":"help_bot"` | exec 9551 | ✅ PASS |
| GW-12 | WP3 | v1 | DIFF | `/task ...` (thật exec 6603, giống GW-01), `GW-04 Check Pending Upload` pin 0 dòng | Router vẫn chạy, `pendingUpload=null` | `"route":"telebot_main","pendingUpload":null` | exec 9559 | ✅ PASS |
| GW-12 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main","pendingUpload":null` | exec 9560 | ✅ PASS |
| GW-13 | WP3 | v1 | DIFF | tin text thường trong nhóm supergroup (thật exec 9199, không có lệnh), `GW-04 Check Pending Upload` pin 1 dòng có `task_prefix` | (PLAN) `route=telebot_main`, `pendingUpload.task_prefix` có giá trị | THỰC TẾ: `Cần Auth/Routing?` ra output 1 (false) vì `kind='message'`, `command=null`, `chat.type='supergroup'≠'private'` → Router/GW-02/GW-04 KHÔNG chạy; chỉ `Là Tin Nhắn Nhóm?`→`Ghi Log Tin Nhắn Nhóm`+`Detect Mention Tokens`→`Has Mention Tokens?`(false, `mentionTokens:[]`) chạy. `lastNodeExecuted:"Cần Auth/Routing?"` | exec 9561 | ⚠️ PASS (parity v1==v2) — LỆCH so với PLAN: input GW-13 (tin nhóm không lệnh) không tới được Router trong kiến trúc hiện tại ở CẢ v1 lẫn v2 — hành vi có sẵn từ v1, không phải regression của v2 |
| GW-13 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1: `Cần Auth/Routing?` ra output 1 (false); Router không chạy; `lastNodeExecuted:"Cần Auth/Routing?"` | exec 9562 | ⚠️ PASS (parity v1==v2), cùng ghi chú lệch PLAN như trên |
| GW-07 | WP3 | v1 | DIFF | callback `odhelp_123` (synthetic) | `route=telebot_main` (startsWith, không phải ===) | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9541 | ✅ PASS |
| GW-07 | WP3 | v2 | DIFF | callback `odhelp_123` (synthetic) | `route=telebot_main` | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9542 | ✅ PASS |
| GW-08 | WP3 | v1 | DIFF | callback `odfwd_123` (synthetic) | `route=telebot_main` | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9547 | ✅ PASS |
| GW-08 | WP3 | v2 | DIFF | callback `odfwd_123` (synthetic) | `route=telebot_main` | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9549 | ✅ PASS |
| GW-09 | WP3 | v1 | DIFF | callback `imgai_5` (synthetic) | `route=image_bot` | `"route":"image_bot"`; Route bot? output idx5 → `"→ Sub: Image Bot"` | exec 9553 | ✅ PASS |
| GW-09 | WP3 | v2 | DIFF | callback `imgai_5` (synthetic) | `route=image_bot` | `"route":"image_bot"`; output idx5 → `"→ Sub: Image Bot"` | exec 9554 | ✅ PASS |
| GW-10 | WP3 | v1 | DIFF | callback `lockap:1` (synthetic), admin | `route=lock_bot` | `"route":"lock_bot"`; output idx6 → `"→ Sub: Lock Bot"` | exec 9555 | ✅ PASS |
| GW-10 | WP3 | v2 | DIFF | callback `lockap:1` (synthetic), admin | `route=lock_bot` | `"route":"lock_bot"`; output idx6 → `"→ Sub: Lock Bot"` | exec 9556 | ✅ PASS |
| GW-11 | WP3 | v1 | DIFF | callback `xyz_1` (synthetic), user active [help_bot] | `bot_key=help_bot` (DEFAULT_BOT) — giữ nguyên hành vi v1 | `"bot_key":"help_bot","route":"help_bot"`; Route bot? output idx1 → `"→ Sub: Help Bot"` (node `disabled:true` ở cả 2 bản, pass-through, không gọi thật) | exec 9557 | ✅ PASS |
| GW-11 | WP3 | v2 | DIFF | callback `xyz_1` (synthetic), user active [help_bot] | `bot_key=help_bot` | `"bot_key":"help_bot","route":"help_bot"`; output idx1 → `"→ Sub: Help Bot"` (disabled, pass-through, giống v1) | exec 9558 | ✅ PASS |
| GW-14 | WP3 | v1 | DIFF | `/help` private (thật exec 9187), `GW-02 Auth Lookup` pin 0 dòng (auth=new) | Chạy `Tạo pending user` → `Báo user chờ duyệt` + `Báo admin duyệt user`; v2 KHÔNG còn `Tạo pending user (Supabase)` | `auth.state:"new"`; `Tạo pending user` VÀ `Tạo pending user (Supabase)` đều chạy (v1 có cả 2, đúng C1); `Báo user chờ duyệt` (msg 90001) + `Báo admin duyệt user` (msg 90009) chạy | exec 9566 | ✅ PASS |
| GW-14 | WP3 | v2 | DIFF | (như trên) | (như trên) | `auth.state:"new"`; CHỈ `Tạo pending user` chạy (không có key `Tạo pending user (Supabase)` — node không tồn tại, đúng khác biệt cho phép C1); `Báo user chờ duyệt` + `Báo admin duyệt user` chạy | exec 9567 | ✅ PASS |
| GW-15 | WP3 | v1 | DIFF | `/help` private (thật exec 9177), `GW-02 Auth Lookup` pin `status:pending` | `Nhắc đang chờ duyệt` chạy | `auth.state:"pending"`; `Nhắc đang chờ duyệt` chạy (output index 1, msg 90002) | exec 9569 | ✅ PASS |
| GW-15 | WP3 | v2 | DIFF | (như trên) | (như trên) | `auth.state:"pending"`; `Nhắc đang chờ duyệt` chạy (output index 1) | exec 9571 | ✅ PASS |
| GW-12 | WP3 | v1 | DIFF | `/task nguyễn thị thảo vân`, GW-04 trả 0 dòng | Router VẪN chạy, `pendingUpload=null` | `"pendingUpload":null,"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9565 | ✅ PASS |
| GW-12 | WP3 | v2 | DIFF | `/task nguyễn thị thảo vân`, GW-04 trả 0 dòng | Router VẪN chạy, `pendingUpload=null` | `"pendingUpload":null,"route":"telebot_main"` | exec 9570 | ✅ PASS |
| GW-13 | WP3 | v1 | DIFF | corpus thật (exec nguồn 9199): tin nhóm supergroup không lệnh, GW-04 trả 1 dòng có task_prefix | `route=telebot_main`; `pendingUpload.task_prefix` có giá trị | **Không tới GW-03 Router**: input thật là tin nhóm (`chat.type=supergroup`, không lệnh) → `Cần Auth/Routing?` ra `false` (output rỗng) → dừng ở đây, `lastNodeExecuted:"Cần Auth/Routing?"`. Parity v1↔v2 giữ nguyên (giống hệt nhau) nhưng KHÔNG chứng minh được nhánh pendingUpload override của spec — corpus không đúng kịch bản (phải là tin nhắn PRIVATE mới qua được cổng auth/routing) | exec 9572 | ⚠️ PASS (parity) nhưng corpus sai kịch bản — xem GW-13b |
| GW-13 | WP3 | v2 | DIFF | như trên | như trên | giống hệt v1: dừng ở `Cần Auth/Routing?`, `lastNodeExecuted:"Cần Auth/Routing?"` | exec 9575 | ⚠️ PASS (parity) nhưng corpus sai kịch bản — xem GW-13b |
| GW-13b | WP3 | v1 | DIFF (input tự tạo, thay corpus GW-13 vì corpus là tin nhóm không qua được cổng auth) | tin thường `bao_cao_thang_9.docx`, chat PRIVATE, GW-04 trả 1 dòng task_prefix=TESTPFX (synthetic) | `route=telebot_main`; `pendingUpload.task_prefix` có giá trị | `"route":"telebot_main","pendingUpload":{"task_prefix":"TESTPFX",...}`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 9576 | ✅ PASS |
| GW-13b | WP3 | v2 | DIFF | như trên | như trên | `"route":"telebot_main","pendingUpload":{"task_prefix":"TESTPFX",...}` — giống hệt v1 | exec 9578 | ✅ PASS |
| GW-16 | WP3 | v1 | DIFF | tin nhóm không lệnh có `@@abc` (synthetic, derived exec 8932) | Chạy `Ghi Log Tin Nhắn Nhóm` + `Trigger Mention Resolver (Gateway)`; KHÔNG chạy auth/router | Cả 2 node có trong runData; `lastNodeExecuted:"Cần Auth/Routing?"` (không tới Router) | exec 9577 | ✅ PASS |
| GW-16 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1 | exec 9579 | ✅ PASS |
| GW-17 | WP3 | v1 | DIFF | caption `/nentrang` + ảnh (thật exec 7249, lệnh lạ) | `route=unknown` → `Hướng dẫn lệnh` | `"route":"unknown","bot_key":null`; `Hướng dẫn lệnh` chạy (output index 4, msg 90004) | exec 9580 | ✅ PASS |
| GW-17 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"unknown"`; `Hướng dẫn lệnh` chạy | exec 9581 | ✅ PASS |
| GW-18 | WP3 | v1 | DIFF | callback `ap:1:ALL` từ user thường thlinh (synthetic, derived exec 3072), `Check admin` pin 0 dòng | `Bỏ qua (không phải admin)` | `Là admin?` output1(false)=1 item rỗng (role undefined); `Bỏ qua (không phải admin)` chạy (msg 90008) | exec 9582 | ✅ PASS |
| GW-18 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1 | exec 9583 | ✅ PASS |
| GW-14 | WP3 | v1 | DIFF | `/help`, user chưa có trong DB (GW-02 Auth Lookup=0 dòng) | chạy `Tạo pending user` → `Báo user chờ duyệt` + `Báo admin duyệt user`; v2 KHÔNG còn `Tạo pending user (Supabase)` | `"auth":{"state":"new",...}`; runData có `Tạo pending user`, `Báo user chờ duyệt`, `Báo admin duyệt user`, VÀ `Tạo pending user (Supabase)` (v1 có node này) | exec 9584 | ✅ PASS |
| GW-14 | WP3 | v2 | DIFF | như trên | như trên | `"auth":{"state":"new",...}`; runData có `Tạo pending user`, `Báo user chờ duyệt`, `Báo admin duyệt user`; KHÔNG có `Tạo pending user (Supabase)` (node không tồn tại ở v2 — đúng khác biệt cho phép) | exec 9585 | ✅ PASS |
| GW-16 | WP3 | v1 | DIFF | tin nhóm `@@abc test mention` (synthetic, dựa update thật 51638) | Chạy `Ghi Log Tin Nhắn Nhóm` + `Trigger Mention Resolver (Gateway)`; KHÔNG chạy auth/router | runData có cả 2 node trên; `Cần Auth/Routing?` output0=[] (false) → auth/router KHÔNG chạy; `lastNodeExecuted:"Cần Auth/Routing?"` | exec 9601 | ✅ PASS |
| GW-16 | WP3 | v2 | DIFF | như trên | như trên | giống hệt v1 | exec 9602 | ✅ PASS |
| GW-17 | WP3 | v1 | DIFF | `/nentrang`+ảnh (lệnh lạ, không có trong COMMAND_MAP) | `route=unknown` → `Hướng dẫn lệnh` | `"bot_key":null,"route":"unknown"`; `lastNodeExecuted:"Hướng dẫn lệnh"` | exec 9606 | ✅ PASS |
| GW-17 | WP3 | v2 | DIFF | như trên | như trên | `"bot_key":null,"route":"unknown"`; `lastNodeExecuted:"Hướng dẫn lệnh"` | exec 9613 | ✅ PASS |
| GW-P1 | WP3 | v1 | PIN (đo thời gian) | 9 lần (3x mỗi GW-01/GW-02/GW-07 pin data) — GIẢM từ 20 xuống 9/phiên bản để tiết kiệm chi phí, ghi rõ số lần | p50 thời gian thực thi | durations (ms): 102,93,110,97,104,117,101,89,85 → sorted 85,89,93,97,101,102,104,110,117 → **p50 = 101ms**. GIỚI HẠN: PIN chỉ đo phần logic (Postgres/Telegram/executeWorkflow đều pinned, không tính latency mạng thật) | exec 9591-9600 (9 exec) | ✅ PASS (ghi nhận số liệu) |
| GW-P1 | WP3 | v2 | PIN (đo thời gian) | (như trên) | p50 thời gian thực thi | durations (ms): 93,81,81,80,110,76,102,90,78 → sorted 76,78,80,81,81,90,93,102,110 → **p50 = 81ms**. Cùng giới hạn PIN chỉ đo logic | exec 9603-9612 (9 exec) | ✅ PASS (v2 p50 81ms ≤ v1 p50 101ms — nhanh hơn, phù hợp mục tiêu F9 giảm độ trễ) |
| GW-18 | WP3 | v1 | DIFF | callback `ap:1:ALL` (synthetic) từ user thường, `Check admin`=0 dòng | `Bỏ qua (không phải admin)` | `lastNodeExecuted:"Bỏ qua (không phải admin)"`; `Là admin?` ra output1 (false, role rỗng) | exec 9614 | ✅ PASS |
| GW-18 | WP3 | v2 | DIFF | như trên | như trên | `lastNodeExecuted:"Bỏ qua (không phải admin)"` — giống hệt v1 | exec 9615 | ✅ PASS |
| GW-19 | WP3 | v1 | DIFF (trích từ exec GW-01) | bất kỳ (`/task abc`) | 2 node audit chạy | runData có cả `Audit Log (Docker)` và `Audit Log (Supabase)` (2 node, cùng ghi Postgres account — F5 trùng lặp) | exec 9511 | ✅ PASS |
| GW-19 | WP3 | v2 | DIFF (trích từ exec GW-01) | bất kỳ | đúng 1 node `Audit Log (Docker)` chạy | runData chỉ có `Audit Log (Docker)`; không có node `Audit Log (Supabase)` (đã xoá — C1) | exec 9514 | ✅ PASS |

Tổng WP3 tạm thời (GW-01..GW-19 + GW-20): 42/42 dòng PASS (bao gồm GW-13/GW-13b bổ sung). Tiếp tục GW-P1 (hiệu năng) và xác nhận versionId cuối bài.
| GW-S1 | WP3 | v1 vs v2 | STATIC (script Python tự viết, độc lập với AUDIT_REPORT — tham chiếu WP3 audit #1) | `get_workflow_details` full JSON v1 `xmEKeIUnzxm2F7dF@180005b7-…` (48 node) và v2 `hn0YZ85sXtfGACJ4@dbc644d4-…` (44 node) | Ngoài C1–C4, JSON v2 == v1 (node/params/credentials/connections) | Script (`gw_s1_diff.py`) kết quả: **only-v1 (4 node, đúng C1/C2/C4)**: `Audit Log (Supabase)`, `Tạo pending user (Supabase)`, `Ensure Pending Uploads Table`, `GW-04b Merge Pending`; **only-v2: 0 node**. Common-node metadata diff ngoài `⚙️ Config` (C3, Code→Set, allowed): 2 diff `disabled:false` (v1, tường minh) vs field vắng mặt (v2) trên `Ghi Log Tin Nhắn Nhóm` và `Là Tin Nhắn Nhóm?` — tương đương chức năng (JSON `disabled` mặc định `false` khi vắng mặt), khớp phát hiện AUDIT_REPORT audit #1 "disabled:false = tương đương". Connection diff chỉ ở 3 source-node do 4 node bị xoá tạo ra (`GW-01 Envelope`, `GW-04 Check Pending Upload`, `Trạng thái user?`) — đúng re-wire C1/C2/C4, không có cạnh treo. Credentials mọi node Postgres/Telegram chung đều khớp ID (`GwUFREmcXzXXj5mZ`, `hO4yfw7ailV7jHAv`, `BHVAx8GV38yQEn1I`, `zSZ6vVapow5LNpFT`). | script `gw_s1_diff.py` (scratchpad) | ✅ PASS |

## Tóm tắt WP3

**Kết quả theo trạng thái:**
- ✅ PASS: 21 test-case × 2 phiên bản (v1+v2) = 42 dòng cho GW-01..GW-11, GW-14..GW-20 (GW-01,02,03,04,05,06,07,08,09,10,11,12,14,15,16,17,18,19,20 = 19 test-case × 2 = 38 dòng), cộng GW-13 (2 dòng, PASS parity nhưng có ghi chú lệch PLAN), cộng GW-P1 (2 dòng, đo số liệu), cộng GW-S1 (1 dòng STATIC v1-vs-v2). Tổng: 19×2 + 2 (GW-13) + 2 (GW-P1) + 1 (GW-S1) = **43 dòng**, tất cả ✅ PASS.
- ❌ FAIL: 0.
- ⏳ PENDING: 0 (không có mục MANUAL trong bộ test WP3 §7.3).

**Ghi chú quan trọng (không phải FAIL, nhưng cần architect biết):**
- **GW-13**: input "tin nhóm không lệnh" (đúng theo corpus, lấy từ exec thật 9199) KHÔNG chạm tới `GW-03 Router` ở CẢ v1 lẫn v2 — bị chặn tại `Cần Auth/Routing?` (IF: `kind==='callback' || command!==null || chat.type==='private'`, cả 3 đều false với input này) trước khi tới `GW-02 Auth Lookup`/`GW-04`. Đây là hành vi SẴN CÓ của v1 (không phải regression của v2 — 2 bên giống hệt nhau), nhưng KHÁC với "Kết quả mong muốn" ghi trong PLAN §7.3 (`route=telebot_main`). Đề nghị architect xác nhận lại: có phải PLAN mô tả nhầm ngữ cảnh (lẽ ra phải là tin PRIVATE có pending upload, không phải tin NHÓM) hay pending-upload thật sự không hoạt động trong group hiện tại.
- **GW-P1**: đo 9 lần/phiên bản (KHÔNG phải 20) để tiết kiệm — p50 v1 = 101ms, p50 v2 = 81ms (PIN, chỉ đo logic, không có latency mạng thật vì mọi Postgres/Telegram/executeWorkflow đều pinned).

**TEMP workflow:** không tạo TEMP workflow nào trong lượt test này (toàn bộ dùng `test_workflow` chạy trực tiếp trên v1/v2 có sẵn, không cần harness riêng). TEMP có sẵn từ trước (`TEMP - List Sheet Tabs (xoá sau khi dùng)`, tạo 21/09) không đụng tới — không phải tạo hôm nay. Không thấy TEMP nào do tester WP3 lượt trước để lại cần archive.

**Xác nhận không đổi workflow (bắt buộc cuối việc):**
- v1 `xmEKeIUnzxm2F7dF`: `versionId == activeVersionId == 180005b7-a44a-4c95-ace6-24529ae46566` ✓ (không đổi so với PLAN §3)
- v2 `hn0YZ85sXtfGACJ4`: `versionId == dbc644d4-7c8a-44e5-90dd-ec18b9aab157` ✓ (không đổi so với AUDIT_REPORT audit #1, `active:false` — vẫn ở staging, chưa publish)

Không commit git. Không gửi Telegram thật (mọi node Telegram/Postgres/Supabase/executeWorkflow đều pinned qua `test_workflow`, xác nhận qua `pinData` trong từng execution).
| GW-P1 | WP3 | v1 | DIFF (PIN, đo hiệu năng) | `/task abc` (input GW-01) × 5 lần | Ghi p50 thời gian chạy | 5 exec (`stoppedAt-startedAt` ms): 9617=112, 9618=103, 9619=89, 9621=96, 9623=115 → **p50 = 103ms** | exec 9617,9618,9619,9621,9623 | ✅ PASS (5/20 lần — giới hạn thời gian phiên, ghi rõ số lần; PIN chỉ đo phần logic Gateway, không tính thời gian mạng tới Telegram/Postgres/sub-workflow thật vì các node đó bị pin) |
| GW-P1 | WP3 | v2 | DIFF (PIN, đo hiệu năng) | `/task abc` (input GW-01) × 5 lần | Ghi p50 thời gian chạy | 5 exec (ms): 9624=76, 9625=82, 9626=78, 9627=83, 9628=98 → **p50 = 82ms** | exec 9624,9625,9626,9627,9628 | ✅ PASS (5/20 lần — cùng giới hạn; v2 nhanh hơn v1 (~20%) trên input này, hợp lý vì bớt `Audit Log (Supabase)` song song và gộp `GW-04b Merge Pending` vào Router — nhưng mẫu nhỏ (5 lần, chỉ dùng input GW-01, chưa xoay vòng đủ GW-01/02/07 như spec) nên KHÔNG dùng làm số liệu chính thức cho quyết định cutover, chỉ mang tính tham khảo) |

**Giới hạn GW-P1 (bắt buộc ghi rõ):** (1) PIN data thay toàn bộ node Telegram/Postgres/executeWorkflow bằng dummy tức thời — thời gian đo chỉ phản ánh phần LOGIC Gateway (Code/IF/Switch/Set), KHÔNG bao gồm độ trễ mạng thật tới Telegram API, Postgres, hay sub-workflow thật khi chạy production. (2) Do giới hạn thời gian phiên, chỉ chạy 5/20 lần mỗi phiên bản (tối thiểu theo PLAN cho phép), và chỉ dùng lại input GW-01 (`/task abc`) thay vì xoay vòng đều GW-01/GW-02/GW-07 như spec yêu cầu — số liệu p50 ở trên chỉ mang tính tham khảo sơ bộ, không đủ để kết luận chính thức "p50 v2 ≤ p50 v1" cho mọi loại lệnh.

## WP3 — bổ sung (tester, cùng lượt 06:30Z) — GW-15 (thiếu ở lần append trước) + ghi chú đối chiếu chéo

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| GW-15 | WP3 | v1 | DIFF | `/help`, `GW-02 Auth Lookup` pin `status:pending` | `Nhắc đang chờ duyệt` | `"auth":{"state":"pending",...}`; `Trạng thái user?` output idx1 → `Nhắc đang chờ duyệt` chạy | exec 9586 | ✅ PASS |
| GW-15 | WP3 | v2 | DIFF | như trên | như trên | giống hệt v1 | exec 9587 | ✅ PASS |
| GW-15 | WP3 | v1 | DIFF | `/help`, `GW-02 Auth Lookup` pin `status:denied` | `Thông báo từ chối` | `"auth":{"state":"denied",...}`; `Trạng thái user?` output idx2 → `Thông báo từ chối` chạy | exec 9588 | ✅ PASS |
| GW-15 | WP3 | v2 | DIFF | như trên | như trên | giống hệt v1 | exec 9590 | ✅ PASS |

**Ghi chú đối chiếu chéo:** file này bị 2 lượt tester ghi song song (đúng quy tắc mục 5.6 — chỉ dùng `cat >>`, không Write/Edit ghi đè). Lượt của tôi (bắt đầu 06:30Z, chạy lại từ đầu độc lập theo yêu cầu, không đọc kết quả của lượt kia trước khi test) trùng khớp 100% kết luận với lượt song song: cùng route/bot_key cho toàn bộ GW-01..GW-20, cùng phát hiện GW-13 (corpus tin nhóm không chạm được Router ở cả 2 bản — không phải regression), cùng GW-S1 PASS (chỉ khác C1-C4), cùng GW-20 kiểu dữ liệu thực. Sai khác duy nhất: p50 GW-P1 đo bằng input/số lần khác nhau (tôi: 5 lần chỉ dùng GW-01; lượt kia: 9 lần xoay GW-01/02/07) nhưng cùng kết luận định tính v2 nhanh hơn v1. Không tạo TEMP workflow nào trong lượt của tôi. Xác nhận cuối: v1 `xmEKeIUnzxm2F7dF` versionId==activeVersionId==`180005b7-a44a-4c95-ace6-24529ae46566`; v2 `hn0YZ85sXtfGACJ4` versionId==`dbc644d4-7c8a-44e5-90dd-ec18b9aab157`, active=false — cả hai không đổi trong suốt quá trình test (đọc lại lúc 06:42Z).

**Tổng hợp của lượt tester này (độc lập, không tính trùng với lượt song song):** GW-01..GW-20 (kể cả GW-13b bổ sung, GW-15 pending+denied, GW-19, GW-20, GW-S1, GW-P1) = 47 dòng, tất cả ✅ PASS. 0 FAIL. 0 PENDING. 0 TEMP workflow tạo ra (0 cần archive).

## Đêm 2 — WP2 MIG-04 — 2026-09-25T19:12:15Z

Bối cảnh: migration `8XLg2q34VQq6IDx7` (node `Chạy Toàn Bộ DDL Migrations`) đã do user tự chạy tay 2 lần trước đó (exec `9795`, `9880` — MIG-02/MIG-03). Lượt này CHỈ xác nhận schema kết quả bằng SQL chỉ-đọc, không chạy lại migration.

Cách test: đọc nguyên văn node `Chạy Toàn Bộ DDL Migrations` (`get_workflow_details` workflow `8XLg2q34VQq6IDx7`) để liệt kê đủ mọi `CREATE TABLE IF NOT EXISTS` + `ADD COLUMN IF NOT EXISTS` + index `idx_error_alert_throttle_created`. Tạo workflow TEMP `TEMP - MIG-04 kiểm schema (xoá sau khi dùng)` (`0eLYv0f67eziX8R7`, folder `ZdlLC9utIKkjLvhv`, project `5cL5BKorhKAQ2ONI`): `Manual Trigger` → 1 node Postgres `executeQuery` (credential xác nhận đúng qua `get_workflow_details` sau khi `addNode`: `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}`, khớp yêu cầu, không cần sửa bằng `setNodeCredential`). Query CHỈ gồm `SELECT`/`WITH ... SELECT` trên `information_schema.tables`, `information_schema.columns`, `pg_indexes` — không `INSERT`/`UPDATE`/`DELETE`/`DDL`. Chạy bằng `test_workflow` (không pin node Postgres — `prepare_workflow_pin_data` trả về `nodesWithoutSchema` cho cả 2 node, không node nào cần pin, nên Postgres chạy thật, chỉ đọc).

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| MIG-04 | WP2 | (schema hiện tại sau exec 9795/9880) | STATIC + SQL chỉ-đọc (`information_schema.tables`/`.columns`, `pg_indexes`) qua TEMP workflow, `test_workflow` | Manual Trigger → Postgres executeQuery (credential `Postgres account` GwUFREmcXzXXj5mZ) | Bảng `gateway.error_alert_throttle` + toàn bộ bảng/cột được CREATE/ADD COLUMN trong node `Chạy Toàn Bộ DDL Migrations`, và index `idx_error_alert_throttle_created` đều tồn tại; `gateway.error_alert_throttle` có đúng 3 cột `bucket_key`/`created_at`/`suppressed_count` | 26/26 dòng SQL trả về `"found":true` (7 TABLE, 17 COLUMN, 1 INDEX, 1 THROTTLE_COLCOUNT=3) — trích runData nguyên văn bên dưới | exec `10473`, workflow TEMP `0eLYv0f67eziX8R7` | ✅ PASS |

**Trích nguyên kết quả SQL (runData node `Kiểm Schema MIG-04 (chỉ đọc)`, exec `10473`) — 26/26 `found:true`, KHÔNG có object nào thiếu:**

TABLE (7/7 có mặt):
- `clickup.pending_uploads` → found:true
- `clickup.sync_targets` → found:true
- `gateway.error_alert_throttle` → found:true
- `gateway.lock_unlock_requests` → found:true
- `gateway.mention_group_members` → found:true
- `gateway.mention_groups` → found:true
- `gateway.ttlock_auth` → found:true

COLUMN (17/17 có mặt):
- `gateway.notify_targets.zalo_chat_id` → found:true
- `clickup.pending_uploads.student_name` → found:true
- `clickup.pending_uploads.task_url` → found:true
- `clickup.pending_uploads.task_prefix` → found:true
- `clickup.upload_notify_queue.uploader_name` → found:true
- `clickup.upload_notify_queue.student_name` → found:true
- `clickup.upload_notify_queue.task_url` → found:true
- `clickup.upload_notify_queue.drive_id` → found:true
- `clickup.upload_notify_queue.item_id` → found:true
- `clickup.upload_notify_queue.fwd_chat_id` → found:true
- `clickup.upload_notify_queue.fwd_message_id` → found:true
- `clickup.upload_notify_queue.zalo_chat_id_used` → found:true
- `clickup.upload_notify_queue.deleted_at` → found:true
- `clickup.upload_notify_queue.task_prefix` → found:true
- `gateway.error_alert_throttle.bucket_key` → found:true
- `gateway.error_alert_throttle.created_at` → found:true
- `gateway.error_alert_throttle.suppressed_count` → found:true

INDEX (1/1 có mặt):
- `gateway.error_alert_throttle.idx_error_alert_throttle_created` (qua `pg_indexes`) → found:true

THROTTLE_COLCOUNT (1/1 đạt):
- `gateway.error_alert_throttle(bucket_key,created_at,suppressed_count)` — đếm đúng 3/3 cột bắt buộc → found:true

**Object thiếu:** KHÔNG có (0/26).

**TEMP workflow:** `TEMP - MIG-04 kiểm schema (xoá sau khi dùng)` (`0eLYv0f67eziX8R7`) — đã `archive_workflow` ngay sau khi đọc xong runData (xác nhận response `{"archived":true,"workflowId":"0eLYv0f67eziX8R7",...}`).

**Tóm tắt WP2 (MIG-04):** ✅ PASS: 1/1. ❌ FAIL: 0. ⏳ PENDING: 0. Không chạy lại migration, không publish/unpublish workflow nào, không ghi DB (chỉ SELECT), không gửi Telegram. Không có bước nào bị safety/permission từ chối.

## Đêm 2 — test lại toàn bộ — 2026-09-25T19:00:00Z (Architect sửa ngày: tester ghi nhầm 26/09)

Bối cảnh: chạy tự động đêm 2 (26/09/2026), không người trực. Nhiệm vụ: test lại toàn bộ (regression) các WP đang READY (WP3) + bộ REG. Đọc lại PLAN.md mục 3/5/7.1/7.2/7.3/7.7/9, TEST_REPORT.md đêm 1, AUDIT_REPORT.md, RULES.md #2/#18/#20/#21/#24 trước khi bắt đầu.

**Gate WP3 (bắt buộc trước khi test):** `get_workflow_details` xác nhận lại:
- v1 `xmEKeIUnzxm2F7dF`: `versionId == activeVersionId == "180005b7-a44a-4c95-ace6-24529ae46566"` ✓ khớp PLAN §3 và TEST_REPORT đêm 1.
- v2 `hn0YZ85sXtfGACJ4`: `versionId == "dbc644d4-7c8a-44e5-90dd-ec18b9aab157"`, `active:false` ✓ khớp đêm 1.
→ Không có bản nháp mới nào từ 25/09 tới nay. WP3 tiếp tục.

**Xác nhận thêm (không đổi so với đêm 1, dùng cho REG):**
- Bot Xử Lý Ảnh (`6I4MnJiJCiv2JOIr`): `versionId==activeVersionId=="435af575-e17f-488e-b616-20798790bbdf"` ✓
- Telebot Admin System (`eWtu7Qs85Hes0HuP`): `versionId==activeVersionId=="53d44baa-8e4b-4dd4-8f78-fbcd970fe46f"` ✓
- SQL - ClickUp Live Update (`uqTqjtHYieotPZuc`): `versionId==activeVersionId=="42cfa99b-6659-47dd-8a84-f9fa4e977739"` ✓

Không production nào đổi version kể từ đêm 1. Phương pháp: PIN qua `prepare_workflow_pin_data`+`test_workflow` (không `update_workflow`/`publish_workflow` trên v1/v2/production). Pin mọi node Telegram/Postgres/Supabase/executeWorkflow theo RULES 5.3 (danh sách đối chiếu lại 100% với `get_workflow_details` v1/v2 lúc bắt đầu — không thiếu node có tác động ngoài nào). Không gửi Telegram thật, không ghi DB thật.

### WP3 — GW-01..GW-20 (DIFF v1↔v2)

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| GW-01 | WP3 | v1 | DIFF | `/task nguyễn thị thảo vân` (corpus GW-01, thật exec 6603), auth active bots=[telebot_main] | `route=telebot_main`; chạy → Sub: Telebot ClickUp Reader | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"`; `Audit Log (Docker)` + `Audit Log (Supabase)` đều chạy | exec 10475 | ✅ PASS |
| GW-01 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"`; `⚙️ Config` (Set) COMMAND_MAP object/AVAILABLE_BOTS array giống v1 | exec 10480 | ✅ PASS |
| GW-02 | WP3 | v1 | DIFF | `/tomtat`+ảnh (corpus GW-02, synthetic derived exec 6710), auth active bots=[image_bot] | `route=image_bot`; chạy → Sub: Image Bot | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10476 | ✅ PASS |
| GW-02 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10477 | ✅ PASS |
| GW-03 | WP3 | v1 | DIFF | `/xoanen`+ảnh (corpus GW-03, thật exec 6710) | `route=image_bot` | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10478 | ✅ PASS |
| GW-03 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10479 | ✅ PASS |
| GW-04 | WP3 | v1 | DIFF | `/start mokhoa_sel_27300248` (corpus GW-04, thật exec 9189), auth active bots=[lock_bot] | `route=lock_bot` (không phải telebot_main) | `"route":"lock_bot"`; `lastNodeExecuted:"→ Sub: Lock Bot"` | exec 10484 | ✅ PASS |
| GW-04 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"lock_bot"`; `lastNodeExecuted:"→ Sub: Lock Bot"` | exec 10485 | ✅ PASS |
| GW-05 | WP3 | v1 | DIFF | `/mokhoa` trong chat `-5535257695` (corpus GW-05, thật exec 9181), auth active bots=[] | `route=lock_no_permission`; chạy cả "Không có quyền bot này" và "Báo Admin Cấp Quyền Lock" | `"route":"lock_no_permission"`; cả 2 node có trong runData (msg 90010, 90011); `lastNodeExecuted:"Báo Admin Cấp Quyền Lock"` | exec 10486 | ✅ PASS |
| GW-05 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1: cả 2 node có trong runData | exec 10487 | ✅ PASS |
| GW-06 | WP3 | v1 | DIFF | `/mokhoa` chat khác thlinh (corpus GW-06, thật exec 9179), auth active bots=[] | `route=no_permission` | `"route":"no_permission"`; `lastNodeExecuted:"Không có quyền bot này"` (không có "Báo Admin Cấp Quyền Lock") | exec 10488 | ✅ PASS |
| GW-06 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1 | exec 10489 | ✅ PASS |
| GW-07 | WP3 | v1 | DIFF | callback `odhelp_123` (corpus GW-07, synthetic derived exec 3072), auth active bots=[telebot_main] | `route=telebot_main` (startsWith, không phải ===) | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 10490 | ✅ PASS |
| GW-07 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 10491 | ✅ PASS |
| GW-08 | WP3 | v1 | DIFF | callback `odfwd_123` (corpus GW-08, synthetic derived exec 3072), auth active bots=[telebot_main] | `route=telebot_main` | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 10492 | ✅ PASS |
| GW-08 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main"`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 10493 | ✅ PASS |
| GW-09 | WP3 | v1 | DIFF | callback `imgai_5` (corpus GW-09, synthetic derived exec 3072), auth active bots=[image_bot] | `route=image_bot` | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10495 | ✅ PASS |
| GW-09 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"image_bot"`; `lastNodeExecuted:"→ Sub: Image Bot"` | exec 10496 | ✅ PASS |
| GW-10 | WP3 | v1 | DIFF | callback `lockap:1` từ admin `975005174` (corpus GW-10, synthetic derived exec 3072), auth active bots=[lock_bot,telebot_main] | `route=lock_bot` | `"route":"lock_bot"`; `lastNodeExecuted:"→ Sub: Lock Bot"` | exec 10497 | ✅ PASS |
| GW-10 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"lock_bot"`; `lastNodeExecuted:"→ Sub: Lock Bot"` | exec 10499 | ✅ PASS |
| GW-11 | WP3 | v1 | DIFF | callback `xyz_1` không khớp prefix nào (corpus GW-11, synthetic derived exec 3072), auth active bots=[help_bot] | `bot_key=help_bot` (DEFAULT_BOT) | `"bot_key":"help_bot","route":"help_bot"`; `lastNodeExecuted:"→ Sub: Help Bot"` (node disabled, pass-through, không gọi thật) | exec 10501 | ✅ PASS |
| GW-11 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"bot_key":"help_bot","route":"help_bot"`; `lastNodeExecuted:"→ Sub: Help Bot"` | exec 10502 | ✅ PASS |
| GW-18 | WP3 | v1 | DIFF | callback `ap:1:ALL` từ user thường thlinh (synthetic, derived exec 3072), `Check admin` pin 0 dòng | `Bỏ qua (không phải admin)` | `Là admin?` output1(false)=1 item rỗng (role undefined); `lastNodeExecuted:"Bỏ qua (không phải admin)"` | exec 10503 | ✅ PASS |
| GW-18 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1 | exec 10504 | ✅ PASS |
| GW-12 | WP3 | v1 | DIFF | `/task ...` (dùng lại input GW-01), `GW-04 Check Pending Upload` pin 0 dòng | Router vẫn chạy, `pendingUpload=null` | `"route":"telebot_main","pendingUpload":null` (trích từ exec GW-01 v1) | exec 10475 | ✅ PASS |
| GW-12 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"route":"telebot_main","pendingUpload":null` (trích từ exec GW-01 v2) | exec 10480 | ✅ PASS |
| GW-13 | WP3 | v1 | DIFF | tin text thường trong NHÓM, không lệnh, không @@mention (synthetic), GW-04 pin 1 dòng có task_prefix (không dùng tới) | (kỳ vọng MỚI theo xác nhận user 25/09: tin nhóm không lệnh KHÔNG tới Router, chỉ ghi log) | `Cần Auth/Routing?` ra output1 rỗng (false) vì `kind='message'`, `command=null`, `chat.type='supergroup'≠'private'`; chỉ `Ghi Log Tin Nhắn Nhóm` chạy (Router/GW-02/GW-04 KHÔNG có trong runData); `lastNodeExecuted:"Cần Auth/Routing?"` | exec 10508 | ✅ PASS (đúng kỳ vọng mới) |
| GW-13 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1: dừng ở `Cần Auth/Routing?`, chỉ `Ghi Log Tin Nhắn Nhóm` chạy | exec 10509 | ✅ PASS (đúng kỳ vọng mới) |
| GW-13b | WP3 | v1 | DIFF | tin text thường `bao_cao_thang_9.docx`, CHAT RIÊNG, GW-04 pin 1 dòng `task_prefix=TESTPFX` | `route=telebot_main`; `pendingUpload.task_prefix` có giá trị | `"route":"telebot_main"`; `pendingUpload":{"task_prefix":"TESTPFX",...}`; `lastNodeExecuted:"→ Sub: Telebot ClickUp Reader"` | exec 10506 | ✅ PASS |
| GW-13b | WP3 | v2 | DIFF | (như trên) | (như trên) | Giống hệt v1 | exec 10507 | ✅ PASS |
| GW-14 | WP3 | v1 | DIFF | `/help` private, user chưa có trong DB (`GW-02 Auth Lookup` pin 0 dòng) | Chạy `Tạo pending user` → `Báo user chờ duyệt` + `Báo admin duyệt user`; v2 KHÔNG còn `Tạo pending user (Supabase)` | `auth.state:"new"`; `Tạo pending user` VÀ `Tạo pending user (Supabase)` đều chạy (v1, đúng C1); `Báo user chờ duyệt` (msg 90001) + `Báo admin duyệt user` (msg 90009) chạy | exec 10510 | ✅ PASS |
| GW-14 | WP3 | v2 | DIFF | (như trên) | (như trên) | `auth.state:"new"`; CHỈ `Tạo pending user` chạy (không có `Tạo pending user (Supabase)` — node không tồn tại, đúng C1); `Báo user chờ duyệt` + `Báo admin duyệt user` chạy | exec 10511 | ✅ PASS |
| GW-15 | WP3 | v1 | DIFF | `/help` private, `GW-02 Auth Lookup` pin `status:pending` | `Nhắc đang chờ duyệt` chạy | `auth.state:"pending"`; `Trạng thái user?` output idx1 → `Nhắc đang chờ duyệt` chạy (msg 90002) | exec 10512 | ✅ PASS |
| GW-15 | WP3 | v2 | DIFF | (như trên) | (như trên) | Giống hệt v1 | exec 10513 | ✅ PASS |
| GW-15 | WP3 | v1 | DIFF | `/help` private, `GW-02 Auth Lookup` pin `status:denied` | `Thông báo từ chối` chạy | `auth.state:"denied"`; `Trạng thái user?` output idx2 → `Thông báo từ chối` chạy (msg 90003) | exec 10515 | ✅ PASS |
| GW-15 | WP3 | v2 | DIFF | (như trên) | (như trên) | Giống hệt v1 | exec 10516 | ✅ PASS |
| GW-16 | WP3 | v1 | DIFF | tin nhóm `@@abc test mention` (synthetic) | Chạy `Ghi Log Tin Nhắn Nhóm` + `Trigger Mention Resolver (Gateway)`; KHÔNG chạy auth/router | Cả 2 node có trong runData; `mentionTokens:["abc"]`; `lastNodeExecuted:"Cần Auth/Routing?"` (không tới Router) | exec 10518 | ✅ PASS |
| GW-16 | WP3 | v2 | DIFF | (như trên) | (như trên) | Y hệt v1 | exec 10519 | ✅ PASS |
| GW-17 | WP3 | v1 | DIFF | caption `/nentrang` + ảnh (lệnh lạ, không trong COMMAND_MAP), private | `route=unknown` → `Hướng dẫn lệnh` | `"bot_key":null,"route":"unknown"`; `lastNodeExecuted:"Hướng dẫn lệnh"` (msg 90004) | exec 10520 | ✅ PASS |
| GW-17 | WP3 | v2 | DIFF | (như trên) | (như trên) | `"bot_key":null,"route":"unknown"`; `lastNodeExecuted:"Hướng dẫn lệnh"` | exec 10521 | ✅ PASS |
| GW-19 | WP3 | v1 | DIFF (trích từ exec GW-01) | bất kỳ (`/task nguyễn thị thảo vân`) | v1: 2 node audit chạy | `Audit Log (Docker)` VÀ `Audit Log (Supabase)` đều có trong runData | exec 10475 | ✅ PASS |
| GW-19 | WP3 | v2 | DIFF (trích từ exec GW-01) | bất kỳ | v2: đúng 1 node `Audit Log (Docker)` chạy | Chỉ `Audit Log (Docker)` có trong runData exec 10480 (không có key `Audit Log (Supabase)` — node không tồn tại ở v2) | exec 10480 | ✅ PASS |
| GW-20 | WP3 | v1 | STATIC (trích từ exec GW-01) | bất kỳ | `⚙️ Config` kiểu thực tế: COMMAND_MAP object, AVAILABLE_BOTS array | `"AVAILABLE_BOTS":["telebot_main","help_bot","image_bot","lock_bot"]` (array), `"COMMAND_MAP":{"task":"telebot_main",...}` (object), `"ADMIN_CHAT_ID":"975005174"`, `"DEFAULT_BOT":"help_bot"` | exec 10475 | ✅ PASS |
| GW-20 | WP3 | v2 | STATIC (trích từ exec GW-01) | bất kỳ | Set node cho ra cùng kiểu thực tế | Giá trị deep-equal v1 (xác nhận exec 10480, node `⚙️ Config` type Set) | exec 10480 | ✅ PASS |
| GW-P1 | WP3 | v1 | DIFF (PIN, đo hiệu năng) | `/task nguyễn thị thảo vân` (input GW-01) × 5 lần | Ghi p50 thời gian chạy | 5 exec (`stoppedAt-startedAt` ms): 10523=87, 10524=110, 10525=106, 10526=109, 10527=107 → sorted 87,106,107,109,110 → **p50 = 107ms** | exec 10523,10524,10525,10526,10527 | ✅ PASS (5/20 lần theo PLAN "5 lần/bản là đủ"; PIN chỉ đo phần logic Gateway, không tính latency mạng thật tới Telegram/Postgres/sub-workflow vì các node đó bị pin) |
| GW-P1 | WP3 | v2 | DIFF (PIN, đo hiệu năng) | (như trên) × 5 lần | Ghi p50 thời gian chạy | 5 exec (ms): 10528=72, 10529=72, 10530=124, 10531=74, 10532=76 → sorted 72,72,74,76,124 → **p50 = 74ms** | exec 10528,10529,10530,10531,10532 | ✅ PASS (v2 p50 74ms < v1 p50 107ms, cùng giới hạn PIN như trên; nhất quán với đêm 1 v2 nhanh hơn v1) |
| GW-S1 | WP3 | v1 vs v2 | STATIC | `get_workflow_details` full JSON v1 `xmEKeIUnzxm2F7dF@180005b7-…` (48 node) và v2 `hn0YZ85sXtfGACJ4@dbc644d4-…` (44 node), đọc lại toàn bộ trực tiếp đêm 2 (không dựa vào cache đêm 1) | Ngoài C1–C4, JSON v2 == v1 (node/params/credentials/connections) | Node chỉ có ở v1 (4, đúng C1/C2/C4): `Audit Log (Supabase)`, `Tạo pending user (Supabase)`, `Ensure Pending Uploads Table`, `GW-04b Merge Pending`. Node chỉ có ở v2: 0. `⚙️ Config`: v1 `type:"n8n-nodes-base.code"`, v2 `type:"n8n-nodes-base.set"` (đúng C3, cùng 4 field `ADMIN_CHAT_ID/AVAILABLE_BOTS/COMMAND_MAP/DEFAULT_BOT`, cùng giá trị, `retryOnFail/maxTries:5/waitBetweenTries:5000` giữ nguyên). `GW-03 Router` v2 có thêm đoạn `const base = $('GW-02b Merge Auth')...; const rows = $input.all()...; const env = {...base, pendingUpload:...}` thay cho `const env = $input.first().json;` của v1 (đúng C4), phần còn lại của code giống hệt từng ký tự (đối chiếu chuỗi). Connections: v1 có `Trạng thái user?[3]→Ensure Pending Uploads Table→GW-04 Check Pending Upload→GW-04b Merge Pending→GW-03 Router`; v2 có `Trạng thái user?[3]→GW-04 Check Pending Upload→GW-03 Router` (đúng C2+C4 re-wire, không cạnh treo). Credentials mọi node Postgres (`GwUFREmcXzXXj5mZ`)/Telegram (`BHVAx8GV38yQEn1I`, `zSZ6vVapow5LNpFT`) khớp ID giữa v1 và v2 ở mọi node chung. Settings workflow: `errorWorkflow:"34ccboHpyoY2r691"`, `callerPolicy:"workflowsFromSameOwner"`, `executionOrder:"v1"` giống nhau ở cả 2 bản. | get_workflow_details (không có execution riêng, đọc trực tiếp JSON) | ✅ PASS |

### REG — bộ hồi quy trên production (chỉ đọc)

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| REG-LU-01 | — | prod | STATIC | `get_workflow_details(uqTqjtHYieotPZuc)`, node `⚙️ Config (Admin Chat ID)` | `retryOnFail:true, maxTries:5, waitBetweenTries:5000` | `"retryOnFail":true,"maxTries":5,"waitBetweenTries":5000"` (đọc trực tiếp JSON node đêm 2, `versionId` không đổi so với đêm 1) | — | ✅ PASS |
| REG-OCR-02 | — | prod | STATIC | `get_workflow_details(6I4MnJiJCiv2JOIr)`, node `Gửi Bản Tóm Tắt` | Tham chiếu `$('Tóm Tắt Bằng AI').item.json.text`, không phải `$json` trần | `"text":"={{ $('Tóm Tắt Bằng AI').item.json.text }}"` (đọc trực tiếp JSON node đêm 2) | — | ✅ PASS |
| REG-OCR-03 | — | prod | STATIC + runData exec thật gần nhất (9908, 25/09 10:54) | exec 9908 | `Send Processing Ack.startTime` < `Call Qwen OCR.startTime`; `Delete Processing Ack (OK)` chạy trước `Gửi Bản Tóm Tắt` | `1790333654469 < 1790333655312` (Send Ack < Call OCR); `Delete Processing Ack (OK)` startTime `1790333660615` < `Gửi Bản Tóm Tắt` startTime `1790333661295` | exec 9908 | ✅ PASS |
| REG-OCR-05 | — | — | Runtime (exec thật) | Node LangChain `Tóm Tắt Bằng AI`, exec 9908 | 1 item in = 1 item out | `pairedItem:{"item":0}`; 1 item duy nhất trong `data.main[0]`, input `Format OCR Result` cũng 1 item | exec 9908 | ✅ PASS |
| REG-OCR-04 | — | prod (cấu trúc) | TEMP repro (không có cách chọn output-index qua PIN chuẩn — xác nhận lại đúng giới hạn đêm 1) | TEMP `ECH0aKo9CXgCD5UE`: `Manual Trigger` → HTTP GET `https://httpbin.org/status/500` (`onError:"continueErrorOutput"`, cùng cấu hình lỗi như `Call Qwen OCR` thật) → output0→`Format OCR Result (copy)`→`Tom Tat Bang AI (ghi lai)`; output1→`Delete Processing Ack (Failed) (ghi lai)`→`Reply OCR Failed (ghi lai)` | Chạy `Delete Processing Ack (Failed)` → `Reply OCR Failed`; KHÔNG chạy `Tóm Tắt Bằng AI` | Node HTTP trả lỗi thật (`"status":500,"name":"AxiosError"`) đi ra **output 1**; runData chỉ có `Delete Processing Ack (Failed) (ghi lai)` (`wouldHaveDeleted:true`) và `Reply OCR Failed (ghi lai)` (`wouldHaveReplied:true`) — KHÔNG có `Format OCR Result (copy)`/`Tom Tat Bang AI (ghi lai)` trong runData | exec `10537`, TEMP `ECH0aKo9CXgCD5UE` (đã archive, `autoAssignedCredentials:[]` — không có credential nào bị gán sai) | ✅ PASS |
| REG-OCR-01 | — | prod (logic thật) | REAL (TEMP) | `file_id` ảnh thật `AgACAgUAAyEFAASk_5TkAALKDmq2UrNmD5AAAVVlSoo4iOW690Ku7wACKBRrG7RUsVVK3TIY-oBKhAEAAwIAA3kAAz0E` (từ exec thật 9908, 25/09), credential `Elite Clickupbot` (`BHVAx8GV38yQEn1I`) copy đúng từ prod node `Tải Ảnh Về (Vision)` | `data` (base64) tồn tại, độ dài > 50.000 ký tự | Telegram getFile thật OK: `"ok":true,"result":{"file_id":"AgACAg...","file_size":50622,"file_path":"photos/file_372.jpg"}`. `Ack gia lap (TEMP)` xoá field khác (includeOtherFields:false, mô phỏng ack). `Dinh Kem Lai Anh (Sau Ack) (TEMP)` (copy nguyên logic prod, chỉ đổi tên node tham chiếu) gắn lại binary OK (`binary` có key `"data"`). `To Base64 (OCR) (TEMP)` (extractFromFile binaryToPropery, property `data`) chạy `success`, `json.data.length == 67496` (> 50.000) | exec `10538`, TEMP `80821vva7xGpyd6l` (autoAssignedCredentials lần đầu gán nhầm `@csfsintbot` — đã sửa bằng `setNodeCredential` về đúng `Elite Clickupbot` trước khi chạy, xác nhận lại qua `get_workflow_details`; đã archive) | ✅ PASS |
| REG-VPS-01 | — | prod | PIN (`test_workflow`, không đổi workflow) | `/vps` từ chat admin `975005174` (corpus `ADM-01_vps.json`); `Call VPS Info` pin = 3 container mẫu (id 12 hex) | Text có `?start=vpsc_<12 hex>` cho mỗi container | `Send VPS Stats` chạy; text chứa `...?start=vpsc_0b13df56a8c2">🔍 chi tiết</a>`, `...vpsc_211ebda7fd24...`, `...vpsc_016d6fddd3b2...` (đủ cả 3 container mẫu) | exec `10541` | ✅ PASS |
| REG-VPS-02 | — | prod | PIN | `/start vpsc_0b13df56a8c2` từ chat admin (corpus `ADM-02`); `Call Container Info` pin = container thật dạng `{id,name,image,status,running:true,...}` | Tới `Send Container Detail`; nút `vpsrestart_0b13df56a8c2` + `vpscancel` | `Build Container Detail.json.containerId == "0b13df56a8c2"`; `lastNodeExecuted:"Send Container Detail"`. Cấu hình nút (đọc tĩnh từ node, không đổi so với đêm 1): `callback_data:"={{ 'vpsrestart_' + $('Build Container Detail').first().json.containerId }}"` + nút cố định `callback_data:"vpscancel"` | exec `10543` | ✅ PASS |
| REG-VPS-03 | — | prod | PIN | `/start vpsc_ffffffffffff` (id không tồn tại); `Call Container Info` pin = `{"error":"not_found"}` | Tới `Reply Container Info Failed` | `Container Info OK?` output1 (false) = 1 item; `Reply Container Info Failed` chạy; `Build Container Detail` KHÔNG có trong runData | exec `10544` | ✅ PASS |
| REG-VPS-04 | — | prod | PIN | `/vps` từ chat `111111111` (không phải admin `975005174`); `Call VPS Info` pin `{"error":"should_not_be_called"}` (bẫy) | Tới `Reply Không Có Quyền (VPS)`, không gọi `Call VPS Info` | `Check Admin (VPS)` output1 (false, `chatId:"111111111"`≠`ADMIN_CHAT_ID:"975005174"`); `Reply Không Có Quyền (VPS)` chạy; `Call VPS Info` KHÔNG có trong runData (bẫy không bị kích hoạt) | exec `10545` | ✅ PASS |
| REG-VPS-05 | — | prod | PIN | callback `vpscancel` từ chat admin (corpus `ADM-04`) | Tới `Reply VPS Cancelled` | `Phân tích lệnh.json.route == "vps_cancel"`; `Switch` output 25 → thẳng `Reply VPS Cancelled` (không qua `Check Admin (VPS Extra)` — đúng hành vi thật quan sát lại, khớp đêm 1: route `vps_cancel` không có cổng admin) | exec `10546` | ✅ PASS |
| REG-VPS-06 | — | — | MANUAL | Restart container thật `portainer-portainer-1` / `016d6fddd3b2` | Tin xác nhận `✅ Đã khởi động lại container portainer-portainer-1` | — (không làm; cần người trực + SSH/docker thật theo PLAN, đúng luật không SSH ghi/docker trong lượt tự động) | — | ⏳ PENDING (MANUAL, đúng theo PLAN — làm khi có người trực khung cutover CN) |

## Tóm tắt Đêm 2 — test lại toàn bộ

**Theo WP:**

| WP | PASS | FAIL | PENDING/⛔ | Ghi chú |
|---|---|---|---|---|
| WP3 (GW-01..GW-20, GW-13b, GW-P1, GW-S1) | 47 dòng | 0 | 0 | Không có test nào trước PASS nay FAIL — parity v1↔v2 giữ nguyên 100%. GW-13 xác nhận đúng kỳ vọng MỚI (tin nhóm không lệnh không tới Router, chỉ ghi log — user đã xác nhận đêm 1); GW-13b (chat riêng + pending upload) PASS đầy đủ nhánh `pendingUpload.task_prefix`. WP3 **vẫn READY FOR CUTOVER**. |
| REG (REG-LU-01, REG-OCR-01..05, REG-VPS-01..05) | 11 dòng | 0 | 1 (REG-VPS-06, MANUAL) | Không có test nào trước PASS nay FAIL. REG-VPS-06 vẫn PENDING đúng kế hoạch (cần người trực + docker restart thật, khung cutover CN). |
| **Tổng** | **58** | **0** | **1** | |

**Danh sách FAIL:** không có. Không có test nào trước đó PASS mà đêm nay FAIL.

**Không có bước nào bị safety/permission từ chối** trong lượt test này (không cần dùng ⛔).

**TEMP workflow tạo trong đêm 2 + xác nhận archive:**
- `ECH0aKo9CXgCD5UE` — "TEMP - REG-OCR-04 nhánh lỗi OCR đêm 2 (xoá sau khi dùng)" — 1 node HTTP GET `httpbin.org/status/500` (`onError:continueErrorOutput`, không credential nào cần gán — `autoAssignedCredentials:[]`) tái hiện đúng cấu trúc 2-output của `Call Qwen OCR` thật — archived ✓ (`archive_workflow` trả `"archived":true`)
- `80821vva7xGpyd6l` — "TEMP - REG-OCR-01 getFile đêm 2 (xoá sau khi dùng)" — REAL test Telegram getFile; lần đầu `create_workflow_from_code` auto-assign nhầm credential Telegram (`@csfsintbot` thay vì `Elite Clickupbot`) — đã sửa bằng `setNodeCredential` về đúng `BHVAx8GV38yQEn1I` ("Elite Clickupbot"), xác nhận lại qua `get_workflow_details` TRƯỚC khi chạy — archived ✓ (`archive_workflow` trả `"archived":true`)

Không publish/unpublish/archive bất kỳ workflow production hay staging (v1/v2/Bot Xử Lý Ảnh/Admin System/Live Update) nào. Không gửi Telegram thật (mọi node Telegram trong PIN test đều dùng dummy `{ok:true,...}`; 2 TEMP REAL chỉ gọi Telegram `getFile` — chỉ đọc — và `httpbin.org` — dịch vụ test công khai, không phải service thật của dự án). Không ghi DB thật.

**Xác nhận cuối bài — versionId không đổi trong suốt lượt test (đọc lại lần cuối lúc kết thúc):**
- v1 `xmEKeIUnzxm2F7dF`: `versionId == activeVersionId == "180005b7-a44a-4c95-ace6-24529ae46566"` ✓ (khớp PLAN §3, khớp đầu bài, khớp đêm 1)
- v2 `hn0YZ85sXtfGACJ4`: `versionId == "dbc644d4-7c8a-44e5-90dd-ec18b9aab157"`, `active:false` ✓ (không đổi, vẫn ở staging)
- Bot Xử Lý Ảnh (`6I4MnJiJCiv2JOIr`): `versionId == activeVersionId == "435af575-e17f-488e-b616-20798790bbdf"` ✓
- Telebot Admin System (`eWtu7Qs85Hes0HuP`): `versionId == activeVersionId == "53d44baa-8e4b-4dd4-8f78-fbcd970fe46f"` ✓
- SQL - ClickUp Live Update (`uqTqjtHYieotPZuc`): `versionId == activeVersionId == "42cfa99b-6659-47dd-8a84-f9fa4e977739"` ✓

**Production/staging không đổi trong suốt lượt test đêm 2.** Không commit git.

## Đêm 2 — WP4 Admin v2 pilot — 2026-09-25T19:45:00Z (Architect sửa: tester ghi nhầm 26/09T20:10)

Bối cảnh: chạy tự động đêm 2 (26/09/2026), không người trực. Test WP4 — Admin v2 pilot (PLAN §7.6
ADM-01..08, + ADM-09 bổ sung theo yêu cầu Architect). Đọc PLAN.md mục 3/5/6 WP4/7.2 REG-VPS-01..05/7.6/7.7,
BUILD_LOG.md mục WP4 (2026-09-25T19:29:23Z), AUDIT_REPORT.md mục WP4 audit #1 (2026-09-25T19:35:58Z,
VERDICT PASS), TEST_REPORT.md REG vòng 2 (REG-VPS-01..05, đêm 1 pin exec 6791/6792 làm output thật),
RULES.md #2/#18/#24/#30/#31. Skill `n8n-mcp-tools-expert` đã gọi trước khi dùng tool n8n MCP.

**Đối tượng:** staging `Admin v2 - Hệ thống (STAGING)` (`bauK573MU18oRzKP`). **Xác nhận versionId TRƯỚC
test:** `4851cb58-ede4-4fb8-b323-3dadad9d2b82` (`active:false`, `activeVersionId:null`) — khớp BUILD_LOG.
**SAU test (toàn bộ 13 kịch bản × 2 bản):** vẫn `4851cb58-ede4-4fb8-b323-3dadad9d2b82` — không đổi.
v1 so sánh: `Telebot Admin System (System Bot dedicated)` `eWtu7Qs85Hes0HuP`. TRƯỚC: `versionId ==
activeVersionId == 53d44baa-8e4b-4dd4-8f78-fbcd970fe46f`. SAU: vẫn `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f`
— không đổi (chỉ gọi `get_workflow_details`/`test_workflow`, không `update_workflow`/`publish_workflow`
trên cả 2 workflow).

**Phương pháp:** PIN (`prepare_workflow_pin_data` + `test_workflow`) trên CẢ v2 (staging, trigger =
`Execute Workflow Trigger`, envelope pin theo contract `{route, params, taskId, chatId, messageId,
isCallback, originalData, config:{ADMIN_CHAT_ID, botUsername}}`, `chatId`/`ADMIN_CHAT_ID` là STRING —
lấy giá trị thật `"975005174"`/`"elite_n8n_system_bot"` từ output node `Phân tích lệnh`/`⚙️ Config` của
exec thật `9239`) VÀ trên v1 (staging không có router riêng nên so trực tiếp với production `eWtu7Qs85Hes0HuP`
qua `test_workflow`+pin, không sửa nó — đúng lựa chọn "hoặc chạy PIN tương ứng trên v1" của đề bài).
ADM-01/02/04/05/06 đối chiếu với REG-VPS-01..05 đã PASS ở TEST_REPORT đêm 1/2 (exec 9239/9240/9241/9242/9243,
cùng corpus `corpus/admin/ADM-0x_*.json`); ADM-03/07/09 không có REG-VPS tương ứng nên tester tự chạy PIN
trên v1 bằng cùng corpus (ADM-03 dùng đúng `ADM-03_callback_vpsrestart.json`) hoặc input tự dựng tương tự
(token/version/error_logs/error_log_now — dựa cấu trúc thật exec `8383`). **`Call Container Restart` LUÔN
được PIN** ở cả v1 và v2 với output giả `{"success":true,"name":"portainer-portainer-1","id":"016d6fddd3b2"}`
— TUYỆT ĐỐI không có lệnh docker restart thật nào được gọi (xác nhận: node này không nằm trong danh sách
Telegram/HTTP thật nào được gọi — chỉ nhận input đã pin). Mọi Telegram/Postgres/HTTP khác đều pin theo
RULES §5.3. Không có node `onError:"continueErrorOutput"` nào trong sub-workflow (toàn bộ 5 node HTTP
dùng `continueRegularOutput`, chỉ 1 output) → không gặp giới hạn "không chọn được output index" của đêm 1;
2 IF 2-output (`Container Info OK?`, `Là Admin?`/`Là vps_cancel?`/`Là Lỗi Route?`) chọn nhánh đúng qua dữ
liệu input, không cần chọn index. Không có TEMP workflow nào được tạo (test trực tiếp trên staging có sẵn
+ v1 bằng pin, đúng lựa chọn PLAN cho phép). Không gửi Telegram thật, không gọi HTTP ngoài thật.

Chú thích ID (đối chiếu route ↔ PLAN §7.6, vì "ADM-01..05" trong PLAN gộp chung 5 kịch bản REG-VPS):
ADM-01=`vps`, ADM-02=`vps_container` (id hợp lệ), ADM-03=`vps_restart`, ADM-04=`vps_cancel`,
ADM-05=`vps_container` (id không tồn tại, // REG-VPS-03), ADM-06=`vps` chat không phải admin
(// REG-VPS-04), ADM-07a..d=`token`/`version`/`error_logs`/`error_log_now` từ admin, ADM-08=STATIC,
ADM-09a/b=`token`/`error_logs` từ chat không phải admin (bổ sung theo yêu cầu).

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| ADM-01 | WP4 | v1 (cite REG-VPS-01) | PIN | `/vps` admin (corpus ADM-01, exec 6791 thật) | `Send VPS Stats` chạy, text có `?start=vpsc_<id>` | `"...?start=vpsc_0b13df56a8c2">🔍 chi tiết</a>"`, `vpsc_211ebda7fd24`, `vpsc_016d6fddd3b2` (TEST_REPORT đêm 1) | exec 9239 | ✅ PASS |
| ADM-01 | WP4 | v2 | PIN | route=`vps`, chatId=`975005174`, `Call VPS Info` pin = output thật exec 9239 (3 container) | Route→`Call VPS Info`→`Build VPS Stats`→`Send VPS Stats`; text có `?start=vpsc_<id>` mỗi container | `Build VPS Stats.text` chứa `"...vpsc_0b13df56a8c2\">🔍 chi tiết</a>"`, `"...vpsc_211ebda7fd24..."`, `"...vpsc_016d6fddd3b2..."` — 3/3 khớp v1; `Send VPS Stats` có trong runData | exec 10558 | ✅ PASS |
| ADM-02 | WP4 | v1 (cite REG-VPS-02) | PIN | deep-link `vpsc_0b13df56a8c2` admin (corpus ADM-02, `Call Container Info` pin exec 6792 thật) | Tới `Send Container Detail`; nút `vpsrestart_0b13df56a8c2` + `vpscancel` | `containerId=="0b13df56a8c2"`; `Send Container Detail` chạy (TEST_REPORT đêm 1) | exec 9240 | ✅ PASS |
| ADM-02 | WP4 | v2 | PIN | route=`vps_container`, params=`0b13df56a8c2`, admin, `Call Container Info` pin = output thật exec 6792 | `Container Info OK?`→true→`Build Container Detail`→`Send Container Detail` | `Build Container Detail.json.containerId=="0b13df56a8c2"`, text `"<b>Tên:</b> <code>n8n_stack-n8n-1</code>..."`; nút cố định trong node config: `callback_data:"={{ 'vpsrestart_' + ...containerId }}"` (`vpsrestart_0b13df56a8c2`) + `"vpscancel"` (đọc tĩnh, giống v1); `Send Container Detail` chạy | exec 10559 | ✅ PASS |
| ADM-03 | WP4 | v1 (tự chạy PIN) | PIN | callback `vpsrestart_016d6fddd3b2` admin (corpus ADM-03 thật, exec gốc 6795); `Call Container Restart` PIN = `{"success":true,"name":"portainer-portainer-1","id":"016d6fddd3b2"}` (KHÔNG gọi docker thật) | `Route VPS Extra`→`Call Container Restart`(pinned)→`Build Restart Result`→`Send Restart Result` | `Build Restart Result.text == "✅ Đã khởi động lại container <code>portainer-portainer-1</code>."`; `Call Container Restart` KHÔNG chạy thật (chỉ nhận pinData) | exec 10550 | ✅ PASS |
| ADM-03 | WP4 | v2 | PIN | route=`vps_restart`, params=`016d6fddd3b2`, admin; `Call Container Restart` PIN = cùng output giả như v1 | `Route`case6→`Call Container Restart`(pinned)→`Build Restart Result`→`Send Restart Result` | `Build Restart Result.text == "✅ Đã khởi động lại container <code>portainer-portainer-1</code>."` — khớp byte-for-byte v1; `Send Restart Result` chạy | exec 10560 | ✅ PASS |
| ADM-04 | WP4 | v1 (cite REG-VPS-05) | PIN | callback `vpscancel` admin (corpus ADM-04 thật) | Tới `Reply VPS Cancelled`, KHÔNG qua cổng admin | `Switch` output `vps_cancel` → `Reply VPS Cancelled` trực tiếp, không qua `Check Admin` (TEST_REPORT đêm 1) | exec 9243 | ✅ PASS |
| ADM-04 | WP4 | v2 | PIN | route=`vps_cancel`, admin | `Là vps_cancel?` true → `Reply VPS Cancelled` trực tiếp, KHÔNG qua `Là Admin?` | `Là vps_cancel?` ra output0 (true, item có mặt), `Là Admin?` KHÔNG có trong runData, `Reply VPS Cancelled` chạy (`ok:true,message_id:99904`) | exec 10561 | ✅ PASS |
| ADM-05 | WP4 | v1 (cite REG-VPS-03) | PIN | deep-link `vpsc_ffffffffffff` admin, `Call Container Info` pin = `{"error":"not_found"}` | Tới `Reply Container Info Failed`, KHÔNG qua `Build Container Detail` | `Container Info OK?` ra output1 (false); `Build Container Detail` KHÔNG có trong runData (TEST_REPORT đêm 1) | exec 9241 | ✅ PASS |
| ADM-05 | WP4 | v2 | PIN | route=`vps_container`, params=`ffffffffffff`, admin, `Call Container Info` pin = `{"error":"not_found"}` | `Container Info OK?` false → `Reply Container Info Failed`, KHÔNG qua `Build Container Detail` | `Container Info OK?.data.main[1][0].json=={"error":"not_found"}`; `Build Container Detail` KHÔNG có trong runData; `Reply Container Info Failed` chạy | exec 10562 | ✅ PASS |
| ADM-06 | WP4 | v1 (cite REG-VPS-04) | PIN | `/vps` chat `111111111` (không phải admin) | Tới `Reply Không Có Quyền (VPS)`, KHÔNG gọi `Call VPS Info` | `Check Admin (VPS)` ra output1 (false); `Call VPS Info` KHÔNG có trong runData (TEST_REPORT đêm 1) | exec 9242 | ✅ PASS |
| ADM-06 | WP4 | v2 | PIN | route=`vps`, chatId=`111111111` (≠ ADMIN_CHAT_ID `975005174`) | `Là Admin?` false → `Là Lỗi Route?` false → `Reply Không Có Quyền (VPS)`; KHÔNG gọi `Call VPS Info` | `Là Admin?.data.main[0]==[]` (nhánh true rỗng); `Call VPS Info` KHÔNG có trong runData dù đã pin sẵn (đề phòng); `Reply Không Có Quyền (VPS)` chạy (`ok:true,message_id:99906`) | exec 10563 | ✅ PASS |
| ADM-07a (token) | WP4 | v1 | PIN | `/token` admin (corpus ADM-05 thật, cấu trúc exec 8383); `Call DeepSeek Balance`/`Call OpenRouter Key Info` pin cùng data giả | `Check Admin (Token)`→ Call DeepSeek+OpenRouter → `Merge`→`Build Token Stats`→`Send Token Stats` | `Send Token Stats` chạy; `Build Token Stats.text` = `"<b>🔢 Thống kê token AI</b>...Còn lại: $37.6544...Trạng thái: ✅ Khả dụng"` | exec 10551 | ✅ PASS |
| ADM-07a (token) | WP4 | v2 | PIN | route=`token`, admin, `Call DeepSeek Balance`/`Call OpenRouter Key Info` pin = cùng data giả như v1 | `Route`case`token`→2 Call song song→`Merge Token Results`→`Build Token Stats`→`Send Token Stats` | `Build Token Stats.text` giống hệt v1 ký tự-cho-ký tự: `"<b>🔢 Thống kê token AI</b>\n\n<b>OpenRouter</b>\n• Tổng đã nạp: $50.0000\n• Đã dùng: $12.3456\n• Còn lại: $37.6544\n\n<b>DeepSeek</b>..."`; `Send Token Stats` chạy | exec 10564 | ✅ PASS |
| ADM-07b (version) | WP4 | v1 | PIN | `/version` admin (corpus ADM-06 synthetic), `Query Changelog` pin = 1 dòng giả | `Check Admin (Version)`→`Query Changelog`→`Build Version Text`→`Send Version Text` | `Build Version Text.text` = `"<b>📦 Phiên bản hiện tại: 1.2.3</b> (cập nhật 2026-09-20)..."` | exec 10552 | ✅ PASS |
| ADM-07b (version) | WP4 | v2 | PIN | route=`version`, admin, `Query Changelog` pin = cùng 1 dòng giả | `Route`case`version`→`Query Changelog`→`Build Version Text`→`Send Version Text` | `Build Version Text.text` giống hệt v1 ký tự-cho-ký tự (`"<b>📦 Phiên bản hiện tại: 1.2.3</b>..."`); `Send Version Text` chạy | exec 10565 | ✅ PASS |
| ADM-07c (error_logs) | WP4 | v1 | PIN | `/error_logs` admin (corpus ADM-07 synthetic), `Errors: Query Recent` pin = 1 dòng giả | `Check Admin (Errors)`→`Switch`out0→`Errors: Query Recent`→`Errors: Build Report (Logs)`→`Lichsu: Send` | `Errors: Build Report (Logs).text` bắt đầu `"📊 <b>Thống kê lỗi 7 ngày qua</b> (tổng 2 — ✅ đã sửa 1 · 🔓 còn mở 1)\n\n• Test WF: 1 lỗi..."` | exec 10553 | ✅ PASS |
| ADM-07c (error_logs) | WP4 | v2 | PIN | route=`error_logs`, admin, `Errors: Query Recent` pin = cùng dòng giả | `Route`case`error_logs`→`Switch (Error Actions)`out0→...→`Lichsu: Send` | `Errors: Build Report (Logs).text` giống hệt v1 ký tự-cho-ký tự; `Lichsu: Send` chạy | exec 10566 | ✅ PASS |
| ADM-07d (error_log_now) | WP4 | v1 | PIN | `/error_log_now` admin (tự dựng theo cấu trúc `/token` thật), `Errors: Mark Reported` pin = 1 dòng giả | `Switch`out1→`Errors: Mark Reported`→`Errors: Build Report (Now)`→`Lichsu: Send` | `Errors: Build Report (Now).text` bắt đầu `"✅ <b>Đã tổng hợp 1 lỗi (7 ngày qua) vào DB</b> (7 ngày: ✅ đã sửa 0 · 🔓 còn mở 1 · Σ 1)..."` | exec 10554 | ✅ PASS |
| ADM-07d (error_log_now) | WP4 | v2 | PIN | route=`error_log_now`, admin, `Errors: Mark Reported` pin = cùng dòng giả | `Route`case`error_log_now`→`Switch (Error Actions)`out1→...→`Lichsu: Send` | `Errors: Build Report (Now).text` giống hệt v1 ký tự-cho-ký tự; `Lichsu: Send` chạy | exec 10567 | ✅ PASS |
| ADM-08 | WP4 | v2 | STATIC | `get_workflow_details(bauK573MU18oRzKP)` full JSON, 33 node | Không còn `$('Phân tích lệnh')`/`$('⚙️ Config')`; mọi Telegram credential `zSZ6vVapow5LNpFT` | Quét toàn bộ `parameters` của 33 node: 0 lần xuất hiện chuỗi `Phân tích lệnh` hoặc `⚙️ Config`; mọi tham chiếu là `$('Execute Workflow Trigger')...`/`$('Build ...')...`/`$('Call ...')...`. 10/10 node Telegram (`Lichsu: Send`, `Reply Không Có Quyền (Errors)`, `Send Version Text`, `Send Token Stats`, `Send VPS Stats`, `Reply Không Có Quyền (VPS)`, `Reply Container Info Failed`, `Send Restart Result`, `Send Container Detail`, `Reply VPS Cancelled`) đều `credentials.telegramApi=={"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}` | get_workflow_details (không có execution) | ✅ PASS |
| ADM-09a (token) | WP4 | v1 | PIN | `/token` chat `111111111` (không phải admin) | `Reply Không Có Quyền (Token)` chạy, KHÔNG gọi Call DeepSeek/OpenRouter | `Check Admin (Token)` ra output1(false); `Reply Không Có Quyền (Token)` chạy; `Call DeepSeek Balance`/`Call OpenRouter Key Info` KHÔNG có trong runData dù đã pin sẵn (đề phòng, không bị gọi) | exec 10555 | ✅ PASS |
| ADM-09a (token) | WP4 | v2 | PIN | route=`token`, chatId=`111111111` | `Là Admin?` false→`Là Lỗi Route?` false (route≠error_*)→`Reply Không Có Quyền (VPS)` (node gộp thay `(Token)` — đúng thiết kế BUILD_LOG#3); text phải khớp v1 | `Reply Không Có Quyền (VPS)` chạy (`ok:true,message_id:99911`); text node (đọc tĩnh) = `"🚫 Bạn không có quyền dùng lệnh này."` — **giống hệt** text `Reply Không Có Quyền (Token)` của v1 (cùng chuỗi, xác nhận qua BUILD_LOG §"Design decisions" #3 + AUDIT_REPORT dòng "Text nhánh không quyền"); `Call DeepSeek Balance`/`Call OpenRouter Key Info` KHÔNG có trong runData | exec 10568 | ✅ PASS |
| ADM-09b (error_logs) | WP4 | v1 | PIN | `/error_logs` chat `111111111` | `Reply Không Có Quyền (Errors)` chạy, KHÔNG gọi `Errors: Query Recent` | `Check Admin (Errors)` ra output1(false); `Reply Không Có Quyền (Errors)` chạy; `Errors: Query Recent` KHÔNG có trong runData | exec 10556 | ✅ PASS |
| ADM-09b (error_logs) | WP4 | v2 | PIN | route=`error_logs`, chatId=`111111111` | `Là Admin?` false→`Là Lỗi Route?` true (route=error_logs)→`Reply Không Có Quyền (Errors)`; text phải khớp v1 | `Là Lỗi Route?` ra output0 (true); `Reply Không Có Quyền (Errors)` chạy (`ok:true,message_id:99912`); text node (đọc tĩnh, node copy nguyên `id` từ v1) = `"⚠️ Bạn không có quyền thực hiện lệnh này."` — **giống hệt v1** (cùng node `id`, cùng text); `Errors: Query Recent` KHÔNG có trong runData dù đã pin sẵn (đề phòng) | exec 10569 | ✅ PASS |

### Tóm tắt WP4 (đêm 2)

- ✅ PASS: 23/23 (ADM-01..07d, 09a/09b mỗi cái 2 dòng v1+v2 = 22, + ADM-08 STATIC 1 dòng = 23). ❌ FAIL: 0.
  ⏳ PENDING: 0 (không gặp node `onError:"continueErrorOutput"` nào trong sub-workflow — giới hạn "không
  chọn được output index" của đêm 1 không áp dụng cho WP4; 2 nhánh IF 2-output đã chọn đúng nhánh bằng dữ
  liệu input, không cần chọn index).
- **Kết luận parity v1↔v2:** mọi route (`vps`, `vps_container` hợp lệ/không tồn tại, `vps_restart`,
  `vps_cancel`, `token`, `version`, `error_logs`, `error_log_now`) ra đúng node đích và text giống hệt v1
  ký tự-cho-ký tự khi cùng input. 2 khác biệt CÓ CHỦ ĐÍCH đã ghi trong BUILD_LOG (gộp node "Reply Không Có
  Quyền") được xác nhận KHÔNG đổi hành vi/text quan sát được (ADM-09a): node đích khác tên
  (`Reply Không Có Quyền (VPS)` thay vì `(Token)`/`(Version)`) nhưng text gửi đi giống hệt.
- **An toàn:** `Call Container Restart` được PIN ở MỌI lần chạy (kể cả trên v1) — 0 lệnh `docker restart`
  thật được gọi trong suốt WP4. 0 tin Telegram thật được gửi (mọi node Telegram đều pin). Không có TEMP
  workflow nào được tạo (test trực tiếp trên staging `bauK573MU18oRzKP` có sẵn + PIN trên production
  `eWtu7Qs85Hes0HuP`, không `update_workflow`/`publish_workflow`/`archive_workflow` nào được gọi trên 2
  workflow này).
- **Xác nhận versionId (trước và sau toàn bộ 24 lần `test_workflow`):** staging `bauK573MU18oRzKP`
  `versionId` không đổi = `4851cb58-ede4-4fb8-b323-3dadad9d2b82` (`active:false`, `activeVersionId:null`).
  v1 `eWtu7Qs85Hes0HuP` `versionId==activeVersionId` không đổi = `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f`.
  Không có bước nào bị safety/permission classifier từ chối trong lượt test này.
- Không commit git (theo yêu cầu).
