# STATUS — Bot Luyện Phỏng Vấn & Tự Động Tạo Hồ Sơ Ausbildung

> **Đọc file này ĐẦU TIÊN**, sau đó đọc `RULES.md`, rồi mới đến `ARCHITECTURE.md`.

## Trạng thái hiện tại
- Giai đoạn: **Thiết kế (Design)** — chưa có workflow n8n nào được build.
- Khởi tạo: 2026-09-13

## Việc đã xong
- [x] Xác định luồng nghiệp vụ tổng thể (xác thực mã ClickUp → Upload hồ sơ / Interview)
- [x] Chọn kiến trúc lưu trữ: Postgres (bảng câu hỏi + session state), Supabase (kết quả phỏng vấn — DB đã có sẵn), OneDrive (file hồ sơ)
- [x] Chọn công cụ publish tạm có mã khóa: **PrivateBin** self-host trên VPS hiện có
- [x] Viết `ARCHITECTURE.md`, `RULES.md`, `ROADMAP.md`

## Việc đang làm
- [ ] Chưa bắt đầu build workflow nào
- [ ] Kiểm tra xem folder `interview-evaluation/` và `interview-result-lookup/` đã có sẵn trong repo có liên quan/trùng lặp phần nào với dự án này không — cần rà soát trước khi build để tránh làm lại.

## Việc tiếp theo
Xem chi tiết theo giai đoạn ở `ROADMAP.md`. Ưu tiên ngay:
1. Tạo bảng Postgres `interview_bank` + `application_session`
2. Build sub-workflow "Verify ClickUp Code + OneDrive Link"
3. Deploy PrivateBin trên VPS

## Blocker / câu hỏi cần Mr xác nhận trước khi build
1. Bot này có **route qua Gateway COMMAND_MAP** hiện có (`Elite_clickup_bot`) hay chạy **độc lập** với Telegram Trigger riêng? → Ảnh hưởng lớn đến cách wiring.
2. "Mã ClickUp được cung cấp khi test tiếng xong" — đây là **Task ID** (dạng `86xxxxxxx`) hay một **Custom Field** riêng (vd mã hồ sơ nội bộ)? Cần field ID chính xác nếu là custom field.
3. Comment ClickUp chứa link OneDrive — có format cố định để regex match không, hay cần AI đọc comment tự do?
4. Model AI dùng để "đọc câu trả lời tiếng Việt, tư vấn hướng phù hợp, rồi dịch/soạn câu trả lời tiếng Đức" — dùng lại OpenRouter (Gemini 2.5 Flash) đang có, hay cần model tốt hơn (gợi ý Claude API vì chất lượng văn phong tiếng Đức + tư vấn tốt hơn)?
5. Danh sách hồ sơ "khác nếu có" — có giới hạn số lượng / loại file không, hay tự do?
6. Repo đã có sẵn `interview-evaluation/` và `interview-result-lookup/` — folder này có liên quan/thay thế một phần của luồng Interview trong dự án này không?

## Quy trình review khi implement
- Sub-agent 1 (**Sonnet 4.6**): build workflow, dùng skill `using-n8n-mcp-skills` làm entry point, load thêm skill chuyên biệt theo nhu cầu (node-configuration, expression-syntax, error-handling, binary-and-data, agents, workflow-patterns).
- Sub-agent 2 (**Sonnet 5**): audit lại toàn bộ workflow đã build — đối chiếu với `RULES.md`, kiểm tra validation JSON, kiểm tra logic xóa dữ liệu khi Hủy, kiểm tra state machine không bị kẹt trạng thái.
