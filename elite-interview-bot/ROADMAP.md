# ROADMAP — Bot Luyện Phỏng Vấn & Tự Động Tạo Hồ Sơ

## Giai đoạn 0 — Chốt quyết định (trước khi code)
- [ ] Mr trả lời 5 câu hỏi blocker trong `STATUS.md`.
- [ ] Chốt: route qua Gateway hay độc lập.
- [ ] Rà soát `interview-evaluation/` và `interview-result-lookup/` đã có sẵn trong repo — xác định có tái sử dụng được phần nào không.

## Giai đoạn 1 — Data model
- [ ] Tạo schema `interview_app` trong Postgres (`application_session`, `interview_bank`, `session_upload_files`).
- [ ] Nhập sẵn ~20 câu hỏi phỏng vấn vào `interview_bank`.
- [ ] Test insert/update/delete thủ công qua SQL trước khi nối workflow.

## Giai đoạn 2 — Verify Sub-workflow
- [ ] Build sub-workflow "Verify ClickUp Code + OneDrive Link" (nhận mã → check ClickUp task → check comment → trả kết quả boolean + link).
- [ ] Test với mã hợp lệ / không hợp lệ / hợp lệ nhưng chưa có OneDrive link.

## Giai đoạn 3 — PrivateBin
- [ ] Deploy PrivateBin container trên VPS (Docker + Caddy subdomain).
- [ ] Test gọi API tạo paste có mật khẩu từ n8n (HTTP Request node).

## Giai đoạn 4 — Luồng Upload Hồ Sơ
- [ ] Nối flow hỏi-đáp Anschreiben/CV vào hệ thống tạo doc hiện có (Zod schema + docx template).
- [ ] Build flow tuần tự cho scan hộ chiếu / ảnh / B1 / bằng tốt nghiệp / giấy tờ khác.
- [ ] Build chế độ Upload nhanh.
- [ ] Test nút Quay lại / Tạm dừng / Hủy trong toàn bộ luồng này.

## Giai đoạn 5 — Luồng Interview
- [ ] Build filter regex `el*` theo tên task.
- [ ] Build vòng lặp 20 câu hỏi + AI Agent tư vấn + soạn câu trả lời tiếng Đức.
- [ ] Nối bước publish PrivateBin + ghi comment Supabase.
- [ ] Test nút Quay lại / Tạm dừng / Hủy trong luồng này.

## Giai đoạn 6 — Audit & Test toàn hệ thống
- [ ] Sub-agent Sonnet 5 audit theo checklist mục 6 của `RULES.md`.
- [ ] Test end-to-end với 1-2 học sinh thật (staging bot trước, không dùng bot PROD).

## Giai đoạn 7 — Production cutover
- [ ] Cập nhật `COMMAND_MAP` nếu route qua Gateway.
- [ ] Thông báo cho team/học sinh cách dùng.
- [ ] Theo dõi log lỗi tuần đầu tiên.

## Không nằm trong scope hiện tại (ghi nhận để sau)
- Đa ngôn ngữ khác ngoài Việt/Đức.
- Tự động chấm điểm/xếp hạng độ tốt của câu trả lời phỏng vấn.
- Giao diện admin riêng để sửa `interview_bank` ngoài SQL trực tiếp.
