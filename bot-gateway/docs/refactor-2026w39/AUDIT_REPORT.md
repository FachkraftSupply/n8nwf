# AUDIT_REPORT — refactor 2026-W39

## WP2 — DB Migrations (chạy tay) — audit #1 — 2026-09-25T01:53:04Z
VERDICT: PASS

Đối tượng: `8XLg2q34VQq6IDx7` "DB Migrations (chạy tay) (STAGING)", `versionId` `76f2cb7e-22d8-4a29-81da-e234b69a7825` (khớp giá trị mong đợi). Mọi bằng chứng dưới đây lấy từ `get_workflow_details`/`get_workflow_version` đọc lại lúc audit, so bằng script Python (không dựa vào BUILD_LOG).

| Check | Result | Evidence (quoted from workflow JSON / tool output) |
|---|---|---|
| S1a Cấu trúc đúng spec | ✅ | `nodeCount: 2`; `Manual Trigger` (`n8n-nodes-base.manualTrigger` v1) → `Chạy Toàn Bộ DDL Migrations` (`n8n-nodes-base.postgres` v2.7, `"operation":"executeQuery"`, `"options":{}`); connection `"Manual Trigger":{"main":[[{"node":"Chạy Toàn Bộ DDL Migrations","type":"main","index":0}]]}` |
| S1b Copy nguyên văn 7 khối (MIG-01) | ✅ | Tách `query` theo dòng `-- [nguồn: …]` → 8 khối; ghép lại == query gốc (`reassembled == Q: True`). So ký tự từng khối (bỏ đúng dòng trắng ngăn cách) với `parameters.query` của node nguồn: 1 Gateway `Ensure Pending Uploads Table` (v`180005b7…`) MATCH · 2 Reader `Ensure Zalo Notify Column` MATCH · 3 Reader `Ensure Pending Upload Columns` MATCH · 4 Reader `Ensure Notify Queue Columns` MATCH (Reader v`4437fece…`) · 5 Admin `Ensure Sync Table` MATCH · 6 Admin `Ensure Mention Tables (Admin)` MATCH (Admin v`53d44baa…`) · 7 TTLock `Ensure Schema (Lock)` từ bản ACTIVE `f3062458-d905-421b-bf1b-82f4caab3255` qua `get_workflow_version` MATCH. Tiêu đề comment mỗi khối đúng `-- [nguồn: <tên workflow> / <tên node>]`. Không node nguồn nào có tham số `$1`/expression (`has_expr False`) |
| S1c Khác biệt cho phép duy nhất (TTLock INSERT) | ✅ | Khối 7 == nguồn sau khi thay đúng 1 chuỗi `INSERT INTO gateway.ttlock_auth (id) VALUES (1) ON CONFLICT (id) DO NOTHING;` (xuất hiện đúng 1 lần ở nguồn) bằng `-- [bỏ theo PLAN 5.2: INSERT seed ttlock_auth(id=1) vẫn do TTLock/Ensure Schema (Lock) tự chạy]`; không khác gì thêm |
| S1d Khối mới `gateway.error_alert_throttle` | ✅ | Thân khối 8 == nguyên văn SQL PLAN mục 6 WP2 bước 2 (bảng 3 cột `bucket_key TEXT PRIMARY KEY`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `suppressed_count INTEGER NOT NULL DEFAULT 0` + `CREATE INDEX IF NOT EXISTS idx_error_alert_throttle_created ON gateway.error_alert_throttle (created_at);`) — so chuỗi: MATCH |
| S1e Whitelist lệnh PLAN 5.2 | ✅ | Bỏ comment `--`, tách theo `;` → **22 câu, 0 vi phạm**: 7× `CREATE TABLE IF NOT EXISTS` (clickup.pending_uploads, clickup.sync_targets, gateway.mention_groups, gateway.mention_group_members, gateway.ttlock_auth, gateway.lock_unlock_requests, gateway.error_alert_throttle); 14× `ALTER TABLE <t> ADD COLUMN IF NOT EXISTS` (mỗi câu đúng 1 ADD, không dấu phẩy multi-action); 1× `CREATE INDEX IF NOT EXISTS`. Quét từ khoá DROP/TRUNCATE/DELETE/UPDATE/INSERT/RENAME/TYPE/ALTER COLUMN/SET/CONSTRAINT/GRANT/DO/COPY…: không có (ngoài `ON DELETE CASCADE` trong định nghĩa FK của bảng mới `mention_group_members` — hợp lệ vì CREATE TABLE IF NOT EXISTS). Không `/* */`, không `$$`, không expression `{{`, literal chỉ `'awaiting_choice'`, `'pending'` |
| S1f Thứ tự phụ thuộc | ✅ | `clickup.pending_uploads` CREATE (câu 1) trước 3 ALTER của nó (câu 3–5); `gateway.mention_groups` (câu 17) trước `mention_group_members … REFERENCES gateway.mention_groups(id)` (câu 18); bảng throttle trước index. Bảng chỉ ALTER mà không CREATE: `gateway.notify_targets`, `clickup.upload_notify_queue` — phải có sẵn (xem Risk notes). Không có `CREATE SCHEMA`; schema `gateway`/`clickup` phải có sẵn (production đang dùng) |
| S1g Workflow settings/vị trí | ✅ | `"active":false`, `"activeVersionId":null`, `"triggerCount":0`, `"parentFolderId":"ZdlLC9utIKkjLvhv"` = folder `"REFACTOR 2026-W39 (staging)"` (`search_folders`); `settings: {"executionOrder":"v1","availableInMCP":true}` — không `errorWorkflow` (spec không bắt buộc); chưa từng chạy: `search_workflow_executions` → `{"data":[],"count":0}` |
| S2 Production không đổi | ✅ | Đọc lại lúc audit — `activeVersionId` khớp BUILD_LOG WP0: Gateway `180005b7-a44a-4c95-ace6-24529ae46566`, Admin `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f`, Ảnh `435af575-e17f-488e-b616-20798790bbdf`, Live Update `42cfa99b-6659-47dd-8a84-f9fa4e977739`, Reader `4437fece-36da-4ccc-82fa-16e5330c7960`, Error Handler `1a6b1d2a-2ff8-4cf0-ae59-9ae3e978a183`, Full Reconcile `92611b33-57df-463c-910e-b00c24144dd9`, Interview Eval `7199e254-a3ab-4b8a-a523-768a7b51e468`; tất cả `versionId == activeVersionId`, `active:true`. D3: Blacklist `72efa72b…`/`72efa72b…`, TTLock `versionId 84e951d2…` / `activeVersionId f3062458…` (bản nháp giữ nguyên như WP0), Rule Engine `9905e164…`/`9905e164…` — không đổi |
| R2 `$json` trần | — | Không có expression nào trong workflow |
| R13 IF/Switch | — | Không có IF/Switch |
| R14 reply_to deleted msg | — | Không có node Telegram |
| R16/R26 đúng path tham số | ✅ | `query`/`operation`/`options` nằm trực tiếp dưới `parameters`, không có `parameters.parameters.*` |
| R18 onError/alwaysOutputData | ✅ (N/A có chủ đích) | Node Postgres không có `onError`/`alwaysOutputData` — đúng cho migration chạy tay: DDL lỗi phải làm execution `error` (MIG-02 bắt được), không được nuốt lỗi; không có node nào phía sau |
| R21 replyMarkup literal | — | Không có |
| R23 bot credential | — | Không có node Telegram |
| R24 binary | — | Không có đường binary |
| R25 credential | ✅ | `"credentials":{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}` = PLAN mục 3; node nguồn cả 7 cũng dùng đúng `GwUFREmcXzXXj5mZ` |
| R30 LangChain | — | Không có |
| SQL không phá huỷ | ✅ | Xem S1e — 0 câu DROP/ALTER…TYPE/DELETE/UPDATE/TRUNCATE/INSERT |
| V1 Validation | ✅ | `validate_node_config` (postgres v2.7 `executeQuery`, manualTrigger v1) → `{"valid":true}`; cấu hình tham số ở mức schema không phụ thuộc nội dung chuỗi query. Connections kiểm tay: 1 cạnh, nguồn/đích tồn tại |
| V2 disabled/REPLACE_* | ✅ | Không node nào `disabled`; không chuỗi `REPLACE_` trong workflow |

Blocking issues: không có.

Ghi chú không chặn:
- sha256 trong bảng BUILD_LOG WP2 mục 1 **không tái tạo được như ghi**: mỗi chuỗi dài 63 ký tự (thiếu 1 ký tự hex) và là hash của `query + "\n"`, không phải hash của `query` (vd Gateway: `sha256(query)=664cc8d2…fc15`, `sha256(query+"\n")=09cf706f…c53fe`). Không ảnh hưởng kết quả vì audit này so trực tiếp bằng chuỗi; sha256 toàn query staging `8aadb699e199e69bf0f10eb0651f8e9f3fdc8d18250e1e0e429f8954f0e5461e` thì khớp BUILD_LOG fix #1.

Risk notes:
1. **Thời điểm chạy — hiện đang TRONG khung traffic.** Audit xong lúc 01:53 UTC = **08:53 giờ VN**, nằm trong 08:00–10:00 VN (cũng trùng khung mở khoá TTLock 8h30–9h30 theo thiết kế gốc). `ALTER TABLE … ADD COLUMN IF NOT EXISTS` luôn xin khoá **ACCESS EXCLUSIVE** trên bảng *trước khi* kiểm tra cột đã có hay chưa, kể cả khi thành no-op. Bản thân mỗi câu chạy vài ms, NHƯNG nếu 1 session khác đang giữ khoá trên `clickup.upload_notify_queue`/`clickup.pending_uploads`/`gateway.notify_targets` (vd transaction dài của Full Reconcile hay Live Update), câu ALTER sẽ xếp hàng chờ và **chặn mọi SELECT/INSERT mới** vào bảng đó sau nó (lock queue) cho tới khi xong → Gateway (`GW-04 Check Pending Upload` đọc `clickup.pending_uploads` mỗi request) có thể treo. So với hiện trạng: production vốn đã chạy chính các câu này mỗi request (Gateway `Ensure Pending Uploads Table`, Reader 3 node `Ensure …`), nên rủi ro *mỗi câu* không mới. Điểm khác: n8n Postgres gửi cả chuỗi 22 câu trong 1 lần (simple query protocol → 1 transaction ngầm), nên khoá ACCESS EXCLUSIVE của mọi bảng đã ALTER được **giữ tới cuối cả batch**, và nếu 1 câu lỗi thì cả batch rollback (an toàn về dữ liệu, nhưng MIG-02 fail). Khuyến nghị: chạy MIG-02/03 ngoài 08:00–10:00 VN (tốt nhất trong khung 0 traffic, vd đêm hoặc CN 19:00–22:00 VN). Nếu buộc phải chạy trong giờ, trước đó chạy SQL chỉ-đọc `SELECT pid, state, xact_start, query FROM pg_stat_activity WHERE state <> 'idle' AND xact_start < now() - interval '5 seconds';` để chắc không có transaction dài; cân nhắc `SET lock_timeout = '3s'` ở đầu query — nhưng đó là thay đổi query (không nằm trong whitelist 5.2, cần Architect duyệt), nên audit này KHÔNG đòi thêm.
2. **Phụ thuộc bảng có sẵn:** `gateway.notify_targets` và `clickup.upload_notify_queue` chỉ bị ALTER, không được CREATE ở đâu trong migration; schema `gateway`/`clickup` cũng không được tạo. Trên DB production hiện tại chúng chắc chắn tồn tại (Reader đang chạy các ALTER này thành công), nên OK cho MIG-02; nhưng workflow này KHÔNG phải "nơi duy nhất chứa DDL" đầy đủ để dựng DB mới từ đầu. MIG-04 nên kiểm cả 2 bảng này.
3. **Seed `gateway.ttlock_auth(id=1)`:** đã bỏ khỏi migration theo quyết định Architect. Hiện TTLock `Ensure Schema (Lock)` vẫn tự seed mỗi request nên không mất gì; nhưng khi sau này bỏ node `Ensure Schema (Lock)` trong bản v2 của TTLock, phải chuyển câu INSERT seed sang 1 nơi khác (không phải workflow WP2), nếu không DB mới sẽ thiếu dòng id=1.
4. Workflow đặt `availableInMCP: true` — cần cho `execute_workflow`; không có trigger ngoài nên không có bề mặt tấn công. Không có `errorWorkflow`: lỗi khi chạy tay sẽ chỉ thấy trong execution (chấp nhận được vì người chạy/agent đọc kết quả ngay).

## WP1 — GW Error Handler v2 — audit #1 — 2026-09-25T02:20:00Z
VERDICT: FAIL
Staging `MaoEB8w8Un6UA01n` versionId `c4f05b7d-0a9c-48c1-b832-25e3637ea69e` (khớp; history chỉ có 2 bản: `72e4efff…` Initial build → `c4f05b7d…` Fix credentials), `active:false`, `activeVersionId:null`. So với v1 `34ccboHpyoY2r691` (chỉ đọc).

| Check | Result | Evidence (quoted from workflow JSON / tool output) |
|---|---|---|
| S1a Set `Chuẩn Hoá Lỗi` 6 trường | ✅ | set v3.4, `"includeOtherFields":false`, `mode:manual`; `workflowName`=`={{ $json.workflow?.name \|\| 'unknown' }}`, `workflowId`=`={{ $json.workflow?.id \|\| '' }}`, `nodeName`=`={{ $json.execution?.lastNodeExecuted \|\| $json.trigger?.error?.node?.name \|\| '?' }}`, `errorMessage`=`={{ String(...).slice(0, 2000) }}`, `executionId`, `executionUrl` — nguyên văn PLAN WP1 bước 2; logic trùng jsCode v1 (`wf/wfId/node/msg/url/execId`, `String(msg).slice(0, 2000)`). |
| S1b `text` tái tạo định dạng v1 | ✅ | `"=🚨 LỖI WORKFLOW\n📋 {{ …workflow?.name \|\| 'unknown' }}\n📍 Node: {{ … \|\| '?' }}\n❌ {{ String(…'unknown error').slice(0, 500) }}\n🔗 {{ $json.execution?.url \|\| '' }}"` = template v1 `🚨 LỖI WORKFLOW\n📋 ${wf}\n📍 Node: ${node}\n❌ ${String(msg).slice(0, 500)}\n🔗 ${url}`. Cắt 500 cho text / 2000 cho errorMessage giữ đúng; thiếu url → dòng `🔗 ` rỗng như v1; `\n` là newline thật (giống v1, output v1 exec 7145). |
| S1c SQL CTE nguyên văn spec | ✅ | So từng dòng với PLAN mục 6 WP1 bước 3: `WITH ins_log AS (INSERT INTO gateway.error_logs (...) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id), thr AS (INSERT INTO gateway.error_alert_throttle (bucket_key) VALUES ($2 \|\| '\|' \|\| $3 \|\| '\|' \|\| to_char(date_trunc('minute', now()), 'YYYYMMDDHH24MI')) ON CONFLICT (bucket_key) DO UPDATE SET suppressed_count = … + 1 RETURNING (xmax = 0) AS is_first) SELECT (SELECT id FROM ins_log) AS log_id, (SELECT is_first FROM thr) AS should_alert;` — khớp. Không có SQL phá huỷ. |
| S1d queryReplacement 6 phần tử đúng thứ tự | ✅ | `"={{ [ $json.workflowName, $json.workflowId, $json.nodeName, $json.errorMessage, $json.executionId, $json.executionUrl ] }}"` — giống hệt v1 `Log Error To DB` và thứ tự cột INSERT. |
| S1e Rủi ro tách dấu phẩy | ✅ (có điều kiện test) | Postgres v2.7 executeQuery: nhánh tách chuỗi theo dấu phẩy chỉ chạy khi giá trị resolve là **string**; expression `={{ [ … ] }}` resolve ra **mảng** → dùng thẳng làm mảng values (pg-promise tự escape từng phần tử) → dấu phẩy/nháy trong errorMessage không lệch tham số. Đây cũng là dạng bắt buộc theo RULES #7 ("`queryReplacement` LUÔN dùng mảng"), đang chạy ở v1 và ~10 node production (vd `Ghi Task Links Mới` truyền `$2::jsonb`). get_node_types chỉ khai báo `queryReplacement?: string` nên không tự chứng minh runtime; chưa tìm được execution v1 có message chứa dấu phẩy (các message gần nhất: "Task request timed out", "The service is receiving too many requests from you"). **Bắt buộc tester:** ERR-01 dùng message có dấu phẩy + nháy đơn (vd `throw new Error("TEST WP1, a, 'b', " + n)`) và xác nhận đúng 6 cột trong `gateway.error_logs`. |
| S1f IF `Cần Gửi Cảnh Báo?` kiểu so sánh | ✅ | if v2.3, `typeValidation:"strict"`, `leftValue:"={{ $json.should_alert }}"`, `operator:{type:"boolean",operation:"equals"}`, `rightValue:true`. `(xmax = 0)` là cột `boolean` Postgres → node-pg trả JS `true/false` thật → strict hợp lệ. Khi Postgres lỗi, item là `{error:…}` → `should_alert` undefined → IF filter coi null/undefined là hợp lệ về kiểu, kết quả false (không throw) — nhưng xem blocking #1. |
| S1g Node settings trên JSON live | ✅ | Postgres: `"retryOnFail":true,"maxTries":3,"waitBetweenTries":2000,"alwaysOutputData":true,"onError":"continueRegularOutput"`; Telegram: `"retryOnFail":true,"maxTries":3,"waitBetweenTries":5000,"onError":"continueRegularOutput"` — đúng spec. |
| S1h Telegram node | ✅ | telegram v1.2 sendMessage, `chatId:"-1003647848349"`, `additionalFields:{"appendAttribution":false,"message_thread_id":4}` (= v1), `text:"={{ $('Chuẩn Hoá Lỗi').first().json.text }}"` (tường minh, RULES #2). Không có replyMarkup (R21 N/A). |
| S1i Connections | ✅ | `Error Trigger→Chuẩn Hoá Lỗi→Ghi Lỗi + Kiểm Tra Gộp→Cần Gửi Cảnh Báo?`; `"Cần Gửi Cảnh Báo?":{"main":[[{"node":"Báo admin Telegram"…}]]}` — chỉ output 0 (true); output 1 không nối. |
| S1j Workflow settings | ✅ | `{"executionOrder":"v1","availableInMCP":true}` — không `errorWorkflow`. |
| S1k 0 Code node (ERR-03) | ✅ | 5 node: errorTrigger, set, postgres, if, telegram. |
| S2 Production không đổi | ✅ | get_workflow_details: xmEK `180005b7…`, eWtu `53d44baa…`, 6I4M `435af575…`, uqTq `42cfa99b…`, 9JJR `4437fece…`, 34cc `1a6b1d2a…`, G1R0 `92611b33…`, oF4I `7199e254…` — tất cả `versionId == activeVersionId` và khớp BUILD_LOG WP0. |
| R2 | ✅ | IF đọc `$json.should_alert` ngay sau Postgres (đúng spec); Telegram tham chiếu tên node. |
| R13 | ✅ | IF main[0]=true → Telegram. |
| R16/R26 | ✅ | Không có `parameters.parameters.*`; `queryReplacement` nằm đúng `parameters.options`. |
| R18 | ✅ | Postgres có `alwaysOutputData`+`onError`; Telegram có `onError` (live JSON). |
| R23 | N/A | Không có nút bấm. |
| R25 Credentials | ✅ | Postgres `{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}`, Telegram `{"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}` — khớp PLAN mục 3 và v1; lỗi auto-assign (Supabase/@csfsintbot) đã hết ở `c4f05b7d`. |
| R14/R21/R24/R30 | N/A | Không có delete/replyMarkup/binary/LangChain. |
| V1 Validate | ✅ | Không có validate theo workflowId; kiểm tĩnh: mọi type/typeVersion tồn tại, tham số Postgres khớp get_node_types v2.7; builder: SDK `validate_workflow` `{"valid":true,"nodeCount":5}`, update cuối `validationWarnings: []`. |
| V2 | ✅ | Không node disabled, không `REPLACE_*`. |
| Bảng `gateway.error_alert_throttle` | — | Chưa tồn tại (WP2 chưa chạy) — không tính lỗi WP1; tester phải chạy sau WP2. |
| R-DB Postgres lỗi → không cảnh báo | ❌ | Xem blocking #1. |

**Khác biệt v2 so với v1 (đầy đủ):**
1. `Format lỗi` (Code v2) → `Chuẩn Hoá Lỗi` (Set v3.4), cùng 7 field, cùng logic (cho phép — spec).
2. Thứ tự: v1 fan-out song song Telegram (index 0, chạy trước) + DB; v2 tuần tự DB → IF → Telegram (spec, ERR-04).
3. Throttle: ≤1 tin / (workflowId+nodeName) / phút (khác biệt cho phép duy nhất).
4. Retry/onError/alwaysOutputData mới trên Postgres + Telegram (spec).
5. Telegram text `$json.text` → `$('Chuẩn Hoá Lỗi').first().json.text` (spec).
6. v1 settings có `binaryMode:"separate"`, v2 không có — vô hại (không binary).
7. **Không liệt kê trong spec:** (a) DB lỗi → v2 không gửi Telegram (v1 vẫn gửi); (b) Telegram hoặc DB lỗi → execution v2 vẫn `success` (continueRegularOutput) — v1 thì `error` (vd exec 7130 lỗi 429). (c) Bucket theo `workflowId` rỗng khi `workflow.id` thiếu → mọi lỗi "unknown" cùng node gộp chung.

Blocking issues:
1. `Cần Gửi Cảnh Báo?` — khi `Ghi Lỗi + Kiểm Tra Gộp` lỗi (DB sập / mất kết nối / bảng throttle thiếu), item ra là `{error:…}`, `should_alert` undefined → IF false → **không có tin Telegram, không có dòng DB, execution vẫn `success`** = im lặng hoàn toàn đúng lúc sự cố hạ tầng lớn nhất. v1 trong tình huống này vẫn gửi Telegram. Đây là regression của mục tiêu WP1 ("quan sát lỗi trước") và không nằm trong "khác biệt cho phép" → chặn. **Fix tối thiểu (không Code node):** đổi leftValue IF thành `={{ $json.should_alert === true || !$json.log_id }}` (giữ operator boolean equals `true`, strict vẫn đúng vì luôn ra boolean) — DB OK: hành vi throttle y spec; DB lỗi: fail-open, mọi lỗi đều báo (có retry 3×5s của Telegram, không làm hỏng execution). Cập nhật PLAN WP1 bước 4 + thêm test ERR-06 (pin Postgres trả `{error:"connection refused"}` → phải có 1 lần gọi Telegram). Sửa bằng `removeNode`+`addNode` hoặc cập nhật cả node (RULES #16), re-read live JSON xác nhận.

Risk notes:
- Execution status luôn `success` kể cả Telegram 429/DB lỗi → không còn tín hiệu "handler lỗi" trong danh sách executions; ERR-02 "0 execution handler lỗi" sẽ đạt kể cả khi tin bị rớt → tester phải kiểm runData của `Báo admin Telegram` (`ok:true`) chứ không chỉ status.
- Khi DB lỗi + fix #1: burst N lỗi → N tin Telegram → có thể 429 như v1 (chấp nhận được, chế độ suy giảm).
- `suppressed_count` chỉ đếm, không có tin tổng kết "đã gộp X lỗi" — admin không biết số lỗi bị gộp trừ khi xem DB (đúng spec, ghi nhận).
- Error workflow inactive vẫn được n8n gọi qua `settings.errorWorkflow` — cần xác nhận trong ERR-01 (WP5 phụ thuộc).

## WP1 — GW Error Handler v2 — audit #2 — 2026-09-25T02:10:00Z
VERDICT: PASS
Staging `MaoEB8w8Un6UA01n` live: `versionId:"4f7d5a4b-c6e3-436a-be87-b85793b039bf"`, `active:false`, `activeVersionId:null`. History: `72e4efff…` → `c4f05b7d…` → `4f7d5a4b…` ("WP1 fix #1 - fail-open IF condition").

| Check | Result | Evidence (quoted from workflow JSON / tool output) |
|---|---|---|
| Diff c4f05b7d → 4f7d5a4b | ✅ | `get_workflow_versions_diff`: `nodesAdded:[]`, `nodesRemoved:[]`, `connectionsAdded:[]`, `connectionsRemoved:[]`, `nodesModified` chỉ có `Cần Gửi Cảnh Báo?`: `leftValue {"__old":"={{ $json.should_alert }}","__new":"={{ $json.should_alert === true \|\| !$json.log_id }}"}`. 4 node còn lại không đổi so với audit #1 (đã đọc lại JSON live: Set 7 assignment, SQL CTE, queryReplacement, settings, credentials giống hệt). |
| Blocking #1 audit #1 (fail-open) | ✅ | IF live: `"leftValue":"={{ $json.should_alert === true \|\| !$json.log_id }}"`, `operator:{type:"boolean",operation:"equals"}`, `rightValue:true`, `typeValidation:"strict"`. Khớp PLAN mục 6 WP1 bước 4 (dòng 195). |
| Biểu thức luôn ra boolean (strict) | ✅ | `===` luôn trả boolean; `A \|\| B` trả A nếu A true, ngược lại trả `!$json.log_id` (boolean). Bảng: DB OK lần đầu `{log_id:N,should_alert:true}` → true; DB OK bị gộp `{log_id:N,should_alert:false}` → `false \|\| !N` = false (id serial ≥1; bigint dạng text `"N"` cũng truthy); DB lỗi `{error:"…"}` → `false \|\| !undefined` = true; `$json` rỗng `{}` → true; `should_alert:null` → `!log_id`. Không có nhánh trả non-boolean → strict không throw. |
| S1 phần còn lại | ✅ | Như audit #1 (Set/SQL/queryReplacement/text/Telegram/connections output 0 → Telegram, output 1 không nối). |
| Node settings (live) | ✅ | Postgres `retryOnFail:true,maxTries:3,waitBetweenTries:2000,alwaysOutputData:true,onError:"continueRegularOutput"`; Telegram `retryOnFail:true,maxTries:3,waitBetweenTries:5000,onError:"continueRegularOutput"`. |
| R25 Credentials | ✅ | `{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}`, `{"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}`. |
| 0 Code node / settings workflow | ✅ | 5 node errorTrigger/set/postgres/if/telegram; `settings:{"executionOrder":"v1","availableInMCP":true}` — không errorWorkflow. |
| S2 Production | ✅ | Đọc lại lúc audit #2: 34cc `1a6b1d2a…`, xmEK `180005b7…`, eWtu `53d44baa…`, 6I4M `435af575…`, uqTq `42cfa99b…`, 9JJR `4437fece…`, G1R0 `92611b33…`, oF4I `7199e254…` — `versionId == activeVersionId`, khớp WP0. |
| R16/R26 | ✅ | leftValue ở đúng `parameters.conditions.conditions[0].leftValue`, không có `parameters.parameters`. |
| V1/V2 | ✅ | Tham số hợp lệ theo type if v2.3; không disabled node, không `REPLACE_*`. |
| PLAN 7.4 | ✅ | Đã có ERR-06 (pin Postgres `{"error":"connection refused"}` → IF true, Telegram có trong runData) và ERR-07 (message `a, b 'c' "d"` → 6 cột đúng). |

Blocking issues: không có.

Risk notes (còn hiệu lực từ audit #1, không chặn):
- Execution handler luôn `success` kể cả Telegram 429/DB lỗi → tester kiểm `ok:true` trong runData `Báo admin Telegram`, không chỉ status.
- DB lỗi + burst → mỗi lỗi 1 tin (fail-open, không throttle) → có thể 429 như v1; chấp nhận là chế độ suy giảm.
- Dấu phẩy trong `queryReplacement` mảng: đúng về code path nhưng chỉ được xác nhận thực nghiệm qua ERR-07 — WP1 chưa được READY FOR CUTOVER nếu ERR-07 chưa PASS.
- ERR-01..07 cần bảng `gateway.error_alert_throttle` (WP2) tồn tại trước.

## WP3 — GW Gateway v2 — audit #1 — 2026-09-25T02:45:00Z
VERDICT: PASS

Nguồn: `get_workflow_details` live `hn0YZ85sXtfGACJ4` (versionId `dbc644d4-7c8a-44e5-90dd-ec18b9aab157`, `active:false`, 44 node) và `get_workflow_version` v1 `xmEKeIUnzxm2F7dF@180005b7-…` (48 node; trùng khớp 100% với bản live của v1). Diff bằng script riêng của auditor (python edge-set + node/key diff; node `vm` để evaluate jsCode v1 và mô phỏng Router), không dựa vào BUILD_LOG.

| Check | Result | Evidence |
|---|---|---|
| S1 Clone parity (GW-S1) | ✅ | Chỉ v1 có: `Audit Log (Supabase)`, `Tạo pending user (Supabase)` (C1), `Ensure Pending Uploads Table` (C2), `GW-04b Merge Pending` (C4); chỉ v2 có: không. 40 node chung: type/typeVersion/parameters/credentials/onError/alwaysOutputData/retry giống hệt, trừ `⚙️ Config` (C3) và `GW-03 Router` jsCode (C4). Khác biệt ngoài C1–C4 chỉ là `webhookId` (12 node Telegram, chấp nhận) và `disabled:false` (v1, 2 node `Là Tin Nhắn Nhóm?`/`Ghi Log Tin Nhắn Nhóm`) → vắng mặt ở v2 = tương đương. Position không đổi. Edge chỉ-v1: 6 cạnh đều thuộc 4 node bị xoá; edge chỉ-v2: đúng 2 cạnh `Trạng thái user?[3]→GW-04 Check Pending Upload`, `GW-04 Check Pending Upload[0]→GW-03 Router`. Không có edge treo. |
| S1 Webhook trigger | ✅ | `Telegram Trigger Gateway` v1 `webhookId 9e5cefc0-af9b-4e9f-87f1-c94a1a353073` → v2 `bc2ca2ac-cb2a-4925-aef9-ef115ee9903a`; 0/12 webhookId v2 trùng với v1 → không xung đột path khi cutover. Lưu ý: Telegram chỉ giữ 1 webhook/bot → runbook mục 8 đúng thứ tự (unpublish v1 TRƯỚC, publish v2 SAU); đảo thứ tự sẽ làm deleteWebhook của v1 xoá luôn webhook v2. |
| C1 | ✅ | v1: `Audit Log (Supabase) | GwUFREmcXzXXj5mZ Postgres account`, `Tạo pending user (Supabase) | GwUFREmcXzXXj5mZ Postgres account` (Docker, không phải Supabase); cả 2 không có key trong `connections` (0 output) → nhánh cụt song song với `Audit Log (Docker)` / `Tạo pending user`. D4: `Approve/Deny … (Supabase)` vẫn còn với `hO4yfw7ailV7jHAv Supabase Postgres`. |
| C2 | ✅ | v1 `Trạng thái user?` rules theo thứ tự `new,pending,denied,active` → output 3 = `outputKey:"active"` → `Ensure Pending Uploads Table`. v2 output 3 → `GW-04 Check Pending Upload`. JSON live: `{"alwaysOutputData": true, "onError": null}` (onError null giống v1). Query GW-04 dùng `$('GW-02b Merge Auth').first()` nên việc đổi node upstream không ảnh hưởng. |
| C3 | ✅ | Set `n8n-nodes-base.set` v3.5, `mode:manual`, `includeOtherFields:false`, retry `[true,5,5000]` = v1. Evaluate jsCode v1 vs 4 assignment v2: `DEEP EQUAL: true`; kiểu thực tế `ADMIN_CHAT_ID string/string, AVAILABLE_BOTS array/array, COMMAND_MAP object/object, DEFAULT_BOT string/string` (GW-20 tĩnh PASS). Tham chiếu downstream: `Báo admin duyệt user`, `Báo Admin Cấp Quyền Lock` (`.ADMIN_CHAT_ID`), `GW-03 Router` (`cfg.COMMAND_MAP[...]`, `cfg.DEFAULT_BOT`); không có `JSON.parse` ở node nào. v3.5 = version mới nhất theo `get_node_types`; spec WP3 không ghim version (3.4 là của WP1) → chấp nhận. `validate_node_config` → `valid:true`. |
| C4 | ✅ | jsCode diff đúng 1 hunk: `-const env = $input.first().json;` → +3 dòng spec, phần còn lại byte-identical. Đường tới Router duy nhất: `GW-02b → Trạng thái user?[3] → GW-04 → Router` ⇒ `GW-02b Merge Auth` luôn đã chạy. Logic v1 GW-04b (`filter(r => r && r.task_id)`, `rows[0]`/null, base từ GW-02b) giống hệt 3 dòng mới. Mô phỏng v1(GW-04b→Router) vs v2(Router) trên 5 envelope × 5 rowset (`[{}]` từ alwaysOutputData, 1 dòng, dòng thiếu task_id, 2 dòng, rỗng) → `equivalent cases: 25` (deepStrictEqual). Router chạy runOnceForAllItems → 1 item ra như v1. |
| Workflow settings | ✅ | v2 `executionOrder:v1, errorWorkflow:34ccboHpyoY2r691, callerPolicy:workflowsFromSameOwner`. Thiếu `binaryMode:"separate"`, `timeSavedMode:"fixed"`: không có node nào tạo/tiêu thụ binary trong Gateway (Trigger không download, không node file) → không ảnh hưởng hành vi; `timeSavedMode` chỉ dùng cho Insights. Không blocking (xem risk note). |
| R2 | ✅ | Node có upstream đổi: `GW-01 Envelope` đọc `$('Telegram Trigger Gateway').first()`, `GW-04` đọc `$('GW-02b Merge Auth').first()`, Router đọc `$('GW-02b…')` + `$input.all()` có chủ đích. |
| R13 | ✅ | Switch output index 3 = rule thứ 4 `active`; các Switch/IF khác không đổi (edge-set). |
| R18 | ✅ | GW-04 `alwaysOutputData:true` trên JSON live; `GW-02 Auth Lookup`, `Check admin`, `Tạo pending user` giữ `alwaysOutputData:true` như v1. |
| R21/R23 | ✅ | `replyMarkup:"inlineKeyboard"` literal; credential Telegram không đổi so với v1 (`Báo admin duyệt user`=System Bot, `Báo Admin Cấp Quyền Lock`=Elite Clickupbot, như v1). |
| R25 | ✅ | Credentials v2: `postgres GwUFREmcXzXXj5mZ ×8`, `postgres hO4yfw7ailV7jHAv ×2`, `telegramApi BHVAx8GV38yQEn1I ×10`, `telegramApi zSZ6vVapow5LNpFT ×2` — đều khớp PLAN §3, đều trùng node-by-node với v1. |
| R14/R16/R24/R30/SQL | — / ✅ | Không có xoá tin, không `parameters.parameters`, không binary path, không LangChain; không SQL mới (chỉ bớt 1 DDL). |
| V1 | ✅ | Không có validate theo workflowId; `validate_node_config` cho `⚙️ Config` (set 3.5), `GW-04` (postgres 2.7), Router head (code 2) → `{"valid":true}`; kiểm tĩnh edge/tên node không treo. |
| V2 | ✅ | Disabled `→ Sub: Help Bot`/`→ Sub: Crawl Bot` và `REPLACE_HELP_BOT_ID`/`REPLACE_CRAWL_BOT_ID` có sẵn từ v1 — không do WP3 thêm. |
| S2 | ✅ | `get_workflow_details` 25/09: Gateway `180005b7…`, Admin `53d44baa…`, Ảnh `435af575…`, Live Update `42cfa99b…`, Reader `4437fece…`, Error Handler `1a6b1d2a…`, Reconcile `92611b33…`, Interview `7199e254…` — `versionId==activeVersionId`, khớp WP0. D3: Blacklist `72efa72b…`, TTLock `84e951d2…`/active `f3062458…`, Rule Engine `9905e164…` — khớp WP0. |

Blocking issues: không có.

Risk notes:
1. `binaryMode`/`timeSavedMode` vắng trên v2 — vô hại cho Gateway hiện tại, nhưng nên bật lại qua UI trước cutover để settings giống v1 100% (tránh khác biệt nếu sau này thêm node binary).
2. Cutover: bắt buộc giữ thứ tự unpublish v1 → publish v2 (và ngược lại khi rollback); không bao giờ để 2 workflow cùng active trên bot Elite Clickupbot.
3. `GW-04` không có `onError` (giống v1): DB lỗi → execution fail → errorWorkflow; parity, không đổi.
4. Sticky note `📘 Ghi chú kiến trúc` vẫn nhắc `Audit Log (Supabase)` — cosmetic, cập nhật sau cutover.
5. Tester vẫn phải chạy DIFF GW-01…GW-19 bằng pin data; audit này chỉ chứng minh tĩnh + mô phỏng logic Code.
