# BUILD_LOG — refactor 2026-W39

## WP0 — Chuẩn bị — 2026-09-25T01:33:12Z

### 1. Folder staging

- Không tìm thấy folder `REFACTOR 2026-W39 (staging)` đã có sẵn (search_folders trả rỗng) → đã tạo mới.
- **folderId: `ZdlLC9utIKkjLvhv`** (project `5cL5BKorhKAQ2ONI`, root, không nested).

### 2. Mốc rollback — 8 workflow production (mục 3)

Lấy bằng `get_workflow_details(detailLevel: execution)` lúc chạy. Tất cả 8 workflow đều có
`versionId == activeVersionId` (không có bản nháp chưa publish nào).

| Workflow | ID | active | versionId = activeVersionId | errorWorkflow | Khớp bảng mục 3? |
|---|---|---|---|---|---|
| GW Gateway - Telegram (DEV) | `xmEKeIUnzxm2F7dF` | true | `180005b7-a44a-4c95-ace6-24529ae46566` | `34ccboHpyoY2r691` | Khớp |
| Telebot Admin System | `eWtu7Qs85Hes0HuP` | true | `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f` | *(không có)* | Khớp (errorWorkflow thiếu — đúng như PLAN mục 3/WP5 đã ghi nhận, cần WP5 thêm) |
| Bot Xử Lý Ảnh (xoanen + tomtat) | `6I4MnJiJCiv2JOIr` | true | `435af575-e17f-488e-b616-20798790bbdf` | *(không có)* | Khớp (errorWorkflow thiếu — WP5 thêm) |
| SQL - ClickUp Live Update (Webhook) | `uqTqjtHYieotPZuc` | true | `42cfa99b-6659-47dd-8a84-f9fa4e977739` | `34ccboHpyoY2r691` | Khớp |
| Telebot ClickUp Reader | `9JJRrh36H2rLwtnu` | true | `4437fece-36da-4ccc-82fa-16e5330c7960` | *(không có)* | Khớp (errorWorkflow thiếu — WP5 thêm) |
| GW Error Handler | `34ccboHpyoY2r691` | true | `1a6b1d2a-2ff8-4cf0-ae59-9ae3e978a183` | *(không có — đúng, tự nó là handler)* | Khớp |
| SQL - ClickUp Full Reconcile (5 ngay) | `G1R0okF0rUziySu9` | true | `92611b33-57df-463c-910e-b00c24144dd9` | `34ccboHpyoY2r691` | PLAN mục 3 ghi "WP0 ghi lại" → **đã ghi: `92611b33-57df-463c-910e-b00c24144dd9`** |
| Interview Evaluation - Elite Education (Supabase) | `oF4IWJf6Yad2wF5G` | true | `7199e254-a3ab-4b8a-a523-768a7b51e468` | `34ccboHpyoY2r691` | PLAN mục 3 ghi "WP0 ghi lại" → **đã ghi: `7199e254-a3ab-4b8a-a523-768a7b51e468`** |

### 3. Mốc rollback — 3 workflow cấm đụng (D3, chỉ đọc)

| Workflow | ID | active | versionId | activeVersionId | Khác nhau? | errorWorkflow |
|---|---|---|---|---|---|---|
| Blacklist Bot (/dspv) | `jPaCu9Yv6fgnsKsi` | true | `72efa72b-5624-4846-9bdd-ee094b2d4659` | `72efa72b-5624-4846-9bdd-ee094b2d4659` | Giống nhau (không có bản nháp tại thời điểm 01:33 UTC 25/09) | *(không có)* |
| Telebot Lock (TTLock) | `vGgJ0XfTR3ltohPB` | true | `84e951d2-bb41-43a9-a67e-3b0b0f42c38b` | `f3062458-d905-421b-bf1b-82f4caab3255` | **KHÁC NHAU — có bản nháp chưa publish**, khớp đúng cảnh báo D3 trong PLAN | *(không có)* |
| Interview Rule Engine - Rule 1,2,4 | `ow1fAaAYwxaZjyD4` | true | `9905e164-2afc-41ae-8a92-0a338783f453` | `9905e164-2afc-41ae-8a92-0a338783f453` | Giống nhau | `1KBpJaseeCU13Jtw` (khác GW Error Handler, không đụng) |

Không có `update_workflow`/`publish_workflow`/`unpublish_workflow`/`archive_workflow` nào được gọi trên
bất kỳ ID nào ở mục 2 và mục 3 — chỉ `get_workflow_details` (đọc).

### 4. Corpus Gateway (`corpus/gateway/`) — 19 file

Nguồn: `search_workflow_executions` (workflowId `xmEKeIUnzxm2F7dF`, status success) + `get_workflow_execution`
(includeData, nodeNames `["Telegram Trigger Gateway"]`) — lấy mẫu trải từ 22/09 đến 25/09 (~2072 execution,
đã đọc raw update của ~40 execution) và một đợt lấy quanh 15/09 để tìm callback_query thật (dự án ưu tiên
deep-link hơn inline keyboard — RULES #3 — nên callback thật RẤT hiếm trong dữ liệu gần đây; tìm thấy 3 mẫu
callback thật từ 15/09, dùng làm khuôn cho các loại synthetic).

| File | Loại | Thật/Synthetic | Ghi chú |
|---|---|---|---|
| GW-01_task_command.json | `/task <kw>` | Thật | exec Gateway |
| GW-02_tomtat_photo.json | `/tomtat` + ảnh | Synthetic | dựa trên GW-03 thật, đổi caption |
| GW-03_xoanen_photo.json | `/xoanen` + ảnh | Thật | exec Gateway |
| GW-04_start_mokhoa_sel.json | `/start mokhoa_sel_<id>` | Thật | exec Gateway |
| GW-05_mokhoa_group_no_permission.json | `/mokhoa` trong chat -5535257695 | Thật | trạng thái quyền phải PIN riêng ở GW-02 |
| GW-06_mokhoa_other_chat_no_permission.json | `/mokhoa` chat khác | Thật | đã chạy thật tới "Không có quyền bot này" |
| GW-07_callback_odhelp.json | callback `odhelp_123` | Synthetic | dựa khuôn callback thật, đổi `data` |
| GW-08_callback_odfwd.json | callback `odfwd_123` | Synthetic | dựa khuôn callback thật, đổi `data` |
| GW-08b_real_start_chitiet_deeplink.json | `/start chitiet_<id>` | Thật | bổ sung thật cho nhóm GW-08 (prefix `chitiet_`) |
| GW-09_callback_imgai.json | callback `imgai_5`/`imgupscale_5`/`imgcancel` | Synthetic | dựa khuôn callback thật, đổi `data` |
| GW-10_callback_lockap.json | callback `lockap:1`/`lockdn:1`/`lockgrant:1` | Synthetic | dựa khuôn callback thật, đổi `data`, from=admin |
| GW-11_callback_unknown_xyz.json | callback `xyz_1` | Synthetic | dựa khuôn callback thật, đổi `data` |
| GW-12_task_pending_zero_rows.json | `/task` khi GW-04 trả 0 dòng | Thật (input) | trạng thái "0 dòng" phải PIN riêng ở GW-04 |
| GW-13_plaintext_pending_one_row.json | tin text thường, pending 1 dòng | Thật (input) | trạng thái "1 dòng" phải PIN riêng ở GW-04 |
| GW-14_auth_new_user.json | auth=new | Thật (input) | trạng thái auth phải PIN riêng ở GW-02 |
| GW-15_auth_pending_denied.json | auth=pending/denied | Thật (input) | trạng thái auth phải PIN riêng ở GW-02 |
| GW-16_group_text_mention_tag.json | tin nhóm có `@@abc` | Synthetic | dựa tin nhóm thật, thêm `@@abc ` vào đầu text |
| GW-17_unknown_command.json | lệnh lạ (`/nentrang`, không phải `/abcxyz` nhưng cùng loại) | Thật | thật đã chạy tới "Hướng dẫn lệnh" |
| GW-18_callback_approve_non_admin.json | callback `ap:1:ALL` từ non-admin | Synthetic | dựa khuôn callback thật, đổi `data` + `from` |

Tổng: 19 file — **9 thật, 10 synthetic** (GW-05/06/12/13/14/15/17/08b dùng update Telegram thật dù trạng
thái DB/pending đi kèm phải pin riêng; GW-02/07/08/09/10/11/16/18 là synthetic có `"synthetic": true`).

### 5. Corpus Admin (`corpus/admin/`) — 7 file

Nguồn: `search_workflow_executions` (workflowId `eWtu7Qs85Hes0HuP`) + `get_workflow_execution` (includeData,
nodeNames `["Telegram Trigger (System Bot)"]`) — chỉ 195 execution tổng, đọc ~15 mẫu.

| File | Loại | Thật/Synthetic |
|---|---|---|
| ADM-01_vps.json | `/vps` | Thật |
| ADM-02_start_vpsc_deeplink.json | `/start vpsc_<id>` | Thật |
| ADM-03_callback_vpsrestart.json | callback `vpsrestart_<id>` | Thật |
| ADM-04_callback_vpscancel.json | callback `vpscancel` | Thật |
| ADM-05_token.json | `/token` | Thật |
| ADM-06_version.json | `/version` | Synthetic (không có mẫu thật trong 195 execution đã soi) |
| ADM-07_error_logs.json | `/error_logs` | Synthetic (không có mẫu thật trong 195 execution đã soi) |

Tổng: 7 file — 5 thật, 2 synthetic. Không tìm thấy mẫu thật `/error_log_now` — không tạo file riêng (không
bắt buộc theo PLAN, chỉ liệt kê "nếu có").

### 6. .gitignore / check-ignore

- `.gitignore` đã có dòng `bot-gateway/docs/refactor-2026w39/corpus/` từ trước (dòng 5-6).
- Xác nhận `git -C /Users/haianh/Projects/n8nwf check-ignore -q <file>` trả exit 0 (ignored) cho **toàn bộ
  26 file** (19 gateway + 7 admin) — không có file nào bị bỏ sót.
- Repo `n8nwf` xác nhận là git repo hợp lệ (`git rev-parse --is-inside-work-tree` = true), khác với ghi chú
  môi trường ban đầu ("Is a git repository: false") — có thể ghi chú đó đã lỗi thời.
- Toàn bộ 26 file JSON đã được validate cú pháp bằng `python3 -c "json.load(...)"` — không lỗi.

### Việc KHÔNG làm (đúng luật an toàn mục 5)

- Không `update_workflow`/`publish_workflow`/`unpublish_workflow`/`archive_workflow` trên bất kỳ workflow
  production/cấm đụng nào.
- Không tạo workflow nào ngoài 1 folder staging.
- Không gửi Telegram thật, không SSH/docker.
- Không commit git (để Architect commit).

### Open questions for architect

- Không có câu hỏi mở nào cần dừng WP0. Hai điểm cần Architect/auditor lưu ý:
  1. TTLock (`vGgJ0XfTR3ltohPB`) hiện có `versionId != activeVersionId` — xác nhận có bản nháp thật đang
     tồn tại trên UI, đúng cảnh báo D3; WP0 chỉ đọc, không đụng.
  2. Không tìm được mẫu callback_query thật nào cho các prefix `odhelp_`, `odfwd_`, `imgai_`, `imgupscale_`,
     `imgcancel`, `lockap:`/`lockdn:`/`lockgrant:`, `xyz_`, `ap:...:ALL` trong toàn bộ dữ liệu đã soi (kể cả
     lùi về 15/09) — phù hợp với RULES #3 (dự án ưu tiên deep-link, hạn chế inline keyboard) nhưng nghĩa là
     các test GW-07/08/09/10/11/18 ở WP3 sẽ chạy trên dữ liệu 100% synthetic, cấu trúc dựa theo 1 callback
     thật duy nhất tìm được (exec `3072`, workflow `xmEKeIUnzxm2F7dF`). Auditor nên xác nhận cấu trúc
     `callback_query` synthetic (đặc biệt `chat_instance`, `message.from` là bot) hợp lệ trước khi WP3 dùng.

## WP2 — DB Migrations — 2026-09-25T01:47:06Z

**CHỈ BUILD, KHÔNG CHẠY** — đúng yêu cầu giao việc. Không gọi `execute_workflow`/`publish_workflow` lần nào
trên bất kỳ workflow nào (staging lẫn production) trong suốt WP này.

### 1. Đọc nguyên văn 7 node DDL nguồn (chỉ đọc — `get_workflow_details`/`get_workflow_version`)

Không có `update_workflow`/`publish_workflow`/... nào được gọi trên 4 workflow nguồn. Với TTLock
(`vGgJ0XfTR3ltohPB`), đọc đúng **bản ACTIVE** (`get_workflow_version` với `versionId =
f3062458-d905-421b-bf1b-82f4caab3255`, đúng `activeVersionId` ghi trong BUILD_LOG WP0) — KHÁC bản nháp
hiện có `versionId = 84e951d2-bb41-43a9-a67e-3b0b0f42c38b` ("TẠM THỜI tắt giới hạn khung giờ mở khóa"),
không đọc/đụng bản nháp đó, đúng D3.

| # | Nguồn (workflow / node) | versionId đã đọc | sha256 query gốc |
|---|---|---|---|
| 1 | GW Gateway - Telegram (DEV) `xmEKeIUnzxm2F7dF` / `Ensure Pending Uploads Table` | `180005b7-a44a-4c95-ace6-24529ae46566` (active) | `09cf706ff723a0e10e06e154aea7550af004af4bcb8c94063453ff35922c53f` |
| 2 | Telebot ClickUp Reader `9JJRrh36H2rLwtnu` / `Ensure Zalo Notify Column` | `4437fece-36da-4ccc-82fa-16e5330c7960` (active) | `acc263c4249c68ef58ab46fad139af4a6a0768fde4a4be80275bdb84ab70782` |
| 3 | Telebot ClickUp Reader `9JJRrh36H2rLwtnu` / `Ensure Pending Upload Columns` | `4437fece-36da-4ccc-82fa-16e5330c7960` (active) | `0b3f224e80d3b29fc1769adb097879cf89f91b4e2ed1c1c3949451a62f59324` |
| 4 | Telebot ClickUp Reader `9JJRrh36H2rLwtnu` / `Ensure Notify Queue Columns` | `4437fece-36da-4ccc-82fa-16e5330c7960` (active) | `820b656fdeadde7bff0f6ec34bd50d1d55b5e0da16dd6677b8eb54684f32887` |
| 5 | Telebot Admin System `eWtu7Qs85Hes0HuP` / `Ensure Sync Table` | `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f` (active) | `c9068d52c775848f2f4f4ac507028aaebb22e07d377c3cdbf30902174d08d73` |
| 6 | Telebot Admin System `eWtu7Qs85Hes0HuP` / `Ensure Mention Tables (Admin)` | `53d44baa-8e4b-4dd4-8f78-fbcd970fe46f` (active) | `4ae413959a735652ccd5ddf1b11a5fec81d85b19c80796d6148addf7233e471` |
| 7 | Telebot Lock (TTLock) `vGgJ0XfTR3ltohPB` / `Ensure Schema (Lock)` | `f3062458-d905-421b-bf1b-82f4caab3255` (**active**, KHÁC bản nháp `84e951d2-...`) | `94f9333b35f1670807d5308d508c643dbd827878105d75490c7a29aa6f56802` |

Cả 4 workflow nguồn đều có `versionId == activeVersionId` (không có bản nháp mới phát sinh so với WP0),
trừ TTLock vốn đã biết có bản nháp từ WP0 (đúng D3, không đụng). Toàn bộ 7 query gốc lưu nguyên văn trong
scratchpad phiên này (`q1..q7_*.sql`), không commit vào repo.

### 2. Workflow staging đã tạo

- **Tên:** `DB Migrations (chạy tay) (STAGING)`
- **workflowId:** `8XLg2q34VQq6IDx7`
- **versionId (sau khi tạo):** `229467f0-d396-4aab-ae9b-83c3a3f0fd72`
- **active:** `false`, **activeVersionId:** `null` (chưa publish — đúng yêu cầu "workflow không active")
- **Project/Folder:** `5cL5BKorhKAQ2ONI` / `ZdlLC9utIKkjLvhv` (`REFACTOR 2026-W39 (staging)`) — xác nhận qua
  `targetProject`/`targetFolder` trong response của `create_workflow_from_code`.
- **Tạo qua:** `create_workflow_from_code` (đã đọc `get_workflow_sdk_reference` + `validate_workflow` trả
  `{"valid":true,"nodeCount":2}` trước khi tạo).
- **Cấu trúc:** `Manual Trigger` (`n8n-nodes-base.manualTrigger` v1) → `Chạy Toàn Bộ DDL Migrations`
  (`n8n-nodes-base.postgres` v2.7, `operation: executeQuery`, `options: {}`, không dùng `queryReplacement`
  vì cả 7 query gốc + khối mới đều không có tham số `$1`/expression n8n).
- **Credential node Postgres:** `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}` — đúng
  ID/tên yêu cầu, copy trực tiếp vào `addNode`/SDK (không dùng `newCredential()` để tránh rủi ro resolve
  sai theo tên — RULES #25).
- **`autoAssignedCredentials`:** `[]` (rỗng) trong response `create_workflow_from_code` — không có node nào
  bị gán nhầm credential.
- Query trong node gồm đúng 8 khối theo thứ tự PLAN: 7 khối copy nguyên văn (mỗi khối có comment
  `-- [nguồn: <workflow> / <node>]` ngay phía trên, mỗi khối kết thúc bằng `;`) + 1 khối mới
  `gateway.error_alert_throttle` (bảng + index, đúng nguyên văn SQL trong PLAN mục 6 WP2 mục 2).
- **Không** `execute_workflow` workflow này ở bước nào.

### 3. So khớp lại bằng script (đọc lại `get_workflow_details` sau khi tạo)

Đọc lại `get_workflow_details(8XLg2q34VQq6IDx7)`, lưu `query` thực tế của node `Chạy Toàn Bộ DDL Migrations`
ra file, chạy script Python so từng ký tự (bỏ qua đúng 1 dòng trắng ngăn cách giữa các khối mà builder chủ
động thêm vào cho dễ đọc — không phải nội dung SQL) giữa mỗi khối trong workflow mới với file query gốc
tương ứng (`q1..q7_*.sql`) đã lưu ở bước 1:

| Khối | Khớp ký tự với nguồn? | Kết thúc bằng `;`? |
|---|---|---|
| 1. Gateway `Ensure Pending Uploads Table` | ✅ MATCH | ✅ |
| 2. Reader `Ensure Zalo Notify Column` | ✅ MATCH | ✅ |
| 3. Reader `Ensure Pending Upload Columns` | ✅ MATCH | ✅ |
| 4. Reader `Ensure Notify Queue Columns` | ✅ MATCH | ✅ |
| 5. Admin `Ensure Sync Table` | ✅ MATCH | ✅ |
| 6. Admin `Ensure Mention Tables (Admin)` | ✅ MATCH | ✅ |
| 7. TTLock `Ensure Schema (Lock)` (bản active) | ✅ MATCH | ✅ |

Toàn bộ query field của node (bao gồm cả khối mới `gateway.error_alert_throttle`) cũng khớp 100% với bản
dự định build cục bộ (`combined_ddl.sql`) — diff 0 dòng, sha256 hai bên giống hệt
(`f4ff91a46286fd893e168a45f6a497437b0cd5ae9f520d02b9fb2491971bf6a5`).

Credential đã xác nhận lại qua `get_workflow_details`: `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}`
— đúng như tạo, không bị ghi đè/auto-assign sai.

### 4. Đối chiếu whitelist lệnh cho phép (PLAN mục 5.2, auditor sẽ xác nhận lại độc lập)

- Khối 1, 5: `CREATE TABLE IF NOT EXISTS` — cho phép.
- Khối 2, 3, 4: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` — cho phép.
- Khối 6: 2× `CREATE TABLE IF NOT EXISTS` (viết trên 1 dòng, phân tách bằng `;` + khoảng trắng) — cho phép.
- Khối mới (error_alert_throttle): `CREATE TABLE IF NOT EXISTS` + `CREATE INDEX IF NOT EXISTS` — cho phép.
- **Khối 7 (TTLock `Ensure Schema (Lock)`) VI PHẠM whitelist**: ngoài 2 câu `CREATE TABLE IF NOT EXISTS`
  hợp lệ, còn có 1 câu `INSERT INTO gateway.ttlock_auth (id) VALUES (1) ON CONFLICT (id) DO NOTHING;` —
  **INSERT không nằm trong danh sách cho phép** (chỉ CREATE TABLE/ADD COLUMN/CREATE INDEX/CREATE SCHEMA
  IF NOT EXISTS). Theo đúng chỉ đạo "KHÔNG tự sửa, ghi Open question và vẫn đưa vào nhưng đánh dấu" — đã
  giữ nguyên văn 100%, đánh dấu tại đây và ở mục Open questions bên dưới. Không có tham số `$1`/expression
  n8n nào trong bất kỳ khối nào trong số 7 khối (toàn bộ là SQL tĩnh) — không phát sinh trường hợp cần đánh
  dấu "tham số/expression".

### Việc KHÔNG làm (đúng luật an toàn mục 5 + chỉ đạo giao việc)

- Không `execute_workflow` workflow staging vừa tạo (chờ auditor PASS trước, do Architect giao riêng).
- Không `update_workflow`/`publish_workflow`/`unpublish_workflow`/`archive_workflow` trên bất kỳ workflow
  production nào (Gateway, Reader, Admin, TTLock) — chỉ đọc.
- Không sửa/viết lại bất kỳ câu SQL nào kể cả câu INSERT sai whitelist trong khối TTLock.
- Không commit git.

### Open questions for architect

1. **Khối TTLock (`Ensure Schema (Lock)`) chứa 1 câu `INSERT` ngoài whitelist PLAN mục 5.2** (xem mục 4).
   Câu INSERT này dùng `ON CONFLICT (id) DO NOTHING` nên về hành vi là idempotent/an toàn để chạy lại nhiều
   lần, nhưng đây vẫn là **INSERT**, không phải 1 trong 4 loại lệnh được liệt kê rõ trong PLAN mục 5.2
   (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE SCHEMA
   IF NOT EXISTS`). Builder đã copy nguyên văn theo đúng chỉ đạo "copy NGUYÊN VĂN, không viết lại", KHÔNG
   tự xoá dòng INSERT này. Architect/auditor cần quyết định: (a) chấp nhận chạy nguyên văn (rủi ro thấp vì
   `ON CONFLICT DO NOTHING` + chỉ ghi 1 dòng cấu hình mặc định, không đụng dữ liệu người dùng), hay (b) yêu
   cầu builder xoá dòng INSERT khỏi bản STAGING trước khi audit PASS.
2. Không có câu hỏi mở nào khác — 4 workflow nguồn đều đọc được, không workflow nào phát sinh bản nháp mới
   ngoài TTLock (đã biết từ WP0, đúng D3).

## WP2 fix #1 — bỏ INSERT khỏi khối TTLock — 2026-09-25T01:49:20Z

Architect quyết định Open question 1 (b): xoá câu `INSERT INTO gateway.ttlock_auth (id) VALUES (1) ON
CONFLICT (id) DO NOTHING;` khỏi khối 7, thay bằng comment `-- [bỏ theo PLAN 5.2: INSERT seed
ttlock_auth(id=1) vẫn do TTLock/Ensure Schema (Lock) tự chạy]`. Chỉ sửa workflow staging `8XLg2q34VQq6IDx7`
— không đụng workflow TTLock production.

- **Cách áp dụng:** theo RULES #16 — `removeNode` + `addNode` (cùng `id`
  `09a700fa-9ac5-48ed-af0c-9634826ab025`, copy nguyên `parameters`/`credentials`/`position`, chỉ thay 1
  dòng trong `query`) + `addConnection` lại `Manual Trigger → Chạy Toàn Bộ DDL Migrations`, cả 3 op trong
  1 batch `update_workflow`. Response: `appliedOperations: 3`, `autoAssignedCredentials: []`,
  `validationWarnings: []`.
- **versionId mới:** `76f2cb7e-22d8-4a29-81da-e234b69a7825` (active vẫn `false`, `activeVersionId: null`).
- **Re-read + so khớp bằng script** (`get_workflow_details` → so ký tự):
  - Khối 1–6 (Gateway, Reader×3, Admin×2) và khối mới `gateway.error_alert_throttle`: **MATCH**, không đổi
    1 ký tự nào so với BUILD_LOG gốc.
  - Khối 7 (TTLock): **MATCH** với "bản gốc trừ đúng 1 dòng INSERT, thay bằng dòng comment" — không có sai
    khác nào khác ngoài đúng thay đổi được yêu cầu (kiểm bằng diff toàn văn: chỉ 1 dòng khác giữa bản
    trước/sau fix).
  - sha256 toàn bộ `query` sau fix: `8aadb699e199e69bf0f10eb0651f8e9f3fdc8d18250e1e0e429f8954f0e5461e`.
- **Credential:** đọc lại `get_workflow_details` — vẫn `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres
  account"}}`, `autoAssignedCredentials: []` (không có node nào bị gán nhầm).
- **Connection:** `Manual Trigger → Chạy Toàn Bộ DDL Migrations` (index 0/0) — còn nguyên sau
  `removeNode`+`addNode`.
- **Không** `execute_workflow` workflow này ở bước nào của fix.

### Open questions for architect

Không có câu hỏi mở mới.

## WP1 — GW Error Handler v2 — 2026-09-25T01:57:30Z

### 1. Đọc v1 (`34ccboHpyoY2r691`, chỉ đọc) — định dạng `Format lỗi` + credentials

v1 gồm 4 node: `Error Trigger` → `Format lỗi` (**Code node**, `n8n-nodes-base.code` v2) → nối song song tới
`Báo admin Telegram` (`n8n-nodes-base.telegram` v1.2) và `Log Error To DB` (`n8n-nodes-base.postgres` v2.7,
INSERT đơn giản, không throttle).

- **Định dạng `text` v1** (dựng bằng template literal trong Code node):
  ```
  🚨 LỖI WORKFLOW
  📋 ${wf}
  📍 Node: ${node}
  ❌ ${String(msg).slice(0, 500)}
  🔗 ${url}
  ```
  với `wf = e.workflow?.name || 'unknown'`, `node = e.execution?.lastNodeExecuted || e.trigger?.error?.node?.name || '?'`,
  `msg = e.execution?.error?.message || e.trigger?.error?.message || 'unknown error'`, `url = e.execution?.url || ''`.
  Các field phụ trợ: `workflowName`, `workflowId`, `nodeName`, `errorMessage` (cắt 2000 ký tự — khác 500 ký
  tự dùng trong `text`), `executionId`, `executionUrl`.
- **Cách v2 tái tạo bằng expression** (Set node `Chuẩn Hoá Lỗi`, không Code): mỗi field trên map 1-1 sang 1
  assignment kiểu `string`, dùng `?.` + `||` y hệt logic v1; riêng `text` là 1 string field chứa nhiều
  `{{ ... }}` xen kẽ text/emoji cố định (đúng cách Set node xử lý nhiều expression trong 1 field), tái tạo
  đúng nguyên văn 5 dòng trên (dùng field `execution?.error?.message` cắt 500 ký tự cho dòng `❌`, không
  dùng lại `errorMessage` đã cắt 2000 — khớp hành vi v1 nơi `text` và `errorMessage` cắt độ dài khác nhau).
- **Credentials v1** (copy nguyên cho v2):
  - Telegram: `{"telegramApi":{"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}}`, chatId
    `-1003647848349`, `additionalFields`: `{"appendAttribution": false, "message_thread_id": 4}` (v1 KHÔNG
    có `parse_mode`/`disable_web_page_preview` — giữ nguyên `appendAttribution: false` sang v2 vì đây là
    additionalField v1 thật sự có).
  - Postgres: `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}`.
  - v1 KHÔNG có `retryOnFail`/`maxTries`/`waitBetweenTries`/`alwaysOutputData` trên Telegram lẫn Postgres —
    đây là điểm v2 CHỦ ĐỘNG khác v1 theo đúng spec PLAN WP1.

### 2. Workflow staging đã tạo

- **Tên:** `GW Error Handler v2 (STAGING)`
- **workflowId:** `MaoEB8w8Un6UA01n`
- **versionId (sau khi fix credential):** `c4f05b7d-0a9c-48c1-b832-25e3637ea69e`
- **active:** `false`, **activeVersionId:** `null` (chưa publish/không active — đúng spec)
- **Project/Folder:** `5cL5BKorhKAQ2ONI` / `ZdlLC9utIKkjLvhv` (`REFACTOR 2026-W39 (staging)`) — xác nhận qua
  `targetProject`/`targetFolder` của `create_workflow_from_code`.
- **Tạo qua:** `create_workflow_from_code` (đã đọc `get_workflow_sdk_reference` trước; `validate_workflow`
  trả `{"valid":true,"nodeCount":5}` trước khi tạo).
- **5 node, đúng cấu trúc PLAN:**
  1. `Error Trigger` (`n8n-nodes-base.errorTrigger` v1).
  2. `Chuẩn Hoá Lỗi` (`n8n-nodes-base.set` v3.4, `mode: manual`, `includeOtherFields: false`, 7 assignment:
     `workflowName`, `workflowId`, `nodeName`, `errorMessage`, `executionId`, `executionUrl`, `text` — đúng
     expression trong spec PLAN WP1).
  3. `Ghi Lỗi + Kiểm Tra Gộp` (`n8n-nodes-base.postgres` v2.7, `operation: executeQuery`, SQL CTE đúng
     nguyên văn PLAN (`ins_log` INSERT `gateway.error_logs` RETURNING id + `thr` INSERT
     `gateway.error_alert_throttle` ON CONFLICT DO UPDATE suppressed_count RETURNING `xmax = 0` AS
     is_first), `queryReplacement` đúng nguyên văn spec).
  4. `Cần Gửi Cảnh Báo?` (`n8n-nodes-base.if` v2.3, 1 điều kiện `boolean equals` trên
     `{{ $json.should_alert }}` so với `true`).
  5. `Báo admin Telegram` (`n8n-nodes-base.telegram` v1.2, `resource: message`, `operation: sendMessage`,
     `text` tham chiếu tường minh `={{ $('Chuẩn Hoá Lỗi').first().json.text }}` — RULES #2).

### 3. Settings node — SDK có đặt được, xác nhận qua re-read

Thử đặt `retryOnFail`/`maxTries`/`waitBetweenTries`/`alwaysOutputData`/`onError` trực tiếp trong `config`
của `node()` khi gọi `create_workflow_from_code` (không phải `addNode` qua `update_workflow`, nên KHÔNG bị
luật "settings bị bỏ qua trong addNode" áp dụng). Re-read bằng `get_workflow_details` sau khi tạo xác nhận
SDK **đặt được** ngay từ lần tạo đầu, không cần `setNodeSettings` bổ sung:

| Node | retryOnFail | maxTries | waitBetweenTries | alwaysOutputData | onError |
|---|---|---|---|---|---|
| `Ghi Lỗi + Kiểm Tra Gộp` | `true` ✅ | `3` ✅ | `2000` ✅ | `true` ✅ | `continueRegularOutput` ✅ |
| `Báo admin Telegram` | `true` ✅ | `3` ✅ | `5000` ✅ | *(không đặt — đúng spec, spec chỉ liệt kê retry+onError cho node này)* | `continueRegularOutput` ✅ |

Workflow settings sau khi tạo: `{"executionOrder":"v1","availableInMCP":true}` — **không có `errorWorkflow`**
(đúng spec "không đặt errorWorkflow cho chính nó").

### 4. `autoAssignedCredentials` — phát hiện sai, đã sửa

`create_workflow_from_code` KHÔNG gán credentials trong code (không dùng `newCredential()` vì SDK không xác
nhận rõ cách gán ID có sẵn) → n8n auto-assign nhầm theo user: Postgres → `Supabase Postgres`
(`hO4yfw7ailV7jHAv`), Telegram → `@csfsintbot` (`ULzoIY1vw0zMeOTk`). Phát hiện ngay trong response tạo
workflow (`autoAssignedCredentials` không rỗng) → sửa ngay bằng `update_workflow` (`setNodeCredential` ×2,
cùng 1 batch) sang đúng credential production: `Ghi Lỗi + Kiểm Tra Gộp` → `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}`,
`Báo admin Telegram` → `{"telegramApi":{"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}}`. Response:
`appliedOperations: 2`, `autoAssignedCredentials: []`, `validationWarnings: []`. Re-read `get_workflow_details`
sau fix xác nhận cả 2 credential đúng ID/tên yêu cầu.

### 5. Kiểm tra đã làm

- **0 Code node:** 5 node = `errorTrigger`, `set`, `postgres`, `if`, `telegram` — không có
  `n8n-nodes-base.code` nào.
- **Connections đúng:** `Error Trigger → Chuẩn Hoá Lỗi → Ghi Lỗi + Kiểm Tra Gộp → Cần Gửi Cảnh Báo?` rồi chỉ
  output `main[0]` (true) nối tới `Báo admin Telegram`; `main[1]` (false) không xuất hiện trong `connections`
  → không nối, đúng spec.
- **Credentials đúng + `autoAssignedCredentials` rỗng:** xác nhận ở mục 4 (sau fix).
- **`validate_workflow` (SDK code):** chạy trước khi tạo, trả `{"valid":true,"nodeCount":5}`. Không có tool
  "validate theo workflowId" trong bộ MCP n8n chính thức đang dùng phiên này (chỉ có `validate_workflow` theo
  code SDK, không có biến thể theo ID) — coi `validationWarnings: []` trong response `update_workflow` (sau
  fix credential, là lần sửa cuối cùng trên workflow) là xác nhận tương đương ở phía server.
- **Re-read toàn bộ JSON** bằng `get_workflow_details(detailLevel: full)` sau bước fix credential — mọi
  `parameters`/`credentials`/`settings`/`connections` đúng như liệt kê ở mục 2–4, không có sai lệch.

### Rủi ro đã ghi theo yêu cầu giao việc

- Nếu node Postgres `Ghi Lỗi + Kiểm Tra Gộp` lỗi (vd mất kết nối DB) và `onError: continueRegularOutput` với
  `alwaysOutputData: true` kích hoạt, item đi tiếp tới `Cần Gửi Cảnh Báo?` sẽ **không có field `should_alert`**
  (vì query không chạy được) → điều kiện `{{ $json.should_alert }}` bằng `true` sẽ là `false`/undefined →
  nhánh Telegram **không chạy** trong trường hợp Postgres lỗi. Đây là hành vi hợp lý theo tinh thần "ghi DB
  trước" của PLAN (không gửi cảnh báo nếu chưa chắc đã ghi được log), nhưng nghĩa là **khi chính node ghi
  lỗi bị lỗi, admin sẽ không nhận được tin Telegram nào cho execution đó** — tester nên có 1 case kiểm tra
  riêng hành vi này (không có trong bảng ERR-01..05 hiện tại của PLAN mục 7.4).

### Việc KHÔNG làm

- Không `publish_workflow`/`execute_workflow`/`archive_workflow` trên `MaoEB8w8Un6UA01n` (chờ auditor rồi
  tester).
- Không đụng workflow production `34ccboHpyoY2r691` (chỉ `get_workflow_details` đọc 1 lần ở bước 1).
- Không commit git.

### Open questions for architect

- Không có câu hỏi cần dừng WP1. Một điểm cần auditor/tester lưu ý: xem mục "Rủi ro đã ghi theo yêu cầu
  giao việc" ở trên (Postgres lỗi → should_alert vắng mặt → không có tin Telegram cho execution đó) — nên bổ
  sung 1 test case (đề xuất mã `ERR-06`) pin node Postgres ra lỗi và xác nhận hành vi này là chủ đích trước
  khi WP1 được đánh READY FOR CUTOVER.

## WP1 fix #1 — fail-open IF khi Postgres lỗi — 2026-09-25T02:02:16Z

Theo AUDIT_REPORT.md audit #1 (FAIL, blocking #1) + PLAN mục 6 WP1 bước 4 đã cập nhật. Sửa DUY NHẤT trên
`MaoEB8w8Un6UA01n`, node `Cần Gửi Cảnh Báo?`.

- **Cách áp dụng:** `update_workflow` với `setNodeParameter` (path `/conditions/conditions/0/leftValue`) —
  **ăn ngay lần đầu**, không cần fallback `removeNode`+`addNode`. `appliedOperations: 1`,
  `autoAssignedCredentials: []`, `validationWarnings: []`.
- **leftValue mới:** `={{ $json.should_alert === true || !$json.log_id }}` — giữ nguyên `operator:
  {"type":"boolean","operation":"equals"}`, `rightValue: true`, `options.typeValidation: "strict"` (biểu
  thức luôn trả boolean nên strict vẫn hợp lệ).
- **versionId mới:** `4f7d5a4b-c6e3-436a-be87-b85793b039bf` (`active:false`, `activeVersionId:null`).
- **Re-read `get_workflow_details` xác nhận:**
  - `leftValue` đúng vị trí `parameters.conditions.conditions[0].leftValue` trên node `Cần Gửi Cảnh Báo?`.
  - Connections không đổi: `Error Trigger→Chuẩn Hoá Lỗi→Ghi Lỗi + Kiểm Tra Gộp→Cần Gửi Cảnh Báo?
    →Báo admin Telegram` (output 0), output 1 vẫn không nối.
  - Settings 4 node còn lại không đổi: Postgres `retryOnFail:true,maxTries:3,waitBetweenTries:2000,
    alwaysOutputData:true,onError:continueRegularOutput`; Telegram `retryOnFail:true,maxTries:3,
    waitBetweenTries:5000,onError:continueRegularOutput`; workflow settings vẫn
    `{"executionOrder":"v1","availableInMCP":true}` (không `errorWorkflow`).
  - Credentials không đổi: Postgres `{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}`, Telegram
    `{"id":"zSZ6vVapow5LNpFT","name":"Telegram System Bot"}`. `autoAssignedCredentials: []`.
  - Vẫn 0 node `n8n-nodes-base.code` (5 node như cũ, chỉ đổi 1 field).

**Không** `publish_workflow`/`execute_workflow` ở bước fix này. Không đụng production.

### Open questions for architect

Không có câu hỏi mở mới. Đề nghị tester thêm ERR-06 (pin Postgres trả lỗi → xác nhận có 1 lần gọi Telegram)
như audit #1 đã ghi.

## WP3 — GW Gateway v2 — 2026-09-25T02:13:31Z

- Staging workflow: `GW Gateway - Telegram v2 (STAGING)` (`hn0YZ85sXtfGACJ4`), folder `REFACTOR 2026-W39 (staging)` (`ZdlLC9utIKkjLvhv`), project `5cL5BKorhKAQ2ONI`. Final versionId `dbc644d4-7c8a-44e5-90dd-ec18b9aab157`. `active: false` (never published, no cutover). Telegram Trigger node present but inactive — workflow not published, no webhook re-registration risk.
- Source (cloned): `xmEKeIUnzxm2F7dF` @ `activeVersionId` `180005b7-a44a-4c95-ace6-24529ae46566` — matches PLAN §3 expected value exactly (confirmed before AND after all work: still `versionId == activeVersionId == 180005b7-...`, `updatedAt` unchanged at `2026-09-23T08:34:37.511Z`, production untouched).
- Build method: read full v1 JSON via `get_workflow_details`, wrote it verbatim to a scratch file (patched only to restore full Vietnamese comment blocks in `⚙️ Config`/`GW-03 Router` jsCode that got trimmed on first transcription — fixed via python before use, verified against original tool output). Generated addNode/setNodeSettings/addConnection op lists with a script, applied via 2 `update_workflow` calls on a placeholder created with `create_workflow_from_code`:
  - Batch 1: 48 `addNode` (id/parameters/credentials/position/typeVersion preserved, `webhookId` omitted) + 18 `setNodeSettings` (nodes carrying `onError`/`alwaysOutputData`/`retryOnFail`/`maxTries`/`waitBetweenTries`) — 66 ops, `autoAssignedCredentials: []`.
  - Batch 2: 48 `addConnection` (`sourceIndex`/`targetIndex` from v1's connections object) + `removeNode` of the SDK placeholder trigger — 49 ops, `autoAssignedCredentials: []`, 0 `validationWarnings`.
  - `setWorkflowSettings`: `errorWorkflow=34ccboHpyoY2r691`, `callerPolicy=workflowsFromSameOwner`, `executionOrder=v1`.
- Clone diff (script comparing full v1 vs cloned v2 JSON, before any C1–C4 change): **identical** — 48/48 nodes matched on name, type, typeVersion, parameters (jsCode diffed char-for-char including comments), credentials, and the settings keys (onError/alwaysOutputData/retryOnFail/maxTries/waitBetweenTries); connections object byte-identical. Only differences: node `id`s were kept identical to v1 (not regenerated), so the only actual differences were `webhookId` (new, as required — old one omitted) and workflow-level settings `binaryMode`/`timeSavedMode` (present in v1, not present in v2 — `setWorkflowSettings` tool schema doesn't expose these two fields; not set explicitly, left at instance default, not verified further; flagged below). Result: **PASS**, proceeded to step 4.
- Changes applied (C1–C4), each its own `update_workflow` call, re-read via `get_workflow_details` after every one:
  - **C1**: `removeNode` × 2 — `Audit Log (Supabase)` and `Tạo pending user (Supabase)` (both wrote to the same Docker Postgres DB via credential `Postgres account`, duplicating `Audit Log (Docker)` / `Tạo pending user`; F5). Both were parallel dead-end branches (off `GW-01 Envelope` and `Trạng thái user?` output 0 respectively) — no reconnection needed. Verified: node count 48→46, no other connections changed.
  - **C2**: confirmed in v1 JSON that `Trạng thái user?` output index 3 (rule order new/pending/denied/active) fed `Ensure Pending Uploads Table` — matches spec's "output 3 = active" exactly, no Open question needed. `removeNode Ensure Pending Uploads Table` + `addConnection Trạng thái user? (index 3) → GW-04 Check Pending Upload (index 0)`. Confirmed `GW-04 Check Pending Upload` still carries `alwaysOutputData: true` (inherited from clone, RULES #18). Verified via re-read: connection present, node count 46→45.
  - **C3**: `⚙️ Config` jsCode only returned 4 static constants (`ADMIN_CHAT_ID`, `AVAILABLE_BOTS`, `COMMAND_MAP`, `DEFAULT_BOT`) — no `$json` reads, no computation — so no Open question needed. Grepped all downstream references: `GW-03 Router` (`cfg.COMMAND_MAP[...]`, `cfg.DEFAULT_BOT`), `Báo admin duyệt user` (`ADMIN_CHAT_ID`), `Báo Admin Cấp Quyền Lock` (`ADMIN_CHAT_ID`) — no others found. Replaced via `removeNode`+`addNode` (same id `a1abefb7-...`) with `n8n-nodes-base.set` v3.5, `mode: manual`, `includeOtherFields: false`, 4 typed assignments copied verbatim from v1 code:
    ```json
    ADMIN_CHAT_ID (string) = "975005174"
    AVAILABLE_BOTS (array) = "={{ ['telebot_main', 'help_bot', 'image_bot', 'lock_bot'] }}"
    COMMAND_MAP (object) = "={{ { task:'telebot_main', t:'telebot_main', start:'telebot_main', help:'telebot_main', cancel:'telebot_main', lichsu:'telebot_main', timkiem:'telebot_main', sum:'telebot_main', ask:'help_bot', xoanen:'image_bot', tomtat:'image_bot', mokhoa:'lock_bot' } }}"
    DEFAULT_BOT (string) = "help_bot"
    ```
    Kept `retryOnFail: true, maxTries: 5, waitBetweenTries: 5000` via `setNodeSettings` in the same batch. Reconnected `Telegram Trigger Gateway → ⚙️ Config → GW-01 Envelope` (both dropped by `removeNode`) in the same batch. Verified via re-read: node type/typeVersion/parameters/settings/connections all present and correct.
  - **C4**: confirmed `const env = $input.first().json;` exists verbatim, exactly once, in v1's `GW-03 Router` jsCode, and `GW-04b Merge Pending` does nothing beyond merging `pendingUpload` (no Open question needed). `removeNode GW-04b Merge Pending` + `removeNode`+`addNode` (same id `dff6f80d-...`) for `GW-03 Router` with the one line replaced by the 3-line spec block; script-diffed old vs new jsCode line-by-line confirming **only that line changed, rest byte-identical**. Router has no `mode` param (defaults to `runOnceForAllItems`, unchanged from v1 — code correctly reads `$input.all()` now, matching the "all items" execution mode). Reconnected `GW-04 Check Pending Upload → GW-03 Router → Route bot?` (both dropped by the two `removeNode`s) in the same batch. Verified via re-read: jsCode, connections, node count 45→44 all correct.
- References rewritten: none outside C3/C4 scope — `$('⚙️ Config')` references (`GW-03 Router`, `Báo admin duyệt user`, `Báo Admin Cấp Quyền Lock`) still resolve by node name (unchanged) and now read `COMMAND_MAP`/`AVAILABLE_BOTS` as native object/array types from the Set node's typed assignments (same as before, where the Code node returned native JS object/array).
- Verified by re-read: `get_workflow_details` (detailLevel full) after every `update_workflow` call; final full-workflow script diff against v1 confirms the ONLY differences are: 4 removed nodes (exactly C1's 2 + C2's 1 + C4's 1), `⚙️ Config` type/typeVersion/parameters (C3), `GW-03 Router` parameters (C4, single-line diff confirmed), and the connection-object changes implied by those 4 removals + C2/C4 rewiring. No other node (type/typeVersion/parameters/credentials/settings) differs from v1. `autoAssignedCredentials` was `[]` on every `update_workflow` call. Workflow settings: `errorWorkflow`/`callerPolicy`/`executionOrder` match v1; `binaryMode`/`timeSavedMode` not settable via this MCP server's `setWorkflowSettings` schema, left unset (not independently verified against instance default — see open question). v2 `active: false` confirmed; v1 production `versionId == activeVersionId == 180005b7-...` reconfirmed unchanged after all work.
- Open questions for architect: none blocking. One non-blocking note: workflow-level settings `binaryMode: "separate"` and `timeSavedMode: "fixed"` (present on v1) have no exposed field in this MCP server's `update_workflow`/`setWorkflowSettings` schema, so v2 was left without them set explicitly — likely inherits instance default (n8n's default `binaryMode` is `"separate"`), but this was not independently confirmed via any tool and should be checked by auditor/tester if it matters for parity testing (GW-P1/GW-S1 in PLAN §7.3), or via a direct UI check before cutover.
