# CHANGELOG — Bot Luyện Phỏng Vấn & Tự Động Tạo Hồ Sơ

## 2026-09-13
- Khởi tạo bộ tài liệu kiến trúc: `STATUS.md`, `RULES.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `CHANGELOG.md` trong folder `elite-interview-bot/` của repo `n8nwf`.
- Ban đầu tạo nhầm ở repo riêng `elite-interview-bot` — đã chuyển vào `n8nwf` theo yêu cầu vì dự án vẫn thuộc hệ sinh thái n8n.
- Chốt ý tưởng tổng thể: bot Telegram xác thực qua mã ClickUp (cấp sau khi test tiếng), kiểm tra comment có link OneDrive, sau đó mở 2 chức năng Upload hồ sơ và Interview.
- Chốt công cụ publish tạm có mã khóa: PrivateBin, self-host trên VPS hiện có.
- Ghi nhận 5 câu hỏi blocker cần Mr xác nhận trước khi bắt đầu build (xem `STATUS.md`), cộng thêm câu hỏi thứ 6 về việc rà soát `interview-evaluation/` và `interview-result-lookup/` đã có sẵn.
