# PROJECT STATUS — interview-result-lookup (bàn giao sang phiên chat mới)

> Đọc file này vào đầu chat mới để nắm trạng thái hiện tại, không cần đọc lại lịch sử session cũ.
> Tường thuật chi tiết từng bước nằm trong `README.md` (mục Changelog) và git log của thư mục này.

## ✅ Trạng thái: LIVE, đã test qua Telegram thật (11/09/2026)

**Việc đã làm trong phiên này** (chuyển ngưỡng điểm "Đạt/Chưa đạt" từ hardcode sang cấu hình động):

1. Tạo bảng Supabase `score_thresholds` (project **"Test tiếng"**, id `oreodamslizkrmdpvgye`) — scope
   `company` / `profession` / `default`, RLS bật, chỉ `service_role` đọc/ghi. Migration ở
   `sql/01_score_thresholds.sql`, `02_profession_thresholds.sql`, `03_profession_exact_match.sql`.
2. Sửa workflow n8n **"Tra cứu kết quả phỏng vấn /ketqua (final)"**
   (`https://n8n.toididuhoc.net/workflow/1gPcUduwtUkbA1aX`, đang **active**):
   - Thêm node **"Supabase: Lấy ngưỡng điểm"**, node "Format tin nhắn kết quả" tra ngưỡng theo thứ tự
     **company > profession > default**, fallback cứng = 6 nếu bảng trống.
   - `company` so khớp **chính xác** (field sạch). `profession` so khớp **chính xác sau khi bỏ dấu**
     (không phải "chứa chuỗi" — đã thử "chứa chuỗi" trước rồi đổi lại vì nó vô tình khớp cả hồ sơ ghép
     nhiều nghề như `"Refa/Fachverkäufer/Koch/Bäcker"`).
   - Thêm lệnh **`/nguong`** — xem ngay trong Telegram ngưỡng đang áp dụng, không cần mở Supabase.
   - `/help` có thêm hướng dẫn `/nguong` + link Supabase Table Editor.
3. **Đã sửa 1 bug thật** phát hiện qua execution log (id 2199): `/nguong` lúc đầu bị Telegram trả về
   `400 can't parse entities` vì text chứa `_` trần trong `score_thresholds` (ngoài backtick) —
   `parse_mode: Markdown` (legacy) hiểu nhầm là mở italic không đóng → bot im lặng không trả lời.
   Đã bọc trong backtick, publish lại, xác nhận `/help` (không dính bug) chạy ngay sau đó vẫn OK.

## Ngưỡng hiện tại trong `score_thresholds`

| scope | scope_value | threshold |
|---|---|---|
| default | — | 6 |
| company | elmc, el, elhz, elts, elht, elnb, elmb, eltshz, eltsht | 5 |
| profession | fleischer, fleischer/-in, backer/in, backerin, flex, lam banh, lebensmittelverarbeitung, xay dung | 5.5 |

**Giả định chưa xác nhận với user**: `xay dung` (ngành xây dựng) hiện **chưa có dữ liệu thực tế** khớp
trong `interview_evaluations` — thêm sẵn theo yêu cầu, sẽ hoạt động khi có hồ sơ ghi đúng "xây dựng"
(không dấu). `lebensmittelverarbeitung` được suy ra là nghĩa của "chế biến" theo yêu cầu user — CHƯA
được user xác nhận đúng ý, chỉ có 1 dòng dữ liệu thật dùng từ này.

## Việc CHƯA làm / có thể cần làm tiếp

- Chưa test `/nguong` sau lần fix bug cuối (đã publish, nhưng chưa có execution log mới xác nhận —
  user nên gõ lại `/nguong` 1 lần để chắc chắn).
- User hỏi về việc thêm `ARCHITECTURE.md`/`RULES.md`/`PROJECT_STATUS.md` riêng theo đúng convention
  của `bot-gateway/docs/` — mới tạo `PROJECT_STATUS.md` này, CHƯA tạo `ARCHITECTURE.md`/`RULES.md`
  (README.md hiện đang gộp chung các nội dung đó, có thể tách sau nếu user muốn).
- Repo có credential Supabase cũ (`cISqWlLc6VmWWp7A` "Supabase account") lẫn credential thật đang
  dùng trên n8n live (`LLZ2H3Sv9uyj5V1a` "Supabase account test tiếng") — đã đồng bộ file backup JSON
  trong repo theo credential thật, nhưng nếu ai import lại file JSON vào 1 instance n8n khác, vẫn cần
  gán lại credentials theo hướng dẫn trong README mục "Cài đặt".

## Link nhanh

- n8n workflow: https://n8n.toididuhoc.net/workflow/1gPcUduwtUkbA1aX
- Supabase project "Test tiếng": https://supabase.com/dashboard/project/oreodamslizkrmdpvgye
- Supabase Table Editor: https://supabase.com/dashboard/project/oreodamslizkrmdpvgye/editor
- Repo: https://github.com/FachkraftSupply/n8nwf (thư mục `interview-result-lookup/`)
