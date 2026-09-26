# STATUS — Tổng quan dự án n8nwf (FS International)

> Đọc file này để nắm nhanh trạng thái + việc cần làm của TOÀN BỘ repo. Chi tiết đầy đủ từng dự
> án nằm ở `PROJECT_STATUS.md`/`STATUS.md` riêng của từng folder — xem cột link bên dưới.

Cập nhật lần cuối: 2026-09-26

## Tổng quan trạng thái từng dự án

| Folder | Trạng thái | Việc cần làm chính |
|---|---|---|
| [`bot-gateway/`](./bot-gateway/) | ✅ Production — vừa cutover Gateway v2 + Error Handler v2 (26/09) | Refactor tuần 39 đã live thật (`GW Gateway - Telegram v2` thay v1, `GW Error Handler v2` xử lý lỗi cho 7 workflow). Việc dọn dẹp còn lại: đổi tên bỏ "(STAGING)" khỏi 2 workflow đã lên production, archive workflow v1 sau 14 ngày (~10/10), quyết định có cutover tiếp `Admin v2 - Hệ thống` (đang pilot 1 domain, staging) hay không. **Export JSON của Gateway v2/Error Handler v2 vào `bot-gateway/workflows/` vẫn chưa cập nhật** (còn là bản v1 cũ) — xem [`bot-gateway/docs/PROJECT_STATUS.md`](./bot-gateway/docs/PROJECT_STATUS.md) (file rất dài, đọc từ trên xuống để lấy trạng thái mới nhất) |
| [`interview-evaluation/`](./interview-evaluation/) | ✅ Production, nhưng đang cần redesign | Phát triển lại cách chấm điểm để tách rõ điểm **MÁY** chấm vs **NGƯờI** chấm — yêu cầu mới từ Mr (13/09/2026), chưa thiết kế — xem [`interview-evaluation/PROJECT_STATUS.md`](./interview-evaluation/PROJECT_STATUS.md) |
| [`interview-result-lookup/`](./interview-result-lookup/) | ✅ Production, LIVE đã test | Còn 1 việc nhỏ: xác nhận lại `/nguong` chạy đúng sau lần fix bug cuối — xem [`interview-result-lookup/PROJECT_STATUS.md`](./interview-result-lookup/PROJECT_STATUS.md) |
| [`elite-interview-bot/`](./elite-interview-bot/) | 📝 Thiết kế, chưa build | 6 câu hỏi blocker cần Mr xác nhận trước khi build (route Gateway hay độc lập, mã ClickUp là gì, format comment OneDrive, model AI, giới hạn hồ sơ khác, trùng lặp với interview-evaluation/interview-result-lookup?) — xem [`elite-interview-bot/STATUS.md`](./elite-interview-bot/STATUS.md) |

## Việc cần làm tổng hợp (thứ tự đề xuất)

1. **bot-gateway** — dọn dẹp hậu cutover W39 (đổi tên workflow, archive v1, export JSON v2, quyết định Admin System v2).
2. **interview-evaluation** — Mr trả lời các câu hỏi thiết kế lại cách chấm điểm máy/người (xem file status folder đó).
3. **elite-interview-bot** — Mr trả lời 6 câu hỏi blocker trước khi bắt đầu build.
4. **interview-result-lookup** — xác nhận lại `/nguong` hoạt động đúng (việc nhỏ, làm bất kỳ lúc nào).

## Cách cập nhật file này

Mỗi khi 1 dự án con đổi trạng thái đáng kể (chuyển Production, phát hiện việc mới, hoàn tất 1
hạng mục lớn), cập nhật bảng trên NGAY — không cần tường thuật chi tiết ở đây, chi tiết đầy đủ
đã nằm ở PROJECT_STATUS.md/STATUS.md riêng của từng folder.
