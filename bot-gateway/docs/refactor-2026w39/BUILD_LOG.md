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
