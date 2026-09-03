# Telegram Bot — Tra cứu kết quả phỏng vấn (`/ketqua`)

Workflow n8n cho bot Telegram tra cứu kết quả phỏng vấn học sinh (interview evaluations) lưu trong Supabase, dùng AI Agent để fuzzy-match tên học sinh (chấp nhận sai dấu, viết tắt, gõ nhầm nhẹ).

## Chức năng

- **`/ketqua <tên học sinh>`** — tìm trên toàn bộ công ty
- **`/ketqua <công ty> + <tên học sinh>`** — tìm trong 1 công ty cụ thể
- **`/help`** — hiển thị hướng dẫn sử dụng
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
                          └─ false → Trả lời: Sai cú pháp

Chuẩn bị lấy chi tiết → Supabase: Lấy chi tiết → Format tin nhắn kết quả → Trả lời: Kết quả phỏng vấn
```

## Yêu cầu trước khi import

| Thành phần | Ghi chú |
|---|---|
| **Telegram Bot Token** | Credential `telegramApi` (đang set là "CSFSINT") |
| **Supabase** | Bảng `interview_evaluations`, credential `supabaseApi` |
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

## Cài đặt

1. Import file `interview-result-lookup.json` vào n8n (**Workflow → Import from File**).
2. Gán lại credentials cho: Telegram Trigger, các node Telegram, Supabase, OpenRouter, DeepSeek.
3. Mở node **"Gửi danh sách để chọn (HTTP)"** → thay `<TOKEN>` trong URL bằng bot token thật:
   ```
   https://api.telegram.org/bot<TOKEN>/sendMessage
   ```
4. Kích hoạt (Activate) workflow.
5. Test:
   - Gửi `/help` → nhận hướng dẫn
   - Gửi `/ketqua <tên có nhiều kết quả trùng>` → nhận inline keyboard, bấm chọn → nhận kết quả chi tiết
   - Gửi cú pháp sai → nhận thông báo lỗi + gợi ý `/help`

## Logic tính "Đạt / Chưa đạt"

Ngưỡng điểm đạt phụ thuộc mã công ty (case-insensitive):

- **Ngưỡng 5**: `elmc, el, elhz, elts, elht, elnb, elmb, eltshz, eltsht`
- **Ngưỡng 6**: các công ty còn lại

`final_score >= threshold` → Đạt, ngược lại → Chưa đạt. Chỉnh sửa danh sách `specialCompanies` trong node **"Format tin nhắn kết quả"** nếu quy tắc thay đổi.

## Các điểm cần lưu ý khi bảo trì

- **Callback data format**: nút chọn dùng `sel:<id>`, node "Parse lựa chọn" phụ thuộc format này — đổi 1 bên phải đổi bên kia.
- **AI Agent** có 2 model fallback (OpenRouter → DeepSeek). Nếu 1 trong 2 lỗi, agent tự chuyển sang model còn lại.
- **`alwaysOutputData: true`** được bật ở các node Supabase và "Rút gọn danh sách candidate" để tránh workflow dừng đột ngột khi không có kết quả.
- Bot token hiện đang hardcode trong URL của HTTP Request node — cân nhắc chuyển sang **Header Auth Credential** hoặc biến môi trường nếu chia sẻ workflow này rộng hơn.

## Changelog

- **v1.1** — Sửa lỗi nút chọn (2–5 kết quả) không gửi được do thiếu `callback_data`; thêm lệnh `/help`.
- **v1.0** — Bản gốc: tra cứu theo tên/công ty, fuzzy match bằng AI Agent, format kết quả chi tiết.
