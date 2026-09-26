# Baseline production trước cutover — refactor 2026-W39

> Lấy số liệu để so sánh trước/sau cutover Chủ Nhật 27/09/2026 19:00–22:00 giờ VN (mục 8 `PLAN.md`).
> Chỉ đọc: không update/publish/unpublish/archive workflow production hay staging, không gửi Telegram
> thật, SQL chỉ SELECT. 1 workflow TEMP đã dùng cho SQL, đã archive ngay sau khi lấy đủ số liệu (xem mục 6).

## 1. Mốc thời gian

- Thời điểm chạy (`date -u`): **2026-09-26T06:21:37Z** = **13:21:37 giờ VN, Thứ Bảy 26/09/2026**.
- Cửa sổ baseline 7 ngày: **[2026-09-19T06:21:37Z, 2026-09-26T06:21:37Z)** UTC
  = **[19/09/2026 13:21:37, 26/09/2026 13:21:37)** giờ VN.
- Mốc tách "trước/sau fix task runner" (F4, áp dụng sáng 25/09): dùng đúng **2026-09-25T00:00:00+07:00
  = 2026-09-24T17:00:00Z**.
- Khung cutover đang xét: Chủ Nhật 27/09/2026 19:00–22:00 giờ VN (14:00–17:00 UTC/giờ Đức).

## 2. Phương pháp, cỡ mẫu, giới hạn

**Công cụ:** n8n MCP (`search_workflow_executions`, `get_workflow_execution`), Postgres qua 1 workflow
TEMP (Manual Trigger → 3 node Postgres `executeQuery`, chỉ SELECT).

- **Đếm chính xác:** `search_workflow_executions` với `limit:1` trả về trường `count` (`estimated:false`)
  — dùng cho mọi số đếm theo status/ngày/giờ, không cần phân trang.
- **Thời gian chạy:** `stoppedAt − startedAt` (ms), tính bằng script Python trong scratchpad, không tính
  nhẩm.
- **Gateway (`xmEKeIUnzxm2F7dF`) — 2 ngày cuối (24/09 06:21 UTC → hết cửa sổ, 26/09 06:21 UTC):** lấy
  **toàn bộ** 494 execution qua phân trang (không mẫu), vì đây là giai đoạn chứa mốc fix runner và mọi
  hoạt động build/test refactor. Loại `mode:"manual"` (84 execution — toàn bộ là `test_workflow` của WP1/WP3,
  không phải traffic thật) → còn **410 execution `mode:"webhook"` thật**.
- **Gateway — 5 ngày đầu (19/09 06:21 → 24/09 06:21 UTC):** đếm theo ngày bằng count-trick (chính xác);
  p50/p95 thời gian chạy dùng **mẫu 20–25 execution/ngày** (không phải 100 như dự kiến ban đầu trong
  PLAN — giảm cỡ mẫu để tiết kiệm lượt gọi, ghi rõ ở đây theo yêu cầu). Mẫu lấy là các execution **gần
  cuối ngày nhất** (không ngẫu nhiên), có thể lệch nếu traffic phân bố không đều trong ngày. Xác nhận:
  0 execution `mode:"manual"` trong 5 ngày này (mọi test refactor đều nằm trong 2 ngày cuối).
- **Phân bố theo giờ VN:** tính **chính xác** cho 2 ngày cuối (410 execution đầy đủ). Không dựng histogram
  đầy đủ 7×24h cho 5 ngày đầu (không đủ ngân sách gọi tool); riêng khung Chủ Nhật 20/09 19:00–22:00 VN
  (=12:00–15:00 UTC) được đếm **chính xác riêng** bằng count-trick.
- **7 workflow WP5 + Error Handler:** đếm exec/error/crashed bằng count-trick (chính xác, không mẫu).
- **`gateway.error_logs`:** SELECT qua workflow TEMP `2xVOmDrN6Rm49ZbE` (folder `ZdlLC9utIKkjLvhv`,
  project `5cL5BKorhKAQ2ONI`), credential `{"postgres":{"id":"GwUFREmcXzXXj5mZ","name":"Postgres account"}}`
  — đã kiểm `autoAssignedCredentials` rỗng và `get_workflow_details` xác nhận đúng credential trên cả 3
  node trước khi chạy bằng `test_workflow`. Loại `id BETWEEN 57 AND 79` (dòng test ERR-01/02/04/05/07 của
  WP1, theo `TEST_REPORT.md`). Đã `archive_workflow` ngay sau khi lấy xong số liệu.
- **Loại trừ chung:** mọi execution `mode:"manual"` (test_workflow), workflow TEMP/STAGING không tính vào
  số liệu production.
- **Không bị chặn bởi safety/permission** — mọi lệnh trong nhiệm vụ này chạy được (chỉ đọc + 1 TEMP SQL
  read-only), không có chỉ số nào bị bỏ vì lý do an toàn.

## 3. Gateway v1 (`xmEKeIUnzxm2F7dF`)

### 3.1 Tổng 7 ngày (chỉ `mode:"webhook"` — traffic thật)

| Chỉ số | Giá trị |
|---|---|
| Tổng execution (kể cả 84 test `mode:"manual"`) | 1286 |
| Execution thật (`mode:"webhook"`) | **1202** |
| — success | 1197 |
| — error | 5 |
| — crashed | 0 |
| Tỉ lệ lỗi (error/tổng thật) | **0,42%** |

Toàn bộ 5 lỗi (id `7113,7112,7111,7110,6762`) xảy ra trong cụm sự cố **23/09 04:59–08:27 UTC** (xem mục 4,
5 — cùng cụm với lỗi của Live Update/Admin/Reader/Error Handler).

### 3.2 Theo ngày (mốc UTC; giờ VN = UTC+7)

| Ngày (UTC) | Giờ VN tương ứng | Exec | Success | Error | p50 (ms) | p95 (ms) | Cỡ mẫu |
|---|---|---|---|---|---|---|---|
| 19/09 06:21→20/09 06:21 | 19/09 13:21→20/09 13:21 | 140 | 140 | 0 | ~123 | ~1808 | mẫu 20/140 |
| 20/09 06:21→21/09 06:21 | 20/09 13:21→21/09 13:21 (chứa tối CN) | 25 | 25 | 0 | ~1608 | ~1856 | toàn bộ 25 |
| 21/09 06:21→22/09 06:21 | 21/09 13:21→22/09 13:21 | 264 | 264 | 0 | ~1554 | ~1890 | mẫu 20/264 |
| 22/09 06:21→23/09 06:21 | 22/09 13:21→23/09 13:21 | 230 | 225 | 5 | ~173 | ~1730 | mẫu 20/225 success |
| 23/09 06:21→24/09 06:21 | 23/09 13:21→24/09 13:21 | 133 | 133 | 0 | ~1603 | ~1805 | mẫu 20/133 |
| 24/09 06:21→26/09 06:21 (2 ngày cuối) | 24/09 13:21→26/09 13:21 | 410 | 410 | 0 | — | — | **toàn bộ, không mẫu** |

### 3.3 Trước/sau mốc fix task runner (00:00 giờ VN 25/09 = 17:00 UTC 24/09)

Tính **chính xác** (không mẫu) trên toàn bộ 410 execution `webhook` của 2 ngày cuối, cắt đúng tại
`2026-09-24T17:00:00Z`:

| Giai đoạn | n | p50 (ms) | p95 (ms) | max (ms) |
|---|---|---|---|---|
| Trong 2 ngày cuối, **trước** 00:00 VN 25/09 (24/09 06:21→17:00 UTC) | 98 | **1595,5** | 1907,0 | 2424 |
| **Từ** 00:00 VN 25/09 (17:00 UTC 24/09 → hết cửa sổ) | 312 | **93,0** | 196,2 | 2336 |

Ranh giới rất sắc: execution cuối cùng trước mốc dừng ở `2026-09-24T15:23:58Z`, execution đầu tiên sau
mốc là `2026-09-24T17:11:19Z` — đúng như PLAN ghi "fix task runner áp dụng sáng 25/09". p50 giảm từ
~1,6s xuống ~93ms (**-94%**). Khớp với 5 ngày đầu (mục 3.2): mọi ngày trước mốc đều có p50 mẫu dao động
1,5–1,6s (trừ ngày 1, thấp hơn — có thể do traffic không đồng nhất trong ngày, xem giới hạn mục 2), còn
p95 luôn quanh 1,7–1,9s do runner phải cold-start.
⚠️ **Giới hạn:** 1 outlier 2336ms sau mốc fix (trong 312 execution) — không loại nhiễu, giữ nguyên p95/max
thật để không đánh giá quá lạc quan.

### 3.4 Phân bố theo giờ VN (chính xác, 410 execution webhook của 2 ngày cuối)

| Giờ VN | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Exec | 4 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 9 | 12 | 15 | 9 | 3 | 7 | 42 | 35 | 33 | 41 | 65 | 25 | 6 | 89 | 13 | 0 |

Giờ 21 VN cao bất thường (89) — đây là 2 ngày build/test refactor (24–26/09), không đại diện traffic
người dùng thông thường; không dùng ngày này để suy luận hành vi giờ đêm. Giờ 0–7 VN gần như 0.

**Chủ Nhật 20/09/2026, 19:00–22:00 giờ VN (=12:00–15:00 UTC 20/09) — đếm chính xác riêng:**

| Chỉ số | Giá trị |
|---|---|
| Execution Gateway trong khung này | **0** |

Xác nhận đúng nhận định trong PLAN §2 (D7): "14 ngày qua khung này có 0 request".

## 4. 7 workflow WP5 + Gateway — exec/error 7 ngày, errorWorkflow hiện tại

| Workflow | ID | Exec (7 ngày, mọi mode) | Error | Crashed | Có `errorWorkflow` hiện tại? |
|---|---|---|---|---|---|
| GW Gateway - Telegram (DEV) | `xmEKeIUnzxm2F7dF` | 1286 (1202 thật) | 5 | 0 | **CÓ** (→ `34ccboHpyoY2r691`) |
| SQL - ClickUp Live Update | `uqTqjtHYieotPZuc` | 673 | 93 | 0 | **CÓ** |
| SQL - ClickUp Full Reconcile | `G1R0okF0rUziySu9` | 3 | 0 | 0 | **CÓ** |
| Interview Evaluation | `oF4IWJf6Yad2wF5G` | 19 | 0 | 0 | **CÓ** |
| Telebot Admin System | `eWtu7Qs85Hes0HuP` | 47 | 4 | 0 | **KHÔNG** |
| Telebot ClickUp Reader | `9JJRrh36H2rLwtnu` | 154 | 1 | 0 | **KHÔNG** |
| Bot Xử Lý Ảnh | `6I4MnJiJCiv2JOIr` | 31 | 6 | 0 | **KHÔNG** |

**"Lỗi không được báo"** = lỗi của 3 workflow chưa có handler = 4 (Admin) + 1 (Reader) + 6 (Ảnh) =
**11 execution lỗi trong 7 ngày không có error handler nào chạy** → không có dòng `error_logs`, không có
tin Telegram nào được gửi cho 11 lỗi này. Đây là số baseline mà WP5 (gắn `errorWorkflow` cho 3 workflow
này) phải xoá bỏ về 0.

6 lỗi của Bot Xử Lý Ảnh trùng đúng với các sự cố OCR đã biết trong PLAN (exec `7931`, `7540`, `8000`,
`8016` nằm trong REG-OCR-01/02).

## 5. GW Error Handler v1 (`34ccboHpyoY2r691`)

| Chỉ số | Giá trị |
|---|---|
| Tổng execution 7 ngày | 98 |
| Execution lỗi (chính handler bị lỗi) | **42** (43%) |
| Execution thành công | 56 |

98 = đúng bằng tổng lỗi của Gateway (5) + Live Update (93) — 2 workflow duy nhất trong tuần có lỗi và
đang trỏ `errorWorkflow` về v1.

**Trích 2 execution lỗi** (exec `7130`, `7004`, cả 2 nằm trong cụm sự cố 23/09 04:59–08:27 UTC):

- Cả 2 đều lỗi tại node **"Báo admin Telegram"**: `429 - {"ok":false,"error_code":429,"description":"Too
  Many Requests: retry after 5","parameters":{"retry_after":5}}`.
- Lỗi gốc (kích hoạt Error Trigger) của cả 2 là **"Task request timed out"** (task runner) — trên node
  `⚙️ Config` (Gateway, exec cha `7112`) và `⚙️ Config (Admin Chat ID)` (Live Update, exec cha `6967`).
- **Phát hiện quan trọng:** trong v1, thứ tự node là `Format lỗi → Báo admin Telegram → Log Error To DB`
  (Telegram **trước** Postgres). Khi Telegram lỗi 429, workflow dừng luôn (không có `onError`/error output)
  → node `Log Error To DB` **không bao giờ chạy** → dòng `error_logs` cũng bị mất theo, không chỉ mất tin
  Telegram. Đây chính là lý do WP1 v2 đảo thứ tự (ghi DB trước).

**Ước lượng "cảnh báo bị mất":** 42 tin Telegram **và** 42 dòng `error_logs` bị mất (khớp chính xác với số
liệu mục 6: 98 lỗi gốc − 56 dòng `error_logs` = 42).

## 6. `gateway.error_logs` (SELECT qua TEMP `2xVOmDrN6Rm49ZbE`, đã archive)

Schema xác nhận cột thời gian là `occurred_at` (không phải `created_at` như dự kiến ban đầu trong lệnh
giao việc — đã tự sửa 3 câu SQL sau khi kiểm `information_schema.columns`).

### 6.1 Theo workflow (7 ngày, loại `id 57–79` test WP1)

| workflow_name | Tổng dòng | Trước 25/09 00:00 VN | Từ 25/09 00:00 VN | chứa "runner" (trước) | chứa "runner" (từ 25/09) |
|---|---|---|---|---|---|
| SQL - ClickUp Live Update (Webhook) | 52 | 52 | 0 | 26 | 0 |
| GW Gateway - Telegram (DEV) | 4 | 4 | 0 | 0 | 0 |
| **Tổng** | **56** | 56 | 0 | 26 | 0 |

**0 dòng `error_logs` mới từ 25/09 00:00 VN** — khớp với mục 3.3 (0 execution lỗi Gateway sau mốc fix) và
xác nhận **0 lỗi runner** kể từ khi fix được áp dụng.

### 6.2 So với số execution lỗi thực tế (đối chiếu "log có bị thiếu không")

| Workflow | Execution lỗi thực (mục 4) | Dòng `error_logs` | Thiếu |
|---|---|---|---|
| Gateway | 5 | 4 | 1 |
| Live Update | 93 | 52 | 41 |
| **Tổng** | **98** | **56** | **42** |

42 dòng thiếu = khớp tuyệt đối với 42 execution lỗi của chính Error Handler v1 (mục 5) → xác nhận nguyên
nhân mất log là do handler tự lỗi (429), **không phải** do thiếu cấu hình hay lỗi ghi DB khác.

### 6.3 Lỗi lặp (cùng workflow + node trong cùng phút) — ước số tin Telegram v2 sẽ gộp

| Chỉ số | Giá trị |
|---|---|
| Tổng dòng (đã loại test) | 56 |
| Số "bucket" phút riêng biệt (workflow+node+phút) | **13** |
| Bucket có ≥ 2 dòng trùng | 10 |
| Số dòng sẽ bị gộp nếu áp logic v2 (throttle 1 tin/phút/workflow+node) | **43** |

→ Nếu chạy trên cùng dữ liệu tuần này, **v1 gửi tối đa 56 tin** (thực tế ít hơn vì 42 bị mất do 429 —
mục 5), còn **v2 chỉ gửi 13 tin** — giảm ~77% số tin, đúng mục tiêu "khác biệt cho phép" của WP1.

Bucket lớn nhất: `⚙️ Config (Admin Chat ID)` (Live Update) lúc `2026-09-23T07:05:00Z` — 10 dòng gộp
thành 1 tin.

## 7. Chỉ số cấu trúc (lấy từ `PLAN.md`/`TEST_REPORT.md`, KHÔNG đo lại)

| Chỉ số | v1 (production) | v2 (staging, chưa cutover) |
|---|---|---|
| Số node Gateway | 48 | 44 (48 − 2 C1 − 1 C2 − 1 C4; C3 giữ nguyên số node) |
| Code node trên đường lệnh Gateway | 5 | 3 |
| DDL chạy mỗi request (Gateway, node `Ensure Pending Uploads Table`) | 1 | 0 |
| Ghi trùng/request (Audit Log + Tạo pending user ghi đôi vào Docker qua Supabase node) | 2 node | 0 |
| Số workflow có `errorWorkflow` (trong 7 WP5 + Gateway) | 4/8 | 8/8 (sau cutover WP5, mục 8.1.2 PLAN) |
| Cổng admin (Admin System) | 5 IF riêng (`Check Admin` Errors/Version/Token/VPS/VPS Extra) | 1 IF (pilot domain "Hệ thống", `bauK573MU18oRzKP`, chưa production) |
| GW-P1 hiệu năng (PIN, chỉ đo phần logic — KHÔNG phải traffic thật) | p50 ≈ 101–107ms | p50 ≈ 74–82ms |

## 8. Bảng chính — theo dõi trước/sau cutover

| Chỉ số | Baseline v1 (7 ngày) | Sau 30 phút | Sau 24 giờ | Sau 7 ngày | Cách đo lại (tool/query chính xác) |
|---|---|---|---|---|---|
| Gateway — số execution/ngày (webhook thật) | 133–410 (biến động; 2 ngày cuối 205/ngày TB) | | | | `search_workflow_executions({workflowId:"xmEKeIUnzxm2F7dF" hoặc ID v2 sau cutover, limit:1, startedAfter, startedBefore})`, đọc `count` |
| Gateway — tỉ lệ lỗi | 0,42% (5/1202) | | | | như trên với `status:["error"]` chia cho tổng |
| Gateway — p50 thời gian chạy (sau fix runner, baseline hiện tại) | **93ms** | | | | như trên, `limit:200` phân trang, tính `stoppedAt-startedAt` bằng script |
| Gateway — p95 thời gian chạy | **196ms** | | | | như trên |
| Gateway — execution CN 19–22h VN | 0 (20/09) | (n/a — không phải CN) | | | count-trick với `startedAfter/startedBefore` đúng khung giờ VN→UTC |
| 7 workflow WP5 — tổng error/crashed | 109 error (5+93+0+0+4+1+6), 0 crashed | | | | count-trick từng workflow, `status:["error"]`/`["crashed"]` |
| Số workflow có `errorWorkflow` | 4/8 | | | | `get_workflow_details(detailLevel:"execution")` → `settings.errorWorkflow` từng workflow |
| "Lỗi không được báo" (3 workflow chưa có handler) | 11 execution | | | | sau cutover: phải = 0 vì cả 3 đã có `errorWorkflow`; đếm error các workflow này rồi so dòng `error_logs`/tin Telegram tương ứng |
| Error Handler — execution lỗi (mất cảnh báo) | 42/98 (43%) | | | | count-trick trên workflow Error Handler (v1 hoặc v2 `MaoEB8w8Un6UA01n` sau cutover) |
| `error_logs` — tổng dòng 7 ngày | 56 | | | | SQL (TEMP mới, cùng mẫu Q1 mục 9) |
| `error_logs` — dòng chứa 'runner' | 26 (100% trước 25/09, 0 từ 25/09) | | | | SQL Q1 mục 9 |
| `error_logs` — số dòng thiếu so với execution lỗi thực | 42/98 (43%) | | | | so `error_logs` count với tổng error/crashed các workflow có handler |
| `error_logs` — số bucket phút riêng biệt (≈ số tin Telegram) | 13 (từ 56 dòng thô) | | | | SQL Q3 mục 9 |

## 9. Câu SQL đã dùng (nguyên văn, chạy qua TEMP `2xVOmDrN6Rm49ZbE`, credential `Postgres account`
`GwUFREmcXzXXj5mZ`)

Kiểm schema trước khi viết query (cột thời gian thực tế là `occurred_at`, không phải `created_at`):

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='gateway' AND table_name='error_logs' ORDER BY ordinal_position;
```

**Q1 — theo workflow, tách trước/sau mốc fix runner, đếm dòng chứa 'runner':**

```sql
SELECT workflow_name,
       COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE occurred_at < '2026-09-25 00:00:00+07') AS rows_before_25,
       COUNT(*) FILTER (WHERE occurred_at >= '2026-09-25 00:00:00+07') AS rows_from_25,
       COUNT(*) FILTER (WHERE error_message ILIKE '%runner%' AND occurred_at < '2026-09-25 00:00:00+07') AS runner_before_25,
       COUNT(*) FILTER (WHERE error_message ILIKE '%runner%' AND occurred_at >= '2026-09-25 00:00:00+07') AS runner_from_25
FROM gateway.error_logs
WHERE occurred_at >= now() - interval '7 days'
  AND id NOT BETWEEN 57 AND 79
GROUP BY workflow_name
ORDER BY total_rows DESC;
```

**Q2 — lỗi lặp cùng workflow+node trong cùng phút:**

```sql
SELECT workflow_name, node_name, date_trunc('minute', occurred_at) AS minute_bucket, COUNT(*) AS cnt
FROM gateway.error_logs
WHERE occurred_at >= now() - interval '7 days'
  AND id NOT BETWEEN 57 AND 79
GROUP BY workflow_name, node_name, minute_bucket
HAVING COUNT(*) > 1
ORDER BY cnt DESC;
```

**Q3 — tổng hợp (tổng dòng, số bucket phút riêng biệt, số dòng sẽ bị gộp theo logic v2):**

```sql
WITH base AS (
  SELECT * FROM gateway.error_logs
  WHERE occurred_at >= now() - interval '7 days' AND id NOT BETWEEN 57 AND 79
),
buckets AS (
  SELECT workflow_name, node_name, date_trunc('minute', occurred_at) AS minute_bucket, COUNT(*) AS cnt
  FROM base GROUP BY 1,2,3
)
SELECT (SELECT COUNT(*) FROM base) AS total_rows,
       (SELECT COUNT(*) FROM buckets) AS distinct_alert_buckets,
       (SELECT COUNT(*) FROM buckets WHERE cnt>1) AS buckets_with_duplicates,
       (SELECT COALESCE(SUM(cnt-1),0) FROM buckets WHERE cnt>1) AS rows_suppressed_if_v2;
```

## 10. Tiêu chí đạt / rollback đề xuất (dựa trên số liệu thật ở trên)

**Sau 30 phút (có người trực, ngay sau bước 8.1–8.2 PLAN):**
- 0 execution lỗi trên Gateway v2 + Error Handler v2 + 7 workflow đã trỏ `errorWorkflow` mới.
- Smoke 4/4: `/task <từ khoá>`, `/tomtat` + ảnh, bấm 1 nút cũ (`chitiet_`), `/mokhoa` ở chat riêng — đều
  có phản hồi đúng như hành vi v1.
- ⚠️ **KHÔNG dùng p50/p95 làm điều kiện dừng ở mốc 30 phút.** Khung cutover 19:00–22:00 CN trùng đúng
  khung "gần 0 traffic" đã xác nhận ở mục 3.4 (0 execution Chủ Nhật 20/09 cùng khung giờ) — 30 phút đầu
  nhiều khả năng có 0–2 request thật, không đủ mẫu để so sánh có ý nghĩa thống kê.

**Sau 24 giờ và 7 ngày:**
- p50 Gateway v2 ≤ baseline hiện tại (đã fix runner) **93ms** × 1,1 ≈ **≤ 102ms** — dùng baseline SAU
  fix (không dùng baseline pre-fix ~1,6s vì đã lỗi thời, không phản ánh trạng thái production hiện tại).
- Tỉ lệ lỗi Gateway ≤ baseline 7 ngày **0,42%**, lý tưởng là **0%** (baseline post-fix hiện tại đã ở 0
  lỗi từ 25/09 đến giờ chạy báo cáo).
- 0 dòng `error_logs` mới chứa "runner" (baseline post-fix đã là 0 — không có dung sai).
- Cảnh báo bị mất = 0: số dòng `error_logs` của Gateway v2/handler v2 phải khớp 100% với tổng
  execution lỗi/crashed thực tế (khác biệt so với v1 hiện đang thiếu 42/98 = 43%).
- "Lỗi không được báo" (Admin/Reader/Ảnh) phải giảm từ 11 xuống **0** — mọi lỗi của 3 workflow này phải
  xuất hiện trong `error_logs` sau khi WP5 gắn `errorWorkflow`.

**Rollback:** theo đúng runbook mục 8 PLAN — lỗi bất kỳ trong 30 phút hoặc theo báo cáo người dùng →
`unpublish_workflow` v2 → `publish_workflow` v1 (Gateway, <10s); đổi `errorWorkflow` các workflow về
`34ccboHpyoY2r691` cho nhánh Error Handler. Không cần sửa gì khác (sub-workflow không đổi).

## 11. Chỉ số không lấy được / lý do

- **Histogram giờ VN đầy đủ 7×24h** cho 5 ngày đầu (19–24/09): không dựng — chỉ có số liệu chính xác cho
  2 ngày cuối và khung Chủ Nhật 19–22h VN riêng lẻ (đủ để trả lời câu hỏi chính của PLAN). Nếu cần đầy đủ,
  chạy lại bằng cách phân trang toàn bộ 5 ngày như đã làm cho 2 ngày cuối (mục 2).
- **p50/p95 5 ngày đầu dùng mẫu 20–25/ngày** (không phải ≤100 như dự kiến, và không phải mẫu ngẫu nhiên —
  là các execution cuối ngày). Đủ để thấy pattern rõ rệt (bimodal ~100ms/~1,6s trước fix) nhưng không nên
  dùng làm số chốt chặn go/no-go — dùng số **chính xác** của mục 3.3 (2 ngày cuối) cho việc này.
- **Không có chỉ số nào bị an toàn/permission từ chối** trong nhiệm vụ này — mọi lệnh (đọc n8n MCP, SQL
  SELECT qua TEMP) đều chạy được.
