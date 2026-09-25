# Kế hoạch refactor workflow — tuần 39/2026 (Workflow Architect)

> Dựa trên [`AUDIT_2026-09-24.md`](./AUDIT_2026-09-24.md). Mọi agent (builder, auditor, tester) đọc
> file này + `bot-gateway/docs/RULES.md` TRƯỚC khi làm bất cứ gì. File này là nguồn sự thật duy nhất
> cho phạm vi, thứ tự và điều kiện dừng.

## 0. Bảng trạng thái (agent cập nhật khi xong từng bước)

| WP | Nội dung | Build | Audit | Test | Trạng thái | Cutover |
|---|---|---|---|---|---|---|
| WP0 | Chuẩn bị: folder staging, ghi mốc rollback, bộ dữ liệu test | — | — | — | ✅ | — |
| WP1 | GW Error Handler v2 | ✅ | ✅ | 🟨 5/10 PASS; ERR-01/02/04rt/05/07 ⛔ (classifier chặn PROD-FAIL, đêm 2) | ⛔ chờ user (mục 9 đêm 2) | CN 27/09 (nếu user chọn) |
| WP2 | Workflow "DB Migrations (chạy tay)" | ✅ | ✅ | ✅ MIG-01..04 (MIG-04 đêm 2: 26/26 object) | ✅ | đã chạy 25/09 16:32 + 17:34 |
| WP3 | GW Gateway v2 | ✅ | ✅ | ✅ 47/47 (đêm 2 test lại: 47/47) | ✅ READY FOR CUTOVER | CN 27/09 |
| WP4 | Admin System v2 — pilot 1 domain | ✅ | ✅ | ✅ 23/23 (ADM-01..09) | ✅ pilot đạt (chỉ staging, không cutover) | tuần sau |
| WP5 | Gắn error workflow cho workflow còn thiếu | — | ✅ (danh sách) | ⛔ ERR-05 (như WP1) | ⛔ phụ thuộc WP1 | CN 27/09 (nếu WP1 đạt) |
| REG | Bộ test hồi quy trên production hiện tại (chỉ đọc) | — | — | ✅ (đêm 2: 11/11, VPS-06 MANUAL) | ✅ | — |

Ký hiệu: ⬜ chưa làm · 🟨 đang làm · ✅ PASS · ❌ FAIL · ⛔ BLOCKED (ghi lý do ở mục 9).

## 1. Mục tiêu

1. **Không làm gián đoạn production** trong suốt quá trình build/test. Chỉ có 1 thời điểm thay đổi
   production: cutover có người trực, trong khung 0 traffic, có rollback 1 bước.
2. **Ổn định hơn:** lỗi không bị mất (F1, F2), không phụ thuộc task runner ở những chỗ không cần (F4, F9).
3. **Nhanh hơn:** giảm độ trễ Gateway (F9), bỏ DDL mỗi request (F6), bỏ ghi trùng (F5).
4. **Dễ quản lý hơn:** chứng minh được mô hình tách Admin System bằng 1 pilot trước khi tách toàn bộ.

## 2. Brainstorm — các phương án đã cân nhắc

| Phương án | Mô tả | Ưu | Nhược | Kết luận |
|---|---|---|---|---|
| A. Sửa tại chỗ | Sửa từng node trực tiếp trên workflow đang chạy, publish ngay | Nhanh | Mỗi lần sửa là live ngay; 2 regression ngày 24/09 đến từ đúng cách này | ❌ Loại |
| **B. Blue/Green staging** | Xây bản `v2` riêng (inactive) trong folder staging, test bằng pin data + so sánh với v1, cutover thủ công trong khung 0 traffic, rollback 1 bước | Production không bị chạm cho tới cutover; so sánh v1↔v2 trên cùng input; rollback tức thì | Tốn công clone; 2 workflow cùng Telegram Trigger không active song song được | ✅ **Chọn** |
| C. Viết lại từ đầu | Kiến trúc mới hoàn toàn (vd bot code ngoài n8n) | Sạch | Không có baseline để so; rủi ro rất cao; quá lớn cho 1 cuối tuần | ❌ Loại |
| D. Instance n8n dev riêng | Thêm 1 container n8n thứ 2 để test | Cô lập tốt nhất | Cần thao tác docker/SSH ghi (bị safety classifier chặn khi chạy không người trực), nhân đôi credential | ⏸ Để sau |

### Các quyết định đã chốt (Architect)

- **D1. Blue/Green + cutover thủ công.** Lượt chạy 2h sáng CHỈ build + audit + test trong staging. KHÔNG
  cutover, KHÔNG publish/unpublish bất kỳ workflow production nào lúc 2h.
- **D2. Parity trước, cải tiến hành vi sau.** v2 phải cho kết quả giống hệt v1 trên cùng input (cùng
  route, cùng bot_key, cùng chat, cùng text, cùng callback_data). Chỉ được khác ở những điểm liệt kê
  rõ trong spec từng WP ("khác biệt cho phép"). Các sửa hành vi (F7 DEFAULT_BOT, F8 Supabase mirror, F13
  help text) để sau cutover, làm riêng.
- **D3. Không đụng 3 workflow có bản nháp chưa publish** (Blacklist `jPaCu9Yv6fgnsKsi`, TTLock
  `vGgJ0XfTR3ltohPB`, Rule Engine `ow1fAaAYwxaZjyD4`) — kể cả đổi settings. Publish sẽ đẩy luôn bản nháp
  của người khác lên production. F3 (Rule Engine chạy chồng) được ghi lại, chờ chủ sở hữu xác nhận.
- **D4. Giữ nguyên Supabase mirror thật** (7 node Admin + 2 node Approve/Deny Gateway). Chỉ bỏ 2 node
  mang tên "(Supabase)" nhưng thực ra ghi trùng vào Docker (F5) — bỏ đi không mất dữ liệu nào.
- **D5. Thứ tự:** quan sát lỗi trước (WP1) → migration additive (WP2) → Gateway (WP3) → pilot Admin
  (WP4, chỉ khi WP1–3 xong). Lý do: phải thấy được lỗi trước khi thay đổi bất cứ thứ gì.
- **D6. Admin System tách theo kiểu pilot:** chỉ tách 1 domain ("Hệ thống": `/error_logs`,
  `/error_log_now`, `/version`, `/token`, `/vps` + container) để chứng minh contract router↔sub-workflow.
  Không tách toàn bộ trong cuối tuần này.
- **D7. Khung cutover:** Chủ nhật 27/09/2026, 19:00–22:00 giờ VN (14:00–17:00 giờ Đức). 14 ngày qua
  khung này có 0 request.

## 3. Hằng số dùng chung

### Production — ID và mốc rollback (WP0 phải xác nhận lại bằng `get_workflow_details`)

| Workflow | ID | activeVersionId (mốc rollback) |
|---|---|---|
| GW Gateway - Telegram (DEV) | `xmEKeIUnzxm2F7dF` | `180005b7-a44a-4c95-ace6-24529ae46566` |
| Telebot Admin System | `eWtu7Qs85Hes0HuP` | `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f` |
| Bot Xử Lý Ảnh | `6I4MnJiJCiv2JOIr` | `435af575-e17f-488e-b616-20798790bbdf` |
| SQL - ClickUp Live Update | `uqTqjtHYieotPZuc` | `42cfa99b-6659-47dd-8a84-f9fa4e977739` |
| Telebot ClickUp Reader | `9JJRrh36H2rLwtnu` | `4437fece-36da-4ccc-82fa-16e5330c7960` |
| GW Error Handler | `34ccboHpyoY2r691` | `1a6b1d2a-2ff8-4cf0-ae59-9ae3e978a183` |
| SQL - ClickUp Full Reconcile | `G1R0okF0rUziySu9` | WP0 ghi lại |
| Interview Evaluation | `oF4IWJf6Yad2wF5G` | WP0 ghi lại |

**Cấm đụng (D3):** `jPaCu9Yv6fgnsKsi`, `vGgJ0XfTR3ltohPB`, `ow1fAaAYwxaZjyD4`.

### Credentials (copy nguyên ID + name, không tự chọn khác — RULES.md #25)

| Tên | Loại | ID |
|---|---|---|
| Postgres account (DB chính, Docker) | postgres | `GwUFREmcXzXXj5mZ` |
| Supabase Postgres | postgres | `hO4yfw7ailV7jHAv` |
| Elite Clickupbot | telegramApi | `BHVAx8GV38yQEn1I` |
| Telegram System Bot | telegramApi | `zSZ6vVapow5LNpFT` |
| OpenRouter account | openRouterApi | `BOzvluQs5DGXl9Yr` |
| X-Auth-Token (vps-monitor) | httpHeaderAuth | `Ri6Y4WtEuLgl9ixb` |
| REMOVE.BG | httpTemplatedCustomAuth | `qgEe19xg0uSNL0lo` |

### Nơi nhận tin khi test (ngoài ra CẤM gửi Telegram thật)

- DM admin: `975005174` (qua Telegram System Bot).
- Topic lỗi của admin: chat `-1003647848349`, `message_thread_id: 4` (chỉ cho test WP1).
- **Không bao giờ** gửi vào nhóm người dùng (`-1003044712131`, `-1002768213220`, `-5535257695`, ...).

### Quy ước đặt tên

- Workflow staging: `<tên gốc> v2 (STAGING)`, đặt trong folder n8n `REFACTOR 2026-W39 (staging)`.
- Workflow test tạm: `TEMP - <mục đích> (xoá sau khi dùng)` → `archive_workflow` ngay sau khi test xong.
- File bàn giao (cùng thư mục với file này): `BUILD_LOG.md` (builder), `AUDIT_REPORT.md` (auditor),
  `TEST_REPORT.md` (tester).

## 4. Quy trình (pipeline) cho lượt chạy 2h sáng

```
Architect (main) ──spec WPn──▶ builder ──BUILD_LOG──▶ auditor ──AUDIT_REPORT──▶ tester ──TEST_REPORT──▶ Architect
        ▲                         │                      │ FAIL                    │ FAIL
        └──────── cập nhật mục 0 ─┴──────◀── sửa (tối đa 2 vòng) ◀─────────────────┘
```

1. **Architect** giao cho `builder` đúng 1 WP (trỏ tới mục tương ứng trong file này), đợi xong.
2. **builder** build trong staging, ghi `BUILD_LOG.md` (ID workflow tạo ra, danh sách thay đổi so với
   v1, lệnh kiểm tra đã chạy). builder KHÔNG tự tuyên bố "đạt".
3. **auditor** audit tĩnh theo RULES.md + skill n8n → `AUDIT_REPORT.md` (PASS/FAIL từng mục).
4. **tester** chạy các test trong mục 7 thuộc WP đó → `TEST_REPORT.md` (bảng chi tiết).
5. FAIL ở audit hoặc test → Architect gửi lại builder kèm báo cáo lỗi. **Tối đa 2 vòng sửa/WP.** Quá 2
   vòng → đánh ⛔ BLOCKED, ghi lý do, chuyển WP tiếp theo. Không cố "ép" cho qua.
6. WP chỉ được đánh "READY FOR CUTOVER" khi audit PASS **và** mọi test của WP PASS (test MANUAL được
   phép để PENDING).
7. Cuối lượt: Architect cập nhật mục 0, viết tóm tắt ở mục 9, gửi thông báo cho user.

## 5. Luật an toàn cho lượt chạy không người trực (áp dụng cho MỌI agent)

1. **Không** `update_workflow` / `publish_workflow` / `unpublish_workflow` / `archive_workflow` /
   `restore_workflow_version` trên bất kỳ workflow production nào (mục 3). Chỉ được thao tác trên
   workflow do chính lượt chạy này tạo ra (v2 STAGING và TEMP).
2. Ngoại lệ duy nhất chạm production: **chạy WP2** (DDL chỉ gồm `CREATE TABLE IF NOT EXISTS`,
   `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`). Cấm `DROP`, `ALTER ... TYPE`,
   `DELETE`, `UPDATE`, `TRUNCATE`.
3. Test mặc định bằng **pin data** (`prepare_workflow_pin_data` + `test_workflow`). Khi dùng
   `test_workflow`, BẮT BUỘC pin **mọi** node: Telegram (gửi/xoá/tải file), Postgres, Supabase, HTTP
   Request, Execute Workflow, ClickUp, Excel. Node `executeWorkflow` không có credential nhưng nếu không
   pin nó sẽ gọi sub-workflow THẬT → gửi tin thật cho người dùng thật.
4. Chỉ các test đánh dấu `REAL` trong mục 7 mới được gọi dịch vụ ngoài thật, và chỉ các lệnh chỉ-đọc
   hoặc chi phí rất nhỏ (Telegram getFile, OpenRouter OCR ~0.0001$). Cấm gọi thật: TTLock unlock,
   `docker restart`/`/container-restart`, remove.bg, gửi email, huỷ lịch.
5. Không SSH ghi, không lệnh docker. SQL chỉ-đọc được phép.
6. Mỗi workflow TEMP phải `archive_workflow` ngay khi test xong (kể cả khi FAIL).
7. Gặp điều gì không có trong kế hoạch mà cần quyết định của con người → dừng WP đó, ghi ⛔ + câu hỏi ở
   mục 9, chuyển WP tiếp theo. Không tự đoán rồi làm.

## 6. Đặc tả từng work package

### WP0 — Chuẩn bị (không đụng production)

1. Tạo folder n8n `REFACTOR 2026-W39 (staging)` (project `5cL5BKorhKAQ2ONI`).
2. `get_workflow_details` (detailLevel `execution`) cho mọi workflow ở mục 3 → xác nhận
   `activeVersionId` và ghi vào `BUILD_LOG.md` (mốc rollback thật tại thời điểm chạy). Nếu khác bảng
   mục 3 → ghi chú (có người đã sửa từ 24/09).
3. **Bộ dữ liệu test (corpus):** lấy update Telegram thật từ output node `Telegram Trigger Gateway` của
   các execution Gateway gần đây (`search_workflow_executions` + `get_workflow_execution`), lưu dạng JSON
   vào `bot-gateway/docs/refactor-2026w39/corpus/gateway/*.json`, mỗi file 1 update. Cần phủ đủ loại ở
   mục 7.3. Loại nào không có mẫu thật → tạo từ 1 mẫu thật gần nhất bằng cách sửa trường, ghi rõ
   `"synthetic": true` trong file.
   ⚠️ Corpus chứa tên/ID người dùng thật → KHÔNG commit thư mục `corpus/` lên git (repo public). Thêm
   `bot-gateway/docs/refactor-2026w39/corpus/` vào `.gitignore`.
4. Tương tự cho Telebot Admin System (update từ `Telegram Trigger (System Bot)`) →
   `corpus/admin/*.json` (chỉ cần cho WP4).

### WP1 — GW Error Handler v2

**Vấn đề:** F1. **Nguyên tắc:** ghi DB trước, không phụ thuộc task runner, không để Telegram 429 làm
hỏng execution.

**Bước 0 (thuộc WP2):** bảng `gateway.error_alert_throttle` phải tồn tại trước.

**Luồng v2** (workflow mới `GW Error Handler v2 (STAGING)`, không có Code node nào):

1. `Error Trigger` (n8n-nodes-base.errorTrigger v1).
2. `Chuẩn Hoá Lỗi` — **Set node** (v3.4, `includeOtherFields: false`), các trường (giữ đúng tên như v1):
   - `workflowName` = `{{ $json.workflow?.name || 'unknown' }}`
   - `workflowId` = `{{ $json.workflow?.id || '' }}`
   - `nodeName` = `{{ $json.execution?.lastNodeExecuted || $json.trigger?.error?.node?.name || '?' }}`
   - `errorMessage` = `{{ String($json.execution?.error?.message || $json.trigger?.error?.message || 'unknown error').slice(0, 2000) }}`
   - `executionId` = `{{ $json.execution?.id || '' }}`
   - `executionUrl` = `{{ $json.execution?.url || '' }}`
   - `text` = giữ đúng định dạng v1: `🚨 LỖI WORKFLOW\n📋 <wf>\n📍 Node: <node>\n❌ <msg 500 ký tự>\n🔗 <url>`
3. `Ghi Lỗi + Kiểm Tra Gộp` — Postgres executeQuery (credential `Postgres account`), 1 câu duy nhất:
   ```sql
   WITH ins_log AS (
     INSERT INTO gateway.error_logs (workflow_name, workflow_id, node_name, error_message, execution_id, execution_url)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id
   ), thr AS (
     INSERT INTO gateway.error_alert_throttle (bucket_key)
     VALUES ($2 || '|' || $3 || '|' || to_char(date_trunc('minute', now()), 'YYYYMMDDHH24MI'))
     ON CONFLICT (bucket_key) DO UPDATE
       SET suppressed_count = gateway.error_alert_throttle.suppressed_count + 1
     RETURNING (xmax = 0) AS is_first
   )
   SELECT (SELECT id FROM ins_log) AS log_id, (SELECT is_first FROM thr) AS should_alert;
   ```
   `queryReplacement` = `={{ [ $json.workflowName, $json.workflowId, $json.nodeName, $json.errorMessage, $json.executionId, $json.executionUrl ] }}`.
   Settings (qua `setNodeSettings` cùng batch — RULES #18): `retryOnFail: true, maxTries: 3,
   waitBetweenTries: 2000, alwaysOutputData: true, onError: continueRegularOutput`.
   Lý do dùng `ON CONFLICT`: chỉ 1 execution trong số N execution đồng thời thắng được `INSERT` → chỉ 1
   cảnh báo/phút cho cùng (workflow, node). Các lần sau đếm vào `suppressed_count`.
4. `Cần Gửi Cảnh Báo?` — IF: `{{ $json.should_alert === true || !$json.log_id }}` is true (boolean).
   _(Sửa 25/09 theo audit WP1 #1: nếu node Postgres lỗi — DB sập/thiếu bảng — thì không có `log_id`
   → vẫn gửi cảnh báo như v1, không bị gộp. Nếu không, DB lỗi = mất sạch cảnh báo, là regression.)_
5. `Báo admin Telegram` — Telegram sendMessage (credential `Telegram System Bot`), chat
   `-1003647848349`, `message_thread_id: 4`, `text` = `={{ $('Chuẩn Hoá Lỗi').first().json.text }}`
   (tham chiếu tường minh — RULES #2). Settings: `retryOnFail: true, maxTries: 3, waitBetweenTries: 5000,
   onError: continueRegularOutput`.

**Khác biệt cho phép so với v1:** lỗi trùng (cùng workflow + node) trong cùng 1 phút chỉ gửi 1 tin.
**Settings workflow:** không đặt errorWorkflow cho chính nó.
**Cutover (CN):** xem WP5. v1 giữ nguyên (không cần tắt) → rollback = trỏ errorWorkflow về v1.

### WP2 — Workflow "DB Migrations (chạy tay)"

Workflow mới `DB Migrations (chạy tay) (STAGING)`: `Manual Trigger` → 1 node Postgres
(`Postgres account`) chạy toàn bộ DDL, theo thứ tự:

1. **Copy NGUYÊN VĂN** query của các node DDL hiện có (đọc qua `get_workflow_details`, không viết lại):
   Gateway `Ensure Pending Uploads Table`; Reader `Ensure Zalo Notify Column`,
   `Ensure Pending Upload Columns`, `Ensure Notify Queue Columns`; Admin `Ensure Sync Table`,
   `Ensure Mention Tables (Admin)`; TTLock `Ensure Schema (Lock)` (chỉ đọc TTLock, không sửa nó).
2. Bảng mới cho WP1:
   ```sql
   CREATE TABLE IF NOT EXISTS gateway.error_alert_throttle (
     bucket_key TEXT PRIMARY KEY,
     created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
     suppressed_count INTEGER NOT NULL DEFAULT 0
   );
   CREATE INDEX IF NOT EXISTS idx_error_alert_throttle_created ON gateway.error_alert_throttle (created_at);
   ```
3. Auditor kiểm tra câu lệnh chỉ chứa loại được phép (mục 5.2) TRƯỚC khi chạy. Chạy 1 lần bằng
   `execute_workflow` (manual) sau khi audit PASS. Chạy lần 2 để xác nhận idempotent.

Workflow này giữ lại vĩnh viễn làm "nơi duy nhất chứa DDL". Các node `Ensure ...` trong workflow
production chỉ được bỏ trong bản v2 của workflow đó (WP3 cho Gateway; các workflow khác làm sau).

### WP3 — GW Gateway v2

**Cách build (clone chính xác rồi mới sửa):**

1. Đọc JSON v1 (`xmEKeIUnzxm2F7dF`) bằng `get_workflow_details`.
2. Viết script (python/jq, trong scratchpad) sinh các batch operation cho `update_workflow` từ JSON v1:
   tạo 1 workflow placeholder bằng `create_workflow_from_code` → `addNode` toàn bộ node (giữ nguyên
   `parameters`, `credentials`, `position`, `typeVersion`; **bỏ** `webhookId` để n8n tự sinh) →
   `setNodeSettings` cho mọi node có `onError`/`alwaysOutputData`/`retryOnFail`/`maxTries`/
   `waitBetweenTries` (RULES #18) → `addConnection` toàn bộ (dùng `sourceIndex`/`targetIndex` —
   RULES #13) → xoá node placeholder. Tối đa 100 op/lần gọi; tất cả addNode trước, addConnection sau
   (RULES #25).
3. **Kiểm tra clone** bằng script so sánh JSON v2 vs v1: cùng số node, cùng tên, `parameters` giống hệt,
   credentials giống hệt, settings node giống hệt, tập connection giống hệt. Ghi kết quả vào BUILD_LOG.
   Chỉ khi clone khớp 100% mới làm bước 4.
4. **Áp dụng đúng 4 thay đổi**, mỗi thay đổi 1 lần `update_workflow` riêng (dễ audit):
   - **C1** Xoá `Audit Log (Supabase)` và `Tạo pending user (Supabase)` (F5 — cả 2 đang ghi trùng vào
     Docker). Không nối lại gì (cả 2 là nhánh cụt song song).
   - **C2** Xoá `Ensure Pending Uploads Table`; nối `Trạng thái user?` output 3 (`active`) →
     `GW-04 Check Pending Upload`. Kiểm tra `GW-04 Check Pending Upload` vẫn có
     `alwaysOutputData: true` (RULES #18, sự cố 16/09).
   - **C3** Thay `⚙️ Config` (Code) bằng **Set node** cùng tên `⚙️ Config`, `includeOtherFields: false`,
     các trường `ADMIN_CHAT_ID` (string), `AVAILABLE_BOTS` (array), `COMMAND_MAP` (object),
     `DEFAULT_BOT` (string) — giá trị copy nguyên từ v1. Giữ `retryOnFail/maxTries/waitBetweenTries` như
     v1. Mọi tham chiếu `$('⚙️ Config').first().json.X` phía sau phải vẫn trả đúng kiểu (array/object,
     không phải string JSON).
   - **C4** Gộp `GW-04b Merge Pending` vào `GW-03 Router`: xoá `GW-04b Merge Pending`, nối
     `GW-04 Check Pending Upload` → `GW-03 Router`, sửa code Router: thay dòng
     `const env = $input.first().json;` bằng:
     ```js
     const base = $('GW-02b Merge Auth').first().json;
     const rows = $input.all().map(i => i.json).filter(r => r && r.task_id);
     const env = { ...base, pendingUpload: rows.length ? rows[0] : null };
     ```
     Phần còn lại của Router giữ nguyên từng ký tự. Output phải giống hệt v1 (có field `pendingUpload`).
5. Settings workflow v2 giống v1 (`errorWorkflow: 34ccboHpyoY2r691`, `callerPolicy`, `executionOrder: v1`).
6. v2 **không active**. Không đổi `workflowId` của các node `→ Sub: ...` (vẫn trỏ sub-workflow production;
   an toàn vì v2 không chạy thật cho tới cutover, và khi test các node này bị pin).

**Khác biệt cho phép:** không còn dòng audit trùng; không còn DDL; `⚙️ Config` là Set node; bớt 2 Code
node trên đường chạy lệnh (từ 5 xuống 3). Mọi output khác phải giống v1.

**Cutover (CN, có người trực):** xem mục 8.

### WP4 — Admin System v2: pilot domain "Hệ thống" (chỉ staging)

Chỉ làm khi WP1–WP3 đều READY hoặc BLOCKED xong. Time-box: nếu tới 06:00 chưa xong → dừng sạch, ghi
trạng thái.

**Mục tiêu pilot:** chứng minh contract "router → sub-workflow" cho Admin System, không phải tách toàn bộ.

1. Workflow `Admin v2 - Hệ thống (STAGING)`: `Execute Workflow Trigger` (inputSource `passthrough`) +
   di chuyển (copy) các node của 5 route: `error_logs`, `error_log_now`, `version`, `token`, `vps`,
   `vps_container`, `vps_restart`, `vps_cancel` (từ `Check Admin (Errors)` / `(Version)` / `(Token)` /
   `(VPS)` / `(VPS Extra)` trở về sau).
2. **Contract đầu vào** (object sub-workflow nhận): `{ route, params, taskId, chatId, messageId,
   isCallback, originalData, config: { ADMIN_CHAT_ID, botUsername } }`.
3. **Việc bắt buộc khi copy node sang sub-workflow:** mọi tham chiếu `$('Phân tích lệnh')...` và
   `$('⚙️ Config')...` KHÔNG còn tồn tại trong sub-workflow → phải đổi thành
   `$('Execute Workflow Trigger').first().json...` tương ứng. Builder liệt kê TOÀN BỘ tham chiếu đã đổi
   (grep trước/sau) vào BUILD_LOG — đây là điểm rủi ro cao nhất của WP4 (RULES #5, #10).
4. Cổng admin: 1 IF duy nhất ở đầu sub-workflow (`chatId === config.ADMIN_CHAT_ID`) thay cho
   `Check Admin (Errors)`, `(Version)`, `(Token)`, `(VPS)`, `(VPS Extra)` (F11).
5. **Không** tạo router v2 cho Admin trong cuối tuần này. Test pilot bằng cách gọi sub-workflow trực
   tiếp với envelope pin sẵn (mục 7).
6. Credential tất cả node Telegram giữ `Telegram System Bot` (RULES #23 — callback `vpsrestart_`/
   `vpscancel` phải quay về đúng bot).

### WP5 — Gắn error workflow

Chuẩn bị lúc 2h (chỉ lập danh sách + test), thực hiện lúc cutover:

- Trỏ `settings.errorWorkflow` sang `GW Error Handler v2` cho: Gateway, Live Update, Full Reconcile,
  Interview Evaluation (đang dùng v1).
- Thêm mới cho: Admin System, ClickUp Reader, Bot Xử Lý Ảnh (đang không có).
- **Bỏ qua (D3):** Blacklist, TTLock, Rule Engine.
- Trước khi thực hiện: xác nhận `versionId == activeVersionId` của từng workflow (nếu khác → có bản
  nháp → không đụng, ghi lại).

## 7. Bộ test (unit test từ các lần test trước)

### 7.1 Phương pháp

| Mã | Phương pháp | Khi nào dùng | Tác động thật |
|---|---|---|---|
| **PIN** | `prepare_workflow_pin_data` + `test_workflow`, pin mọi node có tác động ngoài (mục 5.3) | Logic định tuyến, IF/Switch/Code | Không |
| **DIFF** | Chạy PIN trên cả v1 và v2 với cùng input, so sánh output từng node logic | Kiểm tra parity v1↔v2 | Không |
| **REAL** | Workflow TEMP gọi dịch vụ thật chỉ-đọc/chi phí nhỏ, thay mọi node gửi tin/ghi bằng node Set "ghi lại" | Luồng dữ liệu (binary, text giữa các node) | Chỉ đọc |
| **PROD-FAIL** | Workflow TEMP có Webhook trigger, active, cố ý lỗi, `errorWorkflow` = handler cần test, gọi bằng `execute_workflow` mode `production` | Error handler | Ghi `error_logs` + ≤1 tin vào topic lỗi admin |
| **STATIC** | jq/script trên JSON workflow | Clone parity, credentials, settings, tham chiếu | Không |
| **MANUAL** | Cần người thật | Cutover, restart container thật | Có — làm khi có người trực |

### 7.2 Bộ hồi quy từ các sự cố đã gặp (REG — chạy trên production hiện tại, chỉ đọc)

| ID | Nguồn (sự cố) | Workflow | Cách test | Input | Kết quả mong muốn |
|---|---|---|---|---|---|
| REG-OCR-01 | Mất binary sau bước ack (24/09, exec `7931`, `7540`) | Bot Xử Lý Ảnh | REAL: Telegram getFile `file_id` của exec `7931` → Code `Đính Kèm Lại Ảnh` (logic y hệt prod) → extractFromFile | `file_id` từ exec 7931 | `data` tồn tại, độ dài > 50.000 ký tự |
| REG-OCR-02 | Mất text tóm tắt sau Delete Ack (24/09, exec `8000`, `8016`) | Bot Xử Lý Ảnh | STATIC: `Gửi Bản Tóm Tắt.parameters.text` tham chiếu `$('Tóm Tắt Bằng AI')`, không phải `$json` | JSON prod | Tham chiếu tường minh |
| REG-OCR-03 | Thứ tự tin chờ (23/09) | Bot Xử Lý Ảnh | STATIC trên connections + đọc runData exec thành công gần nhất (`8086`) | exec 8086 | `Send Processing Ack.startTime` < `Call Qwen OCR.startTime`; `Delete Processing Ack (OK)` chạy trước `Gửi Bản Tóm Tắt` |
| REG-OCR-04 | Nhánh OCR lỗi (22/09) | Bot Xử Lý Ảnh | PIN: pin `Call Qwen OCR` ra output lỗi (output index 1) | 1 envelope `/tomtat` có ảnh | Chạy `Delete Processing Ack (Failed)` → `Reply OCR Failed`; không chạy `Tóm Tắt Bằng AI` |
| REG-OCR-05 | LangChain chỉ xử lý 1 item (RULES #30) | — (quy tắc harness) | Mọi test có node LangChain chạy 1 item/lần | — | Số item ra = số item vào |
| REG-VPS-01 | `/vps` (23/09) | Admin System | PIN: pin `Call VPS Info` bằng output thật (có `id` container) | `/vps` từ chat admin | Text có `?start=vpsc_<12 hex>` cho mỗi container |
| REG-VPS-02 | Chi tiết container | Admin System | PIN | callback/deeplink `vpsc_0b13df56a8c2` từ admin | Tới `Send Container Detail`; nút `vpsrestart_0b13df56a8c2` + `vpscancel` |
| REG-VPS-03 | id không tồn tại | Admin System | PIN: pin `Call Container Info` = `{"error":"not_found"}` | `vpsc_ffffffffffff` | Tới `Reply Container Info Failed` |
| REG-VPS-04 | Không phải admin | Admin System | PIN | `/vps` từ chat khác admin | Tới `Reply Không Có Quyền (VPS)`, không gọi `Call VPS Info` |
| REG-VPS-05 | Huỷ | Admin System | PIN | callback `vpscancel` | Tới `Reply VPS Cancelled` |
| REG-VPS-06 | Restart thật (chưa từng test thật) | Admin System | MANUAL (CN, container `portainer-portainer-1` / `016d6fddd3b2`) | — | Tin `✅ Đã khởi động lại container portainer-portainer-1` |
| REG-LU-01 | `⚙️ Config (Admin Chat ID)` có retry (23/09) | Live Update | STATIC | JSON prod | `retryOnFail: true, maxTries: 5, waitBetweenTries: 5000` |

### 7.3 Test cho WP3 (Gateway v2) — tất cả chạy DIFF (v1 vs v2) trừ khi ghi khác

Input lấy từ `corpus/gateway/`. Mọi test: pin `Telegram Trigger Gateway` = update; pin
`GW-02 Auth Lookup` = trạng thái user mong muốn; pin `GW-04 Check Pending Upload` = 0 dòng hoặc 1 dòng;
pin mọi node Telegram/Postgres ghi/`executeWorkflow`.

| ID | Nguồn | Input | Kết quả mong muốn (cả v1 và v2) |
|---|---|---|---|
| GW-01 | COMMAND_MAP | `/task abc` (user active, có `telebot_main`) | `GW-03 Router` ra `route=telebot_main`; chạy `→ Sub: Telebot ClickUp Reader` |
| GW-02 | COMMAND_MAP | `/tomtat` + ảnh (có `image_bot`) | `route=image_bot`; chạy `→ Sub: Image Bot` |
| GW-03 | COMMAND_MAP | `/xoanen` + ảnh | `route=image_bot` |
| GW-04 | Deep-link TTLock (15/09) | `/start mokhoa_sel_<id>` (có `lock_bot`) | `route=lock_bot` (không phải `telebot_main`) |
| GW-05 | Quyền lock (15/09) | `/mokhoa` trong chat `-5535257695`, user chưa có `lock_bot` | `route=lock_no_permission`; chạy cả `Không có quyền bot này` và `Báo Admin Cấp Quyền Lock` |
| GW-06 | Quyền | `/mokhoa` ở chat khác, chưa có quyền | `route=no_permission` |
| GW-07 | Callback prefix (RULES #1, 09/09) | callback `odhelp_123` | `route=telebot_main` (startsWith, không phải ===) |
| GW-08 | Callback prefix | callback `odfwd_123`, `od_x`, `chitiet_x`, `ulchs_x` | `route=telebot_main` |
| GW-09 | Callback prefix | callback `imgai_5`, `imgupscale_5`, `imgcancel` | `route=image_bot` |
| GW-10 | Callback prefix (23 RULES, 15/09) | callback `lockap:1`, `lockdn:1`, `lockgrant:1` | `route=lock_bot` |
| GW-11 | Callback không rõ | callback `xyz_1` | `bot_key=help_bot` (DEFAULT_BOT) — giữ nguyên hành vi v1 |
| GW-12 | Pending upload (RULES #18, sự cố 16/09) | `/task` khi GW-04 trả 0 dòng | Router VẪN chạy, `pendingUpload=null` |
| GW-13 | Pending upload (RULES #19, sự cố 16/09) | tin text thường khi GW-04 trả 1 dòng có `task_prefix` | `route=telebot_main`; `pendingUpload.task_prefix` có giá trị |
| GW-14 | Auth `new` | user chưa có trong DB | chạy `Tạo pending user` → `Báo user chờ duyệt` + `Báo admin duyệt user`; v2 KHÔNG còn `Tạo pending user (Supabase)` (khác biệt cho phép) |
| GW-15 | Auth `pending` / `denied` | — | `Nhắc đang chờ duyệt` / `Thông báo từ chối` |
| GW-16 | Tin nhóm không lệnh + `@@nhom` | text nhóm có `@@abc` | Chạy `Ghi Log Tin Nhắn Nhóm` + `Trigger Mention Resolver (Gateway)`; KHÔNG chạy auth/router |
| GW-17 | Lệnh lạ | `/abcxyz` | `route=unknown` → `Hướng dẫn lệnh` |
| GW-18 | Callback duyệt từ non-admin | callback `ap:1:ALL` từ user thường | `Bỏ qua (không phải admin)` |
| GW-19 | Audit log | bất kỳ | v1: 2 node audit chạy; v2: đúng 1 node `Audit Log (Docker)` chạy (khác biệt cho phép) |
| GW-20 | Config là Set node | bất kỳ | `$('⚙️ Config').first().json.COMMAND_MAP` là object, `AVAILABLE_BOTS` là array (ghi kiểu thực tế vào báo cáo) |
| GW-P1 | Hiệu năng | 20 input của GW-01/02/07 | Ghi p50 thời gian chạy v1 và v2 (PIN nên chỉ đo phần logic; ghi rõ giới hạn này) |
| GW-S1 | Clone parity | STATIC | Ngoài C1–C4, JSON v2 == v1 (node, params, credentials, settings, connections) |

### 7.4 Test cho WP1 (Error Handler v2) — PROD-FAIL

Harness: workflow TEMP `TEMP - Cố Ý Lỗi (xoá sau khi dùng)`, Webhook trigger → Code `throw new Error('TEST WP1 ' + $json.body.n)`,
settings `errorWorkflow = <id Error Handler v2>`, publish, gọi bằng `execute_workflow` mode `production`.

| ID | Input | Kết quả mong muốn |
|---|---|---|
| ERR-01 | 1 lần gọi | Handler v2: 1 execution `success`; `gateway.error_logs` +1 dòng đúng workflow/node; đúng 1 tin vào topic lỗi |
| ERR-02 | 20 lần gọi liên tiếp nhanh nhất có thể (burst) | 20 dòng `error_logs`; ≤1 tin Telegram mỗi phút; 0 execution handler lỗi; `suppressed_count` = số lần bị gộp |
| ERR-03 | Handler không có Code node | STATIC: không có node `n8n-nodes-base.code` |
| ERR-04 | Thứ tự | Trong runData: node Postgres chạy trước node Telegram |
| ERR-06 | DB lỗi vẫn báo (thêm 25/09) | PIN trên handler v2: pin `Ghi Lỗi + Kiểm Tra Gộp` = `{"error":"connection refused"}` (không có `log_id`), pin `Báo admin Telegram` | IF ra nhánh true; `Báo admin Telegram` có trong runData với text đúng từ `Chuẩn Hoá Lỗi` |
| ERR-07 | Message có dấu phẩy/nháy (thêm 25/09) | Trong ERR-01, gọi với `n` = `a, b 'c' "d"` | Dòng `error_logs` có `error_message` nguyên vẹn, 6 cột đúng vị trí |
| ERR-05 | Sub-workflow lỗi có kích hoạt error workflow không (giả định của WP5) | Harness thứ 2: Webhook → Execute Workflow (wait=false) → sub TEMP có `errorWorkflow = v2` và cố ý lỗi | Handler v2 nhận lỗi của sub (ghi rõ CÓ/KHÔNG — nếu KHÔNG, WP5 phải điều chỉnh) |

Dọn dẹp: sau test, unpublish + archive harness; xoá dòng test khỏi `error_logs`? **Không** (cấm DELETE —
mục 5.2); thay vào đó ghi lại `id` các dòng test vào TEST_REPORT để lọc khi xem báo cáo.

### 7.5 Test cho WP2

| ID | Cách test | Kết quả mong muốn |
|---|---|---|
| MIG-01 | STATIC | Query chỉ chứa lệnh được phép (mục 5.2); các khối copy khớp từng ký tự với node gốc |
| MIG-02 | Chạy lần 1 | `success` |
| MIG-03 | Chạy lần 2 | `success` (idempotent) |
| MIG-04 | SQL chỉ-đọc `information_schema` | Bảng `gateway.error_alert_throttle` + các cột của các node Ensure tồn tại |

### 7.6 Test cho WP4 (pilot)

| ID | Cách test | Input (envelope pin vào trigger của sub) | Kết quả mong muốn |
|---|---|---|---|
| ADM-01..05 | PIN | route `vps`, `vps_container`, `vps_restart`, `vps_cancel`, chat admin | Như REG-VPS-01..05 (cùng node đích, cùng text/nút) |
| ADM-06 | PIN | route `vps`, chat KHÔNG phải admin | Nhánh không có quyền; không gọi HTTP |
| ADM-07 | PIN | route `token`, `version`, `error_logs`, `error_log_now` từ admin | Tới đúng node gửi tương ứng như v1 |
| ADM-08 | STATIC | JSON sub-workflow | Không còn tham chiếu `$('Phân tích lệnh')` hay `$('⚙️ Config')`; mọi Telegram dùng `Telegram System Bot` |

### 7.7 Mẫu báo cáo tester (`TEST_REPORT.md`)

Mỗi test 1 dòng; "Kết quả thực tế" phải trích nguyên giá trị từ runData/SQL, không diễn giải:

| ID | WP | Phiên bản | Cách test | Input | Kết quả mong muốn | Kết quả thực tế (trích) | Execution / workflow TEMP | Kết quả |
|---|---|---|---|---|---|---|---|---|
| GW-07 | WP3 | v1 | DIFF | callback `odhelp_123` | `route=telebot_main` | `"route":"telebot_main"` | exec 9xxx | ✅ PASS |
| GW-07 | WP3 | v2 | DIFF | callback `odhelp_123` | `route=telebot_main` | `"route":"telebot_main"` | exec 9xxx | ✅ PASS |

Cuối báo cáo: tổng số PASS/FAIL/PENDING theo WP; danh sách workflow TEMP đã tạo + xác nhận đã archive.

## 8. Runbook cutover — Chủ nhật 27/09/2026, 19:00–22:00 giờ VN (có người trực)

**Điều kiện:** WP tương ứng "READY FOR CUTOVER"; user đã chạy lệnh ở mục 10 (task runner).

1. **WP1 + WP5 (error handler):**
   1. Publish `GW Error Handler v2`.
   2. Lần lượt đổi `errorWorkflow` các workflow ở WP5 → v2 (mỗi workflow: kiểm `versionId ==
      activeVersionId` → `setWorkflowSettings` → `publish_workflow`).
   3. Smoke: chạy lại ERR-01 bằng harness → thấy 1 tin ở topic lỗi.
   4. **Rollback:** đổi `errorWorkflow` về `34ccboHpyoY2r691`, publish.
2. **WP3 (Gateway):**
   1. Ghi `activeVersionId` hiện tại của v1.
   2. `unpublish_workflow` v1 → `publish_workflow` v2 (Telegram trigger đăng ký lại webhook cho bot
      Elite Clickupbot). Khoảng trống giữa 2 bước < 10 giây.
   3. Smoke (admin tự gõ từ tài khoản của mình): `/task <từ khoá>`, `/tomtat` + ảnh, bấm 1 nút có sẵn
      từ tin cũ (vd `chitiet_`), `/mokhoa` ở chat riêng (mong đợi: báo chưa có quyền hoặc danh sách).
   4. Theo dõi 30 phút: `search_workflow_executions` cho v2 — 0 lỗi; p50 ≤ p50 v1.
   5. **Rollback (bất kỳ lỗi nào trong 30 phút / người dùng báo):** `unpublish_workflow` v2 →
      `publish_workflow` v1. Không cần sửa gì khác (sub-workflow không đổi).
3. Sau cutover: đổi tên v1 thành `... (v1 - RETIRED 27/09)`, giữ 14 ngày rồi mới archive.

## 9. Nhật ký lượt chạy + câu hỏi chờ user

_(Architect ghi sau mỗi WP: thời gian, kết quả, link tới BUILD_LOG/AUDIT_REPORT/TEST_REPORT, và mọi
⛔ kèm câu hỏi cần user trả lời.)_

### Đêm 1 — T6 25/09/2026

- **Ghi chú khởi động:** lượt chạy `refactor-w39-night-build` bắt đầu muộn lúc **08:24** (không phải
  02:05 — có thể máy ngủ/app đóng). Hệ quả: WP4 đã quá time-box 06:00 → không làm (dời sang đêm 2).
  WP2 (DDL additive) chạy trong giờ có traffic: chấp nhận vì mọi câu DDL copy nguyên văn đang chạy ở
  MỖI request production (F6) + 1 bảng mới — rủi ro khoá bằng hành vi hiện tại.
- **08:35 WP0 ✅** — folder staging `ZdlLC9utIKkjLvhv`. 8 workflow production khớp mốc rollback mục 3
  (không có bản nháp). Bổ sung: Full Reconcile `92611b33-57df-463c-910e-b00c24144dd9`, Interview
  Evaluation `7199e254-a3ab-4b8a-a523-768a7b51e468`. TTLock có bản nháp (versionId ≠ activeVersionId) —
  đúng D3. Corpus: 19 gateway (9 thật / 10 synthetic), 7 admin (5 thật / 2 synthetic), đã gitignore.
  Lưu ý: toàn bộ test callback GW-07..11, GW-18 chạy trên dữ liệu synthetic (không có callback thật
  cho các prefix này). Chi tiết: [BUILD_LOG.md](./BUILD_LOG.md).
- **08:53 WP2 build + audit ✅** — `DB Migrations (chạy tay) (STAGING)` `8XLg2q34VQq6IDx7`
  (versionId `76f2cb7e-22d8-4a29-81da-e234b69a7825`). Quyết định Architect: bỏ câu
  `INSERT INTO gateway.ttlock_auth ... ON CONFLICT DO NOTHING` của khối TTLock (không thuộc whitelist 5.2;
  TTLock production vẫn tự seed). Audit #1 PASS: 22 câu, toàn bộ IF NOT EXISTS. Risk note auditor: cả
  batch chạy trong 1 transaction → giữ khoá ACCESS EXCLUSIVE tới cuối → **dời MIG-02/03 ra sau 10:00**
  và kiểm tra `pg_stat_activity` trước khi chạy.
  ❓ **Câu hỏi cho user:** khi bỏ node `Ensure Schema (Lock)` khỏi TTLock sau này, seed
  `ttlock_auth(id=1)` nên chuyển đi đâu (migration riêng có INSERT, hay giữ trong TTLock)?
- **~09:20 REG ✅** — 12/12 PASS, 1 PENDING (REG-VPS-06 MANUAL, CN). Vòng 1 (haiku) không dựng được
  harness → vòng 2 giao tester chạy bằng model sonnet (quyết định Architect). REG-OCR-01 REAL: `data`
  100.840 ký tự (exec 9248). 3 TEMP đã archive. Production không đổi. Bài học cho các test sau:
  **pin data không chọn được output index** của node nhiều output → nhánh lỗi phải test bằng TEMP tái
  hiện connection (như REG-OCR-04). Chi tiết: [TEST_REPORT.md](./TEST_REPORT.md).
- **~09:05 WP1 build + audit ✅ (sau 1 vòng sửa)** — `GW Error Handler v2 (STAGING)` `MaoEB8w8Un6UA01n`
  (versionId `4f7d5a4b-c6e3-436a-be87-b85793b039bf`). Audit #1 FAIL: DB lỗi → IF false → mất cảnh báo
  (regression so với v1). Architect sửa spec bước 4 (điều kiện `should_alert === true || !log_id`), thêm
  ERR-06 (DB lỗi vẫn báo) + ERR-07 (message có dấu phẩy/nháy). Audit #2 PASS. Lưu ý: builder gặp
  auto-assign credential sai khi tạo (Postgres→Supabase, Telegram→bot khác) — đã sửa và xác nhận lại.
  Test chờ WP2 tạo bảng throttle.
- **~09:19 WP3 build + audit ✅** — `GW Gateway - Telegram v2 (STAGING)` `hn0YZ85sXtfGACJ4` (versionId
  `dbc644d4-7c8a-44e5-90dd-ec18b9aab157`). Clone khớp 100% 48 node trước C1–C4; diff cuối chỉ đúng C1–C4.
  Audit #1 PASS (mô phỏng Router cũ/mới 25 case giống hệt). Việc cho user trước cutover: vào UI đặt
  `binaryMode`/`timeSavedMode` của v2 giống v1 (MCP không set được; không ảnh hưởng hành vi Gateway).
  Test DIFF đang chạy.
- **09:2x–13:20 gián đoạn** — phiên hết quota (rate limit), tester WP3 bị ngắt giữa chừng, chưa ghi gì.
  Tiếp tục lúc 13:21; tester WP3 được giao lại từ đầu.
- **13:22 WP2 ⛔ BLOCKED (chạy migration)** — lệnh giao tester chạy `8XLg2q34VQq6IDx7` bị safety
  classifier của Claude Code chặn (lý do: "Production Deploy"). Không lách. Hệ quả: WP1 chỉ test được
  phần STATIC/PIN (ERR-03, ERR-04 tĩnh, ERR-06); ERR-01/02/04/05/07 PENDING vì cần bảng throttle.
  ❓ **Câu hỏi cho user (cần trước đêm 2 / trước CN):** chọn 1 —
  (a) tự bấm "Execute workflow" `DB Migrations (chạy tay) (STAGING)` trong n8n UI 2 lần (MIG-02/03),
      rồi để đêm 2 kiểm MIG-04 + chạy test WP1; hoặc
  (b) cấp quyền cho lượt đêm 2 chạy migration (thêm rule cho phép trong settings Claude Code); hoặc
  (c) dời migration vào khung cutover CN có người trực.
  Nên chạy ngoài giờ cao điểm (auditor: batch giữ khoá ACCESS EXCLUSIVE tới cuối transaction).
- **~13:30 WP1 test phần 1** — 5 PASS / 0 FAIL: ERR-03, ERR-04 (tĩnh), ERR-06 (exec 9507 — DB lỗi vẫn
  báo), ERR-06b/06c (gộp đúng). 5 PENDING chờ WP2: ERR-01, ERR-02, ERR-04 runtime, ERR-05, ERR-07.
  WP1 **chưa** READY FOR CUTOVER.
- **~13:40 WP5 danh sách ✅ (READY-LIST)** — 7 workflow đích không có bản nháp; settings hiện tại ghi đủ
  trong AUDIT_REPORT để so khi cutover. Handler v2 phải publish trước khi trỏ errorWorkflow. Lưu ý:
  `setWorkflowSettings` tạo version mới → phải publish lại từng workflow (đăng ký lại trigger). ERR-05
  chưa test (chờ WP2).
- **~14:00 WP3 test ✅ → READY FOR CUTOVER** — DIFF v1↔v2: 47/47 dòng PASS, 0 FAIL (2 lượt tester độc
  lập — lượt bị ngắt do rate limit đã tự chạy tiếp — cùng kết luận). GW-S1 chỉ khác C1–C4. GW-20:
  COMMAND_MAP object, AVAILABLE_BOTS array ở cả 2 bản. GW-P1 (PIN, chỉ logic, 5–9 lần): p50 v1 ≈ 101–103ms,
  v2 ≈ 81–82ms. Không có TEMP nào. v1/v2 không đổi version.
  ❓ **Câu hỏi cho user:** GW-13 — tin text thường trong **nhóm** (không lệnh) không bao giờ tới Router ở
  CẢ v1 và v2 (bị chặn ở `Cần Auth/Routing?`), nên pending upload chỉ hoạt động trong chat riêng hoặc khi
  có lệnh. Đây có phải hành vi mong muốn không? (parity giữ nguyên; bản chat riêng GW-13b PASS.)
- **Xác nhận cuối lượt:** workflow migration `8XLg2q34VQq6IDx7` có 0 execution (không có gì chạm
  production DB). Production mục 3 không đổi version (kiểm bởi auditor WP5 + tester WP3).

### Trả lời của user — 25/09/2026 ~16:40 (Architect đã kiểm chứng những gì kiểm được)

1. **WP2 migration** — user tự chạy tay trong n8n UI.
   > Trả lời: đã chạy, báo success.
   Kiểm chứng: exec `9795` (manual, 25/09 16:32:54 VN), status `success`, node `Chạy Toàn Bộ DDL
   Migrations` trả `{"success":true}` sau 129ms. **Mới chạy 1 lần** → MIG-02 ✅; MIG-03 (chạy lần 2,
   idempotent) và MIG-04 (kiểm schema) còn lại cho đêm 2. ERR-01/02/04/05/07 của WP1 hết bị chặn.
2. **GW-13** — > Trả lời: đúng ý. Upload chỉ khi được phép; tin nhắn thường trong nhóm chỉ lưu lại cho
   chức năng chat summary có sẵn. → Hành vi v1 = v2 là ĐÚNG. Sửa kỳ vọng GW-13 thành "tin nhóm không
   lệnh không tới Router; chỉ ghi log"; GW-13b (chat riêng + pending) là test pending-upload chính.
3. **TTLock / seed `ttlock_auth`** — > Trả lời: không đụng TTLock (đang ổn định), giữ nguyên như hiện
   tại, đảm bảo sau refactor vẫn hoạt động tốt. → Không bỏ `Ensure Schema (Lock)`, không làm TTLock v2.
   Điều kiện "vẫn chạy tốt" sau cutover Gateway: GW-04/GW-05/GW-10 (route `lock_bot`, quyền lock,
   callback `lockap:`/`lockdn:`/`lockgrant:`) đã PASS parity v1↔v2; smoke CN thêm 1 lệnh `/mokhoa`.
4. **Task runner (mục 10.1)** — > Trả lời: đã chạy sáng nay.
   Kiểm chứng gián tiếp (không SSH được): từ 00:00 VN 25/09 tới 16:36 **0 execution error/crashed** trên
   toàn instance; Live Update ≥100 execution, tất cả success (trước đây 16% lỗi do runner). Giá trị
   `N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT=0` chưa đọc trực tiếp được.
5. **D3 (mục 10.2)** — trạng thái hiện tại: chỉ TTLock còn bản nháp chưa publish (versionId
   `84e951d2-…`, tên "TẠM THỜI tắt giới hạn khung giờ mở khóa"); Blacklist + Rule Engine không còn nháp.
   Refactor không publish/đổi settings 3 workflow này. Không cần user làm gì cho cutover.
6. **binaryMode/timeSavedMode** — việc tuỳ chọn trước cutover (không ảnh hưởng hành vi Gateway).

#### Tóm tắt đêm 1

| WP | Kết quả |
|---|---|
| WP0 | ✅ |
| REG | ✅ 12/12 PASS, 1 MANUAL (REG-VPS-06, CN) |
| WP2 | build+audit ✅, **chạy migration ⛔** (classifier chặn) — chờ user chọn (a)/(b)/(c) ở trên |
| WP1 | build+audit ✅ (1 vòng sửa), test 5 PASS / 5 PENDING (chờ WP2) — chưa READY |
| WP3 | ✅ **READY FOR CUTOVER** (47/47 PASS) |
| WP4 | ⏭ chưa làm — lượt chạy bắt đầu 08:24, quá time-box 06:00 → đêm 2 |
| WP5 | danh sách ✅; ERR-05 chờ WP2 |

**Việc cho đêm 2:** (1) nếu user đã chạy/cho phép migration → MIG-04 + ERR-01/02/04/05/07; (2) WP4 pilot;
(3) kiểm lại production không đổi version. **Cần user trả lời trước CN:** migration WP2 (a/b/c), GW-13,
seed `ttlock_auth`, + mục 10 (task runner, D3). Trước cutover: đặt `binaryMode`/`timeSavedMode` của
Gateway v2 trong UI giống v1.

- **~13:45 WP3 test** — DIFF v1↔v2: 0 FAIL, không khác biệt ngoài C1–C4 (TEST_REPORT section WP3
  06:30Z). GW-P1 (9 lần/bản, PIN chỉ đo logic): p50 v1 101ms → v2 81ms. GW-S1 khớp audit.
  ⚠️ **GW-13 chưa đạt mục đích**: corpus dùng tin NHÓM không lệnh → bị chặn ở `Cần Auth/Routing?` trước
  Router ở cả v1 và v2 (parity OK nhưng không kiểm được `pendingUpload.task_prefix` — đúng đường C4 sửa).
  Đêm 2 phải chạy lại GW-13 với tin text thường ở CHAT RIÊNG + GW-04 pin 1 dòng có `task_prefix`.
  WP3 **chưa READY** cho tới khi GW-13 PASS.
- **Tổng kết đêm 1 (Architect phiên 7fd3b1):** WP0 ✅, REG ✅ (12/12), WP1 audit ✅ + test 5 PASS / còn
  PENDING chờ WP2, WP2 ⛔ (chạy migration bị classifier chặn — chờ user), WP3 audit ✅ + test 0 FAIL / còn
  GW-13, WP4 không làm (quá 06:00). ⚠️ Ghi chú vận hành: từ ~13:23 có **một phiên Architect khác ghi song
  song** vào PLAN.md và commit (240e820, b7707ce, 90f5d5b — không phải phiên này), gây trùng mục nhật ký
  và chạy test WP1 hai lần. Phiên này dừng giao việc mới từ 13:27 để tránh xung đột. User nên kiểm tra
  Scheduled tasks xem task có chạy 2 lần không.

### Trả lời của user — 25/09/2026 ~17:40

1. Máy + app Claude desktop để bật cho lượt đêm 2.
2. **MIG-03** — user chạy lần 2. Kiểm chứng: exec `9880` (manual, 25/09 17:34:14 VN), `success`, 100ms
   → idempotent ✅. Đêm 2 chỉ còn MIG-04 (kiểm `information_schema`, chỉ đọc).
3. **Scheduled tasks** — chỉ có 2 task còn lại (đêm 2 + CN); không có bản trùng của night-build. Phiên
   Architect ghi song song lúc 13:23–13:43 vì vậy không phải task chạy 2 lần (nhiều khả năng là phiên
   bị nối lại sau rate limit). Đêm 2: pull trước mỗi lần ghi PLAN.md, dừng nếu thấy commit lạ < 5 phút.
4. **binaryMode/timeSavedMode** — BỎ khỏi checklist. Giá trị v1 là `binaryMode:"separate"` (mặc định
   của n8n, không có ô chỉnh trong UI) và `timeSavedMode:"fixed"` (chỉ dùng cho thống kê Insights "thời
   gian tiết kiệm"). Gateway không có node binary → không ảnh hưởng gì. Không cần user làm.
5. Cutover để CN làm, đúng mục 8.

### Đêm 2 — T7 26/09/2026 (task `refactor-w39-night-continue`, bắt đầu 02:05 đúng lịch)

- **02:10 Bước 1 — production không đổi.** `get_workflow_details` 8 workflow mục 3: tất cả
  `versionId == activeVersionId` và khớp mốc WP0 (Gateway `180005b7…`, Admin `53d44baa…`, Ảnh `435af575…`,
  Live Update `42cfa99b…`, Reader `4437fece…`, Error Handler `1a6b1d2a…`, Reconcile `92611b33…`, Interview
  `7199e254…`). → Không cần clone lại v2 nào.
- **02:1x WP1 PROD-FAIL ⛔ BLOCKED.** Lệnh giao tester chạy ERR-01/02/04 runtime/05/07 (publish harness TEMP
  có webhook, ghi `gateway.error_logs` thật, gửi ≤2 tin vào topic lỗi admin, publish tạm handler v2 nếu cần)
  bị safety classifier của Claude Code chặn — lý do "Modify Shared Resources". Không lách. WP1 giữ 5/10 PASS
  (STATIC + PIN), WP5 (ERR-05) cũng bị chặn theo.
  ❓ **Câu hỏi cho user (cần trước CN 19:00):** chọn 1 —
  (a) **Khuyến nghị:** chạy ERR-01/02/05/07 trong khung cutover CN có người trực, NGAY SAU bước 8.1.1
      (publish handler v2) và TRƯỚC khi trỏ errorWorkflow của 7 workflow. Nếu ERR nào FAIL → dừng WP1/WP5,
      giữ `34ccboHpyoY2r691`, chỉ cutover WP3. Câu hỏi "handler chưa publish có chạy không" không còn quan
      trọng vì runbook publish trước.
  (b) Thêm rule cho phép trong settings Claude Code để task `refactor-w39-cutover-prep` (CN 18:00) chạy
      PROD-FAIL trước giờ cutover.
  (c) Không cutover WP1/WP5 tuần này; chỉ cutover WP3.
  > Trả lời:
- **02:17 WP2 ✅** — MIG-04 PASS: 26/26 object tồn tại (7 bảng, 17 cột, index throttle; bảng throttle
  đúng 3 cột). TEMP `0eLYv0f67eziX8R7` đã archive. WP2 hoàn tất.
- **02:30 WP4 build ✅** — `Admin v2 - Hệ thống (STAGING)` `bauK573MU18oRzKP` (versionId
  `4851cb58-ede4-4fb8-b323-3dadad9d2b82`, inactive). 33 node: 28 copy nguyên văn + 5 mới (trigger
  passthrough, `Là vps_cancel?` trước cổng admin để giữ parity REG-VPS-05, 1 cổng `Là Admin?` thay 5
  `Check Admin (...)`, Switch `Route` 7 nhánh thay luôn `Route VPS Extra`, `Là Lỗi Route?` chọn text không
  quyền). 15 tham chiếu `Phân tích lệnh`/`⚙️ Config` → `Execute Workflow Trigger`, 0 tham chiếu treo.
- **02:36 WP4 audit #1 PASS** (0 blocking). Risk notes: contract phải ghi `chatId`/`ADMIN_CHAT_ID` là
  **string** (IF strict — truyền number sẽ lỗi thay vì ra false); router v2 sau này phải tự giữ phần xử lý
  callback đứng trước `Phân tích lệnh` của v1.
- **02:47 WP4 test ✅ 23/23** (ADM-01..09; `Call Container Restart` pinned, 0 docker restart thật). Text/nút v2
  khớp v1 từng ký tự. 0 TEMP. → **Pilot đạt**, contract router↔sub-workflow được chứng minh. Chưa làm router v2,
  không cutover (đúng D6).
- **02:4x Bước 3 — test lại toàn bộ ✅** — WP3 47/47 PASS (GW-13 theo kỳ vọng mới của user, GW-13b pending
  upload OK; GW-P1 p50 v1 107ms / v2 74ms, PIN chỉ đo logic), REG 11/11 PASS + VPS-06 MANUAL. 0 test PASS→FAIL.
  TEMP `ECH0aKo9CXgCD5UE`, `80821vva7xGpyd6l` đã archive. Production + v1/v2 không đổi version cuối bài.
- Ghi chú: 2 tester ghi nhầm ngày UTC trong tiêu đề TEST_REPORT (26/09 thay vì 25/09) — Architect đã sửa.
  Bài học lặp lại: tạo TEMP có node Telegram bị auto-assign nhầm `@csfsintbot` — tester đã sửa trước khi chạy.

#### Tóm tắt đêm 2

| WP | Kết quả | Cutover CN 27/09 |
|---|---|---|
| WP2 | ✅ xong (MIG-01..04) | — (đã chạy) |
| WP3 | ✅ READY FOR CUTOVER (test lại 47/47) | ✅ theo mục 8.2 |
| WP4 | ✅ pilot đạt 23/23 (staging) | Không (tuần sau: router v2) |
| WP1 | ⛔ 5/10, PROD-FAIL bị classifier chặn | Chỉ nếu user chọn (a)/(b) và ERR PASS |
| WP5 | ⛔ phụ thuộc WP1 + ERR-05 | như WP1 |
| REG | ✅ 11/11 + VPS-06 MANUAL (CN) | smoke VPS-06 nếu muốn |

## 10. Việc user cần làm trước cutover

1. Áp dụng fix task runner (F4) — agent không chạy được do safety classifier:
   ```bash
   ssh root@72.61.126.64
   cd /docker/n8n_stack && docker compose up -d task-runners
   docker exec n8n_stack-task-runners-1 printenv N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT   # phải ra 0
   ```
2. Xác nhận với "chủ" của Blacklist Bot / Rule Engine / TTLock về bản nháp chưa publish (D3), và về
   việc chặn Rule Engine chạy chồng (F3).
3. Quyết định sau cutover (không làm trong cuối tuần này): F7 (DEFAULT_BOT), F8 (Supabase mirror),
   F13 (dọn node chết + help text), F16 (không lưu execution thành công cho workflow poll).

## 11. Lịch tự động (Claude desktop → Scheduled)

| Task ID | Chạy lúc (giờ VN) | Việc |
|---|---|---|
| `refactor-w39-night-build` | T6 25/09 02:05 | Đêm 1: WP0 → REG → WP2 → WP1 → WP3 → WP4, chỉ staging |
| `refactor-w39-night-continue` | T7 26/09 02:05 | Đêm 2: kiểm production có đổi không, làm nốt WP dở, test lại toàn bộ |
| `refactor-w39-cutover-prep` | CN 27/09 18:00 | Go/No-go + checklist cutover điền sẵn ID (chỉ đọc, không cutover) |

Điều kiện để lịch chạy được: app Claude desktop đang mở, máy không ngủ, và quyền của task đã được cấp
sẵn (nếu không, lượt chạy sẽ dừng chờ duyệt). Trả lời câu hỏi ⛔ ở mục 9 bằng cách ghi ngay dưới câu hỏi
(`> Trả lời: ...`) rồi commit — lượt đêm 2 sẽ đọc và làm tiếp.

Lệnh khởi động thủ công (nếu cần chạy lại ngoài lịch), dán vào phiên Claude Code mở trong repo `n8nwf`:

```
Bạn là Workflow Architect. Đọc bot-gateway/docs/refactor-2026w39/PLAN.md và bot-gateway/docs/RULES.md.
Thực hiện lượt chạy 2h sáng đúng mục 4 và mục 5 của PLAN: WP0 → REG → WP2 → WP1 → WP3 → WP4 (time-box
06:00). Với mỗi WP: giao builder (subagent_type "builder"), rồi auditor ("auditor"), rồi tester
("tester"); tối đa 2 vòng sửa. Không cutover, không đụng production ngoài WP2. Cập nhật mục 0 và mục 9
sau mỗi WP, commit + push các file báo cáo (trừ corpus/) khi xong.
```
