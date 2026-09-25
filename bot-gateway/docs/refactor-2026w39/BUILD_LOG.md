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
