# 📋 Hệ Thống Đánh Giá Phỏng Vấn – Elite Education

> Form đánh giá phỏng vấn tiếng Đức cho học viên Ausbildung, tự động tổng hợp bằng AI và gửi kết quả đến Telegram + ClickUp + Supabase.

**Phiên bản hiện tại:** Form v4.3 · Workflow v4-final (1 LLM call gộp + debug branch) · Cập nhật 03/09/2026

---

## 🗺️ Tổng quan kiến trúc

```
┌─────────────────┐
│  Form HTML v4.3 │  (elite-interview-form-v4.3.html)
│  Người đánh giá │
│  điền + submit  │
└────────┬────────┘
         │ POST JSON payload
         ▼
┌─────────────────────────────────────────┐
│  n8n Webhook: /webhook/interview-evaluation │
└────────┬────────────────────────────────┘
         │ fan-out song song 2 nhánh
         ├──────────────────────────────┐
         ▼                              ▼
┌─────────────────┐          ┌──────────────────────┐
│   Aggregate1    │          │ Chuẩn bị dữ liệu      │
│  (dữ liệu gốc)  │          │ Supabase (Code node)  │
└────────┬────────┘          └──────────┬───────────┘
         ▼                              ▼
┌─────────────────────┐      ┌──────────────────────┐
│ Combined LLM Chain   │      │ Supabase - Lưu đánh giá│
│ (Gemini, 1 lần gọi)  │      │ bảng:                 │
│ → JSON {telegram_html,│     │ interview_evaluations │
│    clickup_markdown} │      └──────────────────────┘
└────────┬─────────────┘
         ▼
┌─────────────────────┐
│  Parse LLM Output    │  (Code node — không throw lỗi,
│  (Code)              │   trả về _parse_ok true/false)
└────────┬─────────────┘
         ▼
┌─────────────────────┐
│ Check - Parse LLM OK?│  (IF node)
└──┬────────────────┬──┘
   │ true            │ false
   ▼                 ▼
┌─────────────┐  ┌──────────────────────┐
│Create a task1│  │ Debug - Lỗi Parse LLM │
│  (ClickUp)   │  │ (Telegram, raw output │
└──────┬───────┘  │  đầy đủ để soi lỗi)   │
       ▼          └──────────────────────┘
┌─────────────┐
│Gửi Telegram1│
│(HTML + link │
│ task ClickUp)│
└─────────────┘

┌─────────────────┐          ┌──────────────────────┐
│  Error Trigger  │─────────▶│ Error - Gửi Telegram1 │
│ (lỗi hệ thống   │          │ (lỗi execution-level, │
│  toàn workflow) │          │  không phải lỗi parse)│
└─────────────────┘          └──────────────────────┘
```

**Điểm quan trọng của kiến trúc mới:**
- Chỉ **1 lần gọi LLM duy nhất** (`Combined LLM Chain`) — nhận dữ liệu gốc từ `Aggregate1`, xuất JSON chứa cả 2 định dạng (`telegram_html` + `clickup_markdown`) cùng lúc, thay vì 2 lần gọi tuần tự như bản cũ
- `Parse LLM Output` **không throw lỗi** làm sập workflow — nếu LLM trả JSON hỏng, tách sang nhánh **Debug** gửi Telegram kèm **toàn bộ raw output** của LLM để dễ soi nguyên nhân, mà không ảnh hưởng đến nhánh Supabase (đã lưu xong ở nhánh song song, độc lập)
- `Error Trigger` chỉ bắt lỗi **execution-level** (crash thực sự của node khác), tách biệt với lỗi parse JSON (được xử lý riêng qua nhánh Debug ở trên)

---

## 📁 Danh sách file

| File | Mô tả |
|---|---|
| [`elite-interview-form-v4.3.html`](./elite-interview-form-v4.3.html) | Form đánh giá chính — mở trực tiếp trên trình duyệt hoặc host lên web server |
| [`interview-evaluation-workflow-v4-final.json`](./interview-evaluation-workflow-v4-final.json) | Workflow n8n hoàn chỉnh, bản mới nhất (import vào n8n) |
| `README.md` | File này |

## 📝 Form HTML v4.3

### Cấu trúc form

1. **Thông tin cơ bản** — công ty, tên học viên, nghề, nơi đến, ngày PV (tự động), người đánh giá, bằng cấp, độ tuổi, quê quán, người nhà ở Đức (radio + ô địa chỉ cùng dòng), điểm mạnh, cần cải thiện, ghi chú thêm
2. **Tiêu chí đánh giá** (mỗi tiêu chí /2 điểm, thang 0.5 – 1.0 – 1.5 – 2.0):
   - 🗣️ Phát âm (có tag "Ngọng")
   - 👁️‍🗨️ Nghe hiểu & Phản xạ
   - 💬 Nội dung câu trả lời
   - 😊 Thái độ & Hình thức
3. **Câu hỏi tình huống** — 6 câu cố định luôn hiển thị (ô Câu hỏi + ô Câu trả lời tách riêng), có thể thêm câu custom. Bỏ trống → tự ghi `"Chưa hỏi / Không có câu trả lời"`
4. **Kết luận** — Đạt / Có thể nhận cho nghề khác / Chưa đạt
5. **Tổng điểm tự động** (/10) + **Điều chỉnh điểm** (nút ±0.5 hoặc gõ tay, kèm lý do)

### Tính năng đặc biệt

| Tính năng | Cách hoạt động |
|---|---|
| 💾 **Auto-save draft** | Tự lưu localStorage mỗi lần nhập; reload trang không mất dữ liệu; có nút "Xoá draft" |
| 🔒 **Lock sau submit** | Gửi thành công → form khoá lại, hiện nút "✏️ Đánh giá học viên mới" để reset |
| 📋 **Copy JSON** | Copy toàn bộ payload ra clipboard (debug/backup) |
| 📥 **Load JSON** | Dán payload JSON để khôi phục form (chuyển máy làm tiếp) |
| 📖 **Hướng dẫn tích hợp** | 2 khối `<details>` hướng dẫn sử dụng ngay đầu form |
| 🏷️ **Version tag** | Cuối form ghi `v4.3 · 07/03/2026` để kiểm tra phiên bản |

### Danh sách gợi ý (datalist – vẫn cho nhập tự do)

- **Công ty:** ELMC, ELHT, ELTS, ELHZ, ICO, GAC, GEZ, HND, DSHI, AVT, ETS
- **Nghề:** ZFA, MFA, Koch/Köchin, Fachverkäufer/in, Maler/Malerin, Bäcker/in, HOFA, Gebäudereiniger/in, Elektroniker/in, Mechatroniker/in, Kaufmann/Kauffrau, Flex
- **Người đánh giá:** Thuỳ Chi, Hải Yến, Xuân Hoa, Anh Tuấn, Thanh Hà, Nhi Nguyễn, Thảo Phan

### Webhook endpoint

```
POST https://n8n.toididuhoc.net/webhook/interview-evaluation
Content-Type: application/json
```

---

## 📦 Payload JSON (form → webhook)

```jsonc
{
  // Thông tin cơ bản
  "company": "ELMC",
  "student_name": "Nguyễn Văn A",
  "profession": "ZFA",
  "destination": "Berlin",
  "interview_date": "07/03/2026",        // dd/MM/yyyy
  "evaluator": "Xuân Hoa",
  "certificate": "B1 Telc T10/2025",
  "age": "21",
  "hometown": "Bắc Ninh",
  "family_in_germany": "Có",             // "Có" | "Không" | ""
  "family_region": "Berlin",

  // Điểm từng tiêu chí (/2)
  "score_pronunciation": "1.5",
  "score_listening": "1",
  "score_content": "1.5",
  "score_situation": "1.5",
  "score_attitude": "2",

  // Điểm tổng
  "total_score": "7.5",                  // tự động cộng
  "score_adjustment": 0.5,               // số, có thể âm
  "adjustment_reason": "Có kinh nghiệm thực tế",
  "final_score": "8.0",                  // total + adjustment (clamp 0-10)

  // Tags & ghi chú
  "detail_pronunciation": "Lỗi l/n, Ngọng",   // comma-separated
  "detail_listening": "...",
  "detail_content": "...",
  "detail_attitude": "...",
  "note_pronunciation": "...",
  "note_listening": "...",
  "note_content": "...",
  "note_attitude": "...",

  // Câu hỏi tình huống (6 câu cố định: sit_1 → sit_6; custom: sit_11+)
  "sit_1_question": "Làm thêm giờ / cuối tuần",
  "sit_1_answer": "...",                 // hoặc "Chưa hỏi / Không có câu trả lời"
  "sit_1_tags": "Đúng trọng tâm",
  // ... sit_2 → sit_6, sit_11+ nếu có

  // Nhận xét & kết luận
  "strengths": "...",
  "improvements": "...",
  "notes": "...",
  "verdict": "Đạt"    // "Đạt" | "Có thể nhận cho nghề khác" | "Chưa đạt"
}
```

---

## ⚙️ Workflow n8n v4-final

**File:** `interview-evaluation-workflow-v4-final.json`
**Instance:** `https://n8n.toididuhoc.net`

### Các node

| Node | Chức năng |
|---|---|
| **Webhook - Nhan form** | Nhận POST từ form, path `interview-evaluation` |
| **Aggregate1** | Gom `body` → field `chatInput`, dữ liệu gốc dùng cho LLM |
| **Chuẩn bị dữ liệu Supabase** (Code) | Transform payload đúng schema: gom sit_X thành JSONB, convert date, parse số |
| **Supabase - Lưu đánh giá** | Insert vào bảng `interview_evaluations` (autoMapInputData), chạy song song độc lập |
| **Combined LLM Chain** | Gemini — 1 lần gọi duy nhất, nhận dữ liệu gốc, xuất JSON `{telegram_html, clickup_markdown}` |
| **Parse LLM Output** (Code) | Parse JSON an toàn (không throw), tự strip code fence, trả `_parse_ok: true/false` |
| **Check - Parse LLM OK?** (IF) | Rẽ nhánh theo `_parse_ok` |
| **Debug - Lỗi Parse LLM** (Telegram) | Nhánh false: gửi raw LLM output đầy đủ để debug, không tạo task/Telegram kết quả |
| **Create a task1** | Nhánh true: tạo task ClickUp (list `901812218309`), status theo điểm, dùng `clickup_markdown` |
| **Gửi Telegram1** | Gửi HTML (`telegram_html`) + link task + Task ID đến group `-1002768213220`, thread `33` |
| **Error Trigger + Error - Gửi Telegram1** | Bắt lỗi **execution-level** toàn workflow, báo Telegram kèm execution link |

### Quy tắc prompt LLM (áp dụng cho cả 2 output cùng lúc)

- **Chỉ format**, không thêm/bớt thông tin, không bình luận AI
- **telegram_html:** HTML tag Telegram (`<b>`, `<i>`, `<a>`), không emoji cho điểm thành phần, chỉ emoji cho điểm tổng cuối: `>7` 🌸 · `6–7` 🌷 · `5–6` 🥀 · `4–5` 🍃 · `<4` 🍂
- **clickup_markdown:** `##` heading + emoji, `**bold**` cho nhãn/điểm/kết luận, `*italic*` cho ghi chú phụ, bullet list gọn cho mọi danh sách kể cả câu hỏi tình huống (1 dòng/câu, không blockquote, **không bảng markdown**)
- Cả 2 field đọc từ cùng 1 nguồn dữ liệu gốc — đảm bảo nhất quán, không lệch thông tin giữa Telegram và ClickUp

### ClickUp config

| Thông số | Giá trị |
|---|---|
| Team | `9018351620` |
| Space | `90183192291` |
| Folder | `90183835699` |
| List | `901812218309` |
| Task name | `{company} {student_name} {profession} {destination} {total_score}` |
| Status | `total_score < 3` → Closed, ngược lại → "chưa xử lý" |
| markdown_content | `true` (bắt buộc để ClickUp render Markdown thay vì hiển thị raw text) |

## 🗄️ Supabase

**Bảng:** `public.interview_evaluations`

### Cấu trúc chính

| Nhóm cột | Kiểu | Ghi chú |
|---|---|---|
| `id`, `created_at` | uuid, timestamptz | Tự sinh |
| Thông tin cơ bản | text | company, student_name, profession, destination, evaluator, certificate, age, hometown, family_* |
| `interview_date` | **date** | Code node convert `dd/MM/yyyy` → `yyyy-MM-dd` |
| Điểm số | **numeric** | score_*, total_score, final_score, score_adjustment — Code node parse từ string |
| Tags & notes | text | detail_*, note_* |
| `situations` | **jsonb** | Mảng `[{cau_hoi, cau_tra_loi, danh_gia}]` — gom từ sit_X fields |
| Kết luận | text | strengths, improvements, notes, verdict |

### Node "Chuẩn bị dữ liệu Supabase" xử lý

1. Lấy `$json.body` (tránh auto-map headers/params gây lỗi)
2. Gom `sit_1..6, sit_11+` → mảng JSON cho cột `situations`
3. `interview_date`: `07/03/2026` → `2026-03-07`
4. Điểm: `"1.5"` (string) → `1.5` (number), rỗng → `null`

### Query hữu ích

```sql
-- Xem đánh giá mới nhất
select student_name, profession, final_score, verdict, created_at
from interview_evaluations
order by created_at desc limit 20;

-- Thống kê theo người đánh giá
select evaluator, count(*), round(avg(final_score), 1) as avg_score
from interview_evaluations
group by evaluator order by count(*) desc;

-- Tỷ lệ đạt theo công ty
select company,
  count(*) filter (where verdict = 'Đạt') as dat,
  count(*) as tong
from interview_evaluations
group by company;

-- Đọc câu hỏi tình huống từ JSONB
select student_name, s->>'cau_hoi' as cau_hoi, s->>'cau_tra_loi' as tra_loi
from interview_evaluations, jsonb_array_elements(situations) s
where student_name = 'Nguyễn Văn A';
```

---

## 🚀 Hướng dẫn triển khai / cập nhật

### Deploy form
1. Host file `elite-interview-form-v4.3.html` lên web server bất kỳ (hoặc mở trực tiếp trên trình duyệt)
2. Không cần cấu hình gì thêm — webhook URL đã hardcode trong form

### Import workflow n8n
1. Vào `https://n8n.toididuhoc.net` → Workflows → **Import from file**
2. Chọn `interview-evaluation-workflow-v4-final.json`
3. Kiểm tra 4 credentials được gán đúng:
   - OpenRouter account (2 node LLM)
   - ClickUp account (OAuth2)
   - Telegram: Elite Clickupbot (gửi kết quả) + system noti bot (báo lỗi)
   - Supabase account
4. **Activate** workflow

### Test
1. Mở workflow → node Webhook đã có **pinData mẫu** → bấm "Test workflow" chạy thử toàn tuyến
2. Kiểm tra: row mới trong Supabase + message Telegram + task ClickUp
3. Hoặc mở form thật, điền và submit

### Khi sửa form (thêm/đổi field)
1. Sửa HTML → tăng version tag ở footer
2. Cập nhật `buildPayload()` trong form nếu thêm field
3. Cập nhật prompt trong node **Basic LLM Chain1** (thêm field vào phần "DỮ LIỆU ĐẦU VÀO" + "FORMAT OUTPUT")
4. Nếu lưu Supabase: thêm cột vào bảng + cập nhật Code node "Chuẩn bị dữ liệu Supabase"

---

## 📖 Lịch sử phiên bản

| Version | Thay đổi chính |
|---|---|
| v2 | Payload tiếng Việt, form ổn định ban đầu |
| v3 | Datalist người đánh giá, custom situation, điều chỉnh điểm |
| v4 | Bỏ tick tình huống, thay điểm đầu vào → độ tuổi, thêm tag "Ngọng", UI tối giản |
| v4.1 | Người nhà ở Đức 1 dòng, font nút to hơn, tách ô Câu hỏi/Câu trả lời, verdict "Có thể nhận cho nghề khác", version tag |
| v4.2 | Lock sau submit, Copy JSON, Auto-save draft |
| v4.3 | Chuyển Điểm mạnh/Cần cải thiện/Ghi chú lên Thông tin cơ bản, thêm Load JSON, hướng dẫn sử dụng |
| Workflow v3 | Thêm nhánh Supabase song song + Code node transform dữ liệu |
| Workflow v4-final | Gộp 2 LLM call thành 1 (đọc dữ liệu gốc, xuất JSON 2 field cùng lúc) + thêm nhánh Debug bắt lỗi parse JSON riêng biệt, không làm sập workflow |

---

*Hệ thống nội bộ Elite Education – Ausbildung Germany. Liên hệ admin n8n nếu cần cấp quyền credential.*
