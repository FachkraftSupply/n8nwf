# Telegram Bot — Tra cứu kết quả phỏng vấn (`/ketqua`)

Workflow n8n cho bot Telegram tra cứu kết quả phỏng vấn học sinh (interview evaluations) lưu trong Supabase, dùng AI Agent để fuzzy-match tên học sinh (chấp nhận sai dấu, viết tắt, gõ nhầm nhẹ).

## Link nhanh

| | |
|---|---|
| **n8n workflow** | https://n8n.toididuhoc.net/workflow/1gPcUduwtUkbA1aX |
| **Supabase project** ("Test tiếng") | https://supabase.com/dashboard/project/oreodamslizkrmdpvgye |
| **Supabase Table Editor** (sửa ngưỡng không cần SQL) | https://supabase.com/dashboard/project/oreodamslizkrmdpvgye/editor |
| **Supabase SQL Editor** | https://supabase.com/dashboard/project/oreodamslizkrmdpvgye/sql/new |

## Chức năng

- **`/ketqua <tên học sinh>`** — tìm trên toàn bộ công ty
- **`/ketqua <công ty> + <tên học sinh>`** — tìm trong 1 công ty cụ thể
- **`/help`** — hiển thị hướng dẫn sử dụng
- **`/nguong`** — xem ngưỡng điểm "Đạt" đang áp dụng (mặc định / theo công ty / theo nghề), đọc trực tiếp từ bảng `score_thresholds`
- Nếu có **2–5 kết quả** trùng tên → bot gửi inline keyboard để người dùng chọn đúng học sinh
- Nếu có **>5 kết quả** → yêu cầu gõ tên đầy đủ hơn hoặc kèm tên công ty
- Nếu **0 kết quả** → báo không tìm thấy

## Kiến trúc workflow

```
Telegram Trigger (message + callback_query)
        │
        ▼
   Là callback_query?
   ├─ true  → Parse lựa chọn → Answer callback + Chuẩn bị lấy chi tiết
   └─ false → Parse lệnh /ketqua
                   │
                   ▼
              Lệnh hợp lệ?
              ├─ true  → Có company không?
              │            ├─ true  → Supabase: Tra cứu theo công ty
              │            └─ false → Supabase: Tra cứu theo tên học sinh
              │                          │
              │                          ▼
              │                 Rút gọn danh sách candidate
              │                          │
              │                          ▼
              │                 Có kết quả nào không?
              │                 ├─ true  → AI Agent (fuzzy match) → Parse kết quả AI
              │                 │                                        │
              │                 │                                        ▼
              │                 │                        Phân loại theo số lượng khớp
              │                 │                        ├─ 0 kết quả  → Trả lời: Không tìm thấy học sinh
              │                 │                        ├─ 1 kết quả  → Chọn matched_id duy nhất → ...
              │                 │                        ├─ 2-5        → Build inline keyboard → Gửi (HTTP)
              │                 │                        └─ >5         → Yêu cầu thông tin chi tiết hơn
              │                 └─ false → Trả lời: Không có kết quả
              └─ false → Là lệnh /help?
                          ├─ true  → Trả lời: Hướng dẫn
                          └─ false → Là lệnh /nguong?
                                      ├─ true  → Supabase: Xem ngưỡng hiện tại → Format danh sách ngưỡng → Trả lời: Danh sách ngưỡng
                                      └─ false → Trả lời: Sai cú pháp

Chuẩn bị lấy chi tiết → Supabase: Lấy chi tiết → Supabase: Lấy ngưỡng điểm → Format tin nhắn kết quả → Trả lời: Kết quả phỏng vấn
```

## Yêu cầu trước khi import

| Thành phần | Ghi chú |
|---|---|
| **Telegram Bot Token** | Credential `telegramApi` (đang set là "CSFSINT") |
| **Supabase** | Bảng `interview_evaluations` + `score_thresholds`, credential `supabaseApi` |
| **OpenRouter** | Model `google/gemini-3.5-flash-lite`, dùng cho AI Agent (fallback) |
| **DeepSeek** | Model `deepseek-v4-flash`, dùng cho AI Agent (fallback) |
| **HTTP Request node** | Cần thay `<TOKEN>` trong node **"Gửi danh sách để chọn (HTTP)"** bằng bot token thật |

### Schema bảng Supabase `interview_evaluations` (các field được dùng)

```
id, student_name, company, interview_date, evaluator, profession,
score_pronunciation, score_listening, score_content, score_situation, score_attitude,
total_score, final_score, situations (JSON string),
detail_pronunciation, detail_listening, detail_content, detail_attitude, notes
```

### Bảng Supabase `score_thresholds` (mới — xem `sql/01_score_thresholds.sql`, `sql/02_profession_thresholds.sql`, `sql/03_profession_exact_match.sql`)

Cấu hình ngưỡng điểm "Đạt/Chưa đạt", chạy 1 lần trước khi import workflow (hoặc chạy lại an toàn — script dùng `IF NOT EXISTS`/`ON CONFLICT`):

```
id, scope ('company'|'profession'|'default'), scope_value, threshold, note, active
```

**Cách so khớp khác nhau giữa `company` và `profession`:**

- `company`: field `company` trong `interview_evaluations` sạch, 1 giá trị/dòng → so khớp **chính xác** (đã lowercase + trim).
- `profession`: field `profession` thường bị ghi ghép nhiều nghề trong 1 chuỗi (vd `"Refa/Fachverkäufer/Koch/Bäcker"`, `"Fachverkäufer/in, flex"`) → so khớp **CHÍNH XÁC** sau khi đã **bỏ dấu** (umlaut tiếng Đức ä/ö/ü, dấu tiếng Việt) + lowercase — **không** khớp dạng chứa chuỗi, để hồ sơ chỉ liệt kê 1 nghề đó (không phải ghép nhiều nghề) mới được hưởng ngưỡng riêng. `scope_value` nên lưu **không dấu, đúng y nguyên cách field `profession` ghi** (vd `backer/in` cho `Bäcker/in`, `lam banh` cho `Làm bánh`).

Đã seed sẵn ngưỡng 5.5 cho nhóm nghề chế biến/làm bánh/xây dựng (`sql/02_profession_thresholds.sql` + `sql/03_profession_exact_match.sql`):

| scope_value | Khớp với (dữ liệu thật) |
|---|---|
| `fleischer` | `Fleischer` |
| `fleischer/-in` | `Fleischer/-in` |
| `backer/in` | `Bäcker/in` |
| `backerin` | `Bäckerin` |
| `flex` | `Flex` |
| `lam banh` | `Làm bánh` |
| `lebensmittelverarbeitung` | `Lebensmittelverarbeitung` (chế biến thực phẩm) |
| `xay dung` | *(chưa có dữ liệu thực tế — thêm sẵn cho ngành xây dựng)* |

Vì khớp chính xác, hồ sơ ghi ghép nhiều nghề (vd `"Koch/Köchin - Fleischer"`, `"Refa/Fachverkäufer/Koch/Bäcker"`, `"Koch/Köchin, làm bánh, bán bánh"`) sẽ **không** được ngưỡng riêng, rơi về `default`. Muốn áp dụng cho cách ghi ghép cụ thể nào đó → thêm 1 dòng `scope_value` đúng y nguyên chuỗi đó (đã bỏ dấu, lowercase).

## Cài đặt

1. Chạy lần lượt `sql/01_score_thresholds.sql`, `sql/02_profession_thresholds.sql`, `sql/03_profession_exact_match.sql` trên Supabase (SQL Editor) để tạo bảng `score_thresholds` + seed dữ liệu.
2. Import file `interview-result-lookup.json` vào n8n (**Workflow → Import from File**).
3. Gán lại credentials cho: Telegram Trigger, các node Telegram, Supabase (bao gồm node mới **"Supabase: Lấy ngưỡng điểm"**), OpenRouter, DeepSeek.
4. Mở node **"Gửi danh sách để chọn (HTTP)"** → thay `<TOKEN>` trong URL bằng bot token thật:
   ```
   https://api.telegram.org/bot<TOKEN>/sendMessage
   ```
5. Kích hoạt (Activate) workflow.
6. Test:
   - Gửi `/help` → nhận hướng dẫn
   - Gửi `/ketqua <tên có nhiều kết quả trùng>` → nhận inline keyboard, bấm chọn → nhận kết quả chi tiết
   - Gửi cú pháp sai → nhận thông báo lỗi + gợi ý `/help`
   - Kiểm tra dòng "Kết luận: ... (ngưỡng đạt: X)" trong kết quả trả về khớp với dữ liệu trong `score_thresholds`

## Logic tính "Đạt / Chưa đạt"

Ngưỡng điểm được cấu hình trực tiếp trong bảng Supabase **`score_thresholds`** (không còn hardcode trong code node), cho phép set riêng theo **đối tác (company)** hoặc theo **nghề (profession)**, có 1 dòng `default` dùng chung.

Thứ tự ưu tiên khi tra cứu (`node "Format tin nhắn kết quả"`): **company > profession > default**. Nếu bảng trống hoặc thiếu dòng `default`, code có fallback cứng = 6 để không làm sập workflow.

Cách chỉnh ngưỡng — chỉ cần INSERT/UPDATE trực tiếp trong Supabase, không cần sửa code/import lại workflow:

```sql
-- Set ngưỡng riêng cho 1 công ty
INSERT INTO score_thresholds (scope, scope_value, threshold, note)
VALUES ('company', 'elmc', 5, 'Đối tác ELMC')
ON CONFLICT (scope, scope_value) WHERE scope_value IS NOT NULL
DO UPDATE SET threshold = EXCLUDED.threshold, updated_at = now();

-- Set ngưỡng riêng cho 1 nghề (scope_value KHÔNG DẤU, xem cách so khớp ở trên)
INSERT INTO score_thresholds (scope, scope_value, threshold, note)
VALUES ('profession', 'fleischer', 5.5, 'Nghề Fleischer (chế biến thịt)')
ON CONFLICT (scope, scope_value) WHERE scope_value IS NOT NULL
DO UPDATE SET threshold = EXCLUDED.threshold, updated_at = now();

-- Đổi ngưỡng mặc định
UPDATE score_thresholds SET threshold = 6.5 WHERE scope = 'default';

-- Tạm ngưng áp dụng 1 dòng (giữ lại để tham khảo) mà không xoá
UPDATE score_thresholds SET active = false WHERE scope = 'company' AND scope_value = 'elmc';
```

`scope_value` nên lưu dạng thường + trim (lowercase) vì code node so khớp `company`/`profession` sau khi đã `trim().toLowerCase()`.

`final_score >= threshold` → Đạt, ngược lại → Chưa đạt.

## Các điểm cần lưu ý khi bảo trì

- **Callback data format**: nút chọn dùng `sel:<id>`, node "Parse lựa chọn" phụ thuộc format này — đổi 1 bên phải đổi bên kia.
- **AI Agent** có 2 model fallback (OpenRouter → DeepSeek). Nếu 1 trong 2 lỗi, agent tự chuyển sang model còn lại.
- **`alwaysOutputData: true`** được bật ở các node Supabase và "Rút gọn danh sách candidate" để tránh workflow dừng đột ngột khi không có kết quả.
- Bot token hiện đang hardcode trong URL của HTTP Request node — cân nhắc chuyển sang **Header Auth Credential** hoặc biến môi trường nếu chia sẻ workflow này rộng hơn.
- **`score_thresholds`** là bảng config nhỏ — node "Supabase: Lấy ngưỡng điểm" lấy toàn bộ dòng `active = true` (không lọc theo company/profession ở query) rồi để code node "Format tin nhắn kết quả" tự chọn dòng khớp nhất, tránh phải viết OR-filter phức tạp trên Supabase node.

## Changelog

- **v1.6** — Fix bug `/nguong` không trả lời gì: node "Trả lời: Danh sách ngưỡng" lỗi `400 can't parse entities` vì text có dấu `_` trần trong `score_thresholds` (ngoài backtick) — Telegram `parse_mode: Markdown` (legacy) hiểu nhầm là mở entity italic không tìm được dấu đóng, khiến `sendMessage` fail và bot im lặng. Bọc `score_thresholds` trong backtick để fix.
- **v1.5** — Thêm lệnh `/nguong`: xem ngay trong Telegram ngưỡng điểm "Đạt" đang áp dụng (mặc định/công ty/nghề) mà không cần mở Supabase. Thêm link Supabase Table Editor vào `/help`.
- **v1.4** — Đổi cách so khớp ngưỡng theo nghề từ "chứa chuỗi" về lại **khớp chính xác** (sau khi bỏ dấu): "chứa chuỗi" vô tình áp ngưỡng 5.5 cho hồ sơ ghép nhiều nghề (vd `"Refa/Fachverkäufer/Koch/Bäcker"`, `"Fachverkäufer/in, flex"`) dù nghề đó chỉ là 1 trong nhiều kỹ năng liệt kê. Bỏ `backer`, thêm biến thể chính xác `backer/in`, `backerin`, `fleischer/-in`. Thêm ngành xây dựng (`xay dung`, chưa có dữ liệu thực tế).
- **v1.3** — Sửa cách so khớp ngưỡng theo nghề: field `profession` thường ghép nhiều nghề trong 1 chuỗi (vd `"Koch/Köchin - Fleischer"`), so khớp exact bỏ sót các dòng này → đổi sang so khớp "chứa chuỗi" sau khi bỏ dấu. Seed ngưỡng 5.5 cho nhóm chế biến/làm bánh (Fleischer, Bäcker, làm bánh, Flex, Lebensmittelverarbeitung).
- **v1.2** — Chuyển ngưỡng điểm "Đạt/Chưa đạt" từ hardcode (`specialCompanies` trong code) sang cấu hình trong bảng Supabase `score_thresholds`, hỗ trợ set riêng theo công ty hoặc theo nghề. Thêm node **"Supabase: Lấy ngưỡng điểm"**.
- **v1.1** — Sửa lỗi nút chọn (2–5 kết quả) không gửi được do thiếu `callback_data`; thêm lệnh `/help`.
- **v1.0** — Bản gốc: tra cứu theo tên/công ty, fuzzy match bằng AI Agent, format kết quả chi tiết.
