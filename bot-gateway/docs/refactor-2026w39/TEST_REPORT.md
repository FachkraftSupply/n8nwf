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
