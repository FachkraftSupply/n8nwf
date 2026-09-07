# GIẢI THÍCH CHI TIẾT — `SQL_ClickUp_Sync_Scheduler.json`

> Workflow này KHÔNG có node Code (chỉ dùng node có sẵn của n8n: Postgres, If, Loop, Execute Workflow)
> — giải thích Ý NGHĨA từng node, phù hợp người mới tìm hiểu n8n (chưa cần biết lập trình).

## Workflow này để làm gì?

Đây là "người điều phối" chạy ĐỊNH KỲ (mỗi 5 ngày, 1 giờ sáng) — nhiệm vụ DUY NHẤT là hỏi Postgres
"những List nào ĐANG được đăng ký tự động đồng bộ?" rồi LẦN LƯỢT gọi `SQL_ClickUp_Full_Reconcile.json`
xử lý TỪNG List một, thay vì tự làm việc đồng bộ (việc đó đã có `Full Reconcile` lo).

## Node `Schedule (mỗi 5 ngày, 1h sáng)`
Bộ đếm giờ tự động — không cần ai bấm tay, tới đúng lịch (5 ngày/lần, 1 giờ sáng) là workflow TỰ CHẠY.

## Node `Query Sync Targets`
Chạy câu SQL `SELECT * FROM clickup.sync_targets` — lấy TOÀN BỘ danh sách List đã được admin chọn qua
lệnh `/sync` trước đó.

## Node `Có List Nào Trong Bảng?`
Node KIỂM TRA ĐIỀU KIỆN (giống câu "if" trong lập trình, nhưng không cần viết code) — hỏi "kết quả
Query ở trên CÓ ít nhất 1 dòng hay không?":
- **CÓ** → đi sang nhánh `Loop Over Sync Targets` (xử lý từng List đã đăng ký).
- **KHÔNG** (bảng trống, chưa ai dùng `/sync` lần nào) → đi sang nhánh `Chạy Sync List Mặc Định`
  (dùng List cố định có sẵn trong `Full Reconcile`, để KHÔNG BỎ TRẮNG lần đồng bộ định kỳ này).

## Node `Loop Over Sync Targets`
Node LẶP — nhận TOÀN BỘ danh sách List, XỬ LÝ TỪNG CÁI MỘT (không làm đồng thời tất cả cùng lúc) —
tránh gọi ClickUp API dồn dập nhiều List cùng lúc, dễ bị chặn vì "gọi quá nhiều request".

## Node `Chạy Sync Cho List Này` / `Chạy Sync List Mặc Định`
Node ĐIỀU KHIỂN WORKFLOW KHÁC — gọi SANG `SQL_ClickUp_Full_Reconcile.json` như "nhờ 1 người khác làm
việc thay", truyền kèm `list_id` (List nào cần đồng bộ) và `testMode: false` (chạy THẬT, không giới
hạn số task). Có bật `waitForSubWorkflow: true` — nghĩa là CHỜ workflow kia làm XONG HẲN rồi mới quay
lại vòng lặp xử lý List tiếp theo (tránh chạy chồng chéo nhiều List cùng lúc).

## Sơ đồ tổng thể

```
Schedule (5 ngày) → Query Sync Targets → Có List Nào Trong Bảng?
    có   → Loop Over Sync Targets → Chạy Sync Cho List Này (gọi Full Reconcile, chờ xong) → quay lại Loop
    không → Chạy Sync List Mặc Định (gọi Full Reconcile, dùng List cố định)
```
