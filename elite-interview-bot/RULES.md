# RULES — Bot Luyện Phỏng Vấn & Tự Động Tạo Hồ Sơ

> Đọc sau `STATUS.md`, trước khi build bất kỳ workflow nào. Vi phạm các rule dưới đây = phải sửa lại.

## 0. Quy trình build bắt buộc
- Mọi workflow n8n **PHẢI** dùng skill `using-n8n-mcp-skills` làm entry point trước, để nó route sang skill chuyên biệt phù hợp (node-configuration, expression-syntax, error-handling, binary-and-data, agents, subworkflows, workflow-patterns...).
- 2 sub-agent bắt buộc:
  1. **Builder (Sonnet 4.6)** — build/sửa workflow.
  2. **Auditor (Sonnet 5)** — review lại sau khi builder xong, đối chiếu checklist ở mục 6 dưới đây. Auditor KHÔNG tự sửa, chỉ liệt kê vấn đề để builder sửa lại.
- Không merge/publish workflow nào chưa qua audit.

## 1. Ngôn ngữ & nội dung hồ sơ
- **Tất cả hồ sơ (Thư xin việc, CV, và mọi văn bản tạo ra) PHẢI bằng tiếng Đức.** Không có ngoại lệ.
- Câu trả lời phỏng vấn: user nhập tiếng Việt → bot phản hồi/tư vấn bằng tiếng Việt → câu trả lời "chuẩn" cuối cùng đưa ra bằng tiếng Đức.
- Tài liệu kỹ thuật (file markdown, comment code) viết bằng tiếng Việt có dấu, theo đúng convention hiện có của dự án n8n.

## 2. State machine — nguyên tắc bắt buộc ở MỌI bước hỏi đáp
Mỗi câu hỏi (cả ở luồng Upload hồ sơ lẫn luồng Interview) đều phải có đủ 3 nút:
- **⬅️ Quay lại** — sửa câu trả lời trước đó, không mất các câu đã trả lời khác.
- **⏸️ Tạm dừng** — lưu session hiện tại vào Postgres, cho phép resume lại đúng vị trí sau này (không giới hạn thời gian).
- **❌ Hủy bỏ** — xóa TOÀN BỘ dữ liệu đã nhập của session này VÀ xóa toàn bộ file đã upload lên OneDrive trong session đó. Đây là hard delete, không phải soft delete/archive.
- Vì tính năng này cần thao tác qua nút bấm nhiều bước, đây là **ngoại lệ tường minh** với rule "không dùng inline keyboard mặc định" của dự án Gateway — được phép dùng inline keyboard ở đây.

## 3. Xác thực đầu vào (bắt buộc trước khi mở 2 chức năng)
1. User gửi mã ClickUp.
2. Query ClickUp kiểm tra Task tồn tại (dùng `filters: {}` kể cả rỗng — nếu không workflow không Publish được).
3. Nếu tồn tại → đọc comment của Task, kiểm tra đã có link OneDrive chưa.
4. Chỉ khi có link OneDrive mới hiện 2 chức năng (Upload hồ sơ / Interview). Nếu chưa có → báo user chưa sẵn sàng, không hiện menu.
5. Không cache kết quả xác thực quá lâu — mỗi lần user quay lại menu chính nên re-verify (tránh trường hợp OneDrive link bị xóa sau đó).

## 4. Chức năng Upload hồ sơ
- Thứ tự bắt buộc: **Thư xin việc (Anschreiben) → CV (Lebenslauf)** trước, sau đó mới đến scan hộ chiếu, ảnh xin việc, scan bằng B1, scan bằng tốt nghiệp cấp 3, giấy tờ khác.
- Thư xin việc & CV: dùng lại hệ thống tạo hồ sơ hiện có (Zod validation schema + docx template) — không viết lại từ đầu, chỉ nối luồng hỏi-đáp Telegram vào input của hệ thống đó.
- "Upload nhanh": cho phép bypass toàn bộ luồng hỏi-đáp, nhận file trực tiếp đưa vào đúng folder OneDrive tương ứng theo mã ClickUp — không tạo document mới, chỉ lưu file thô.
- Mọi file/scan phải đi qua `n8n-binary-and-data` skill patterns ($binary vs $json, CDN/URL requirement nếu cần gửi ảnh qua chat).

## 5. Chức năng Interview
- Chỉ mở cho task có tên chứa `el` (không phân biệt hoa thường) — cụ thể các công ty ELMC, ELHZ, ELHT hoặc pattern `el` chung. Dùng regex kiểm tra tên task, không hardcode danh sách công ty.
- Câu hỏi phỏng vấn (~20 câu) lưu trong bảng Postgres riêng (`interview_bank`) để Mr tự sửa/thêm câu hỏi qua ClickUp/Notion hoặc trực tiếp SQL — không hardcode trong workflow.
- Với mỗi câu: user trả lời tiếng Việt → AI đọc, tư vấn hướng trả lời phù hợp (tiếng Việt) → AI đưa ra câu trả lời mẫu tiếng Đức → next.
- Sau 20 câu: publish toàn bộ Q&A lên PrivateBin (có mã khóa), lưu URL + mã khóa vào comment của bảng kết quả phỏng vấn Supabase đã có sẵn — để dùng lại cho lần luyện tiếp theo (không tạo bảng Supabase mới).

## 6. Checklist bắt buộc khi Auditor (Sonnet 5) review
- [ ] Validate JSON cấu trúc workflow + kiểm tra toàn bộ connection source/target tồn tại trong `nodes` array.
- [ ] Nút Hủy bỏ thực sự xóa hết Postgres session rows + file OneDrive (test bằng cách kiểm tra DB/folder sau khi bấm Hủy).
- [ ] Nút Tạm dừng có thể resume đúng vị trí câu hỏi, không mất dữ liệu đã nhập.
- [ ] `chatId` luôn lấy qua reference tường minh (`$('NodeName').first().json.chat_id`), không dùng `$json.chat_id` trần sau node Postgres.
- [ ] Regex lọc task `el*` không match nhầm task không liên quan.
- [ ] Toàn bộ document tạo ra đúng tiếng Đức, không lẫn tiếng Việt/Anh.
- [ ] Không có bước nào block toàn bộ flow nếu 1 field optional bị thiếu (vd "giấy tờ khác nếu có").
- [ ] PrivateBin link có mã khóa, không public không mật khẩu.
