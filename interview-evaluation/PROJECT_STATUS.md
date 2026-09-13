# PROJECT STATUS — interview-evaluation (bàn giao sang phiên chat mới)

> Đọc file này để nắm trạng thái hiện tại của dự án interview-evaluation, không cần đọc lại lịch sử chat cũ.

## ✅ Trạng thái hiện tại

Production — Form v4.3 + Workflow v4-final đang chạy ổn định. Chấm điểm hiện **hoàn toàn do
evaluator con người nhập tay** qua form, 4 tiêu chí (mỗi tiêu chí /2 điểm, tổng /10):
- 🗣️ Phát âm (có tag "Ngọng")
- 👁️‍🗨️ Nghe hiểu & Phản xạ
- 💬 Nội dung câu trả lời
- 😊 Thái độ & Hình thức

Kết quả lưu vào Supabase bảng `interview_evaluations` (project "Test tiếng"), sau đó
`interview-result-lookup` đọc lại qua lệnh `/ketqua`.

## 🆕 Việc cần làm (yêu cầu mới từ Mr, 13/09/2026)

**Phát triển lại cách chấm điểm để thể hiện rõ điểm nào do MÁY (AI/tự động) chấm, điểm nào do
NGƯờI (evaluator) chấm.** Hiện tại toàn bộ 4 tiêu chí đều là người chấm, chưa có thành phần nào
máy chấm — đây là ý định mới, **CHƯA thiết kế**, chưa có code nào.

## ❓ Câu hỏi cần Mr xác nhận trước khi thiết kế lại

1. Tiêu chí nào nên chuyển sang máy chấm, tiêu chí nào giữ nguyên do người chấm? (trong 4 tiêu
   chí hiện có: Phát âm / Nghe hiểu & Phản xạ / Nội dung câu trả lời / Thái độ & Hình thức)
2. Máy chấm dựa trên input nào — audio ghi âm buổi phỏng vấn (hiện form không có, cần thêm
   bước thu âm/upload mới), hay text transcript người đánh giá gõ vào ô "Câu trả lời" của câu
   hỏi tình huống?
3. Điểm máy chấm và điểm người chấm hiển thị tách riêng ở đâu — trên form ngay lúc nhập, trên
   tin Telegram kết quả, trên ClickUp task, hay cả 3?
4. Tổng điểm cuối (`final_score`) tính thế nào khi có cả 2 nguồn — cộng thẳng, trung bình có
   trọng số, hay giữ 2 con số riêng không gộp?
5. Có cần sửa schema bảng `interview_evaluations` (Supabase) để thêm field phân biệt nguồn
   điểm không (vd `score_source` theo từng tiêu chí, hoặc field riêng `machine_score_x` /
   `human_score_x`)? Việc này ảnh hưởng cả `interview-result-lookup` (đang đọc từ bảng này qua
   `/ketqua`) và `score_thresholds` (ngưỡng điểm đậu/rớt hiện tính trên 1 con số tổng duy nhất).

## 🚧 Chưa bắt đầu build

Đây mới là ý định/yêu cầu, chưa có thiết kế hay code nào — cần Mr trả lời các câu hỏi ở trên
trước khi bắt đầu sửa form/workflow/schema.

## Link nhanh

- Repo: https://github.com/FachkraftSupply/n8nwf/tree/main/interview-evaluation
- README chi tiết: [`interview-evaluation/README.md`](./README.md)
