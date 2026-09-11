-- Sửa lại cách so khớp ngưỡng theo nghề: chuyển từ "chứa chuỗi" (02_profession_thresholds.sql)
-- sang KHỚP CHÍNH XÁC. Lý do: cách "chứa chuỗi" vô tình áp ngưỡng 5.5 cho các hồ sơ ghi ghép nhiều
-- nghề trong 1 chuỗi, ví dụ "Refa/Fachverkäufer/Koch/Bäcker" (chỉ là 1 trong 4 kỹ năng liệt kê,
-- không phải nghề chính) hay "Fachverkäufer/in, flex". Node "Format tin nhắn kết quả" giờ chỉ áp
-- ngưỡng riêng khi profession KHỚP CHÍNH XÁC (sau khi bỏ dấu) với 1 scope_value đã cấu hình — hồ sơ
-- ghép nhiều nghề sẽ rơi về ngưỡng default trừ khi có dòng riêng cho đúng cách ghi đó.
--
-- Bỏ 'backer' (scope_value cũ dùng cho khớp chuỗi), thay bằng các biến thể chính xác thật có trong
-- dữ liệu. Thêm ngành xây dựng (chưa có hồ sơ thực tế, thêm sẵn để dùng khi có).
DELETE FROM score_thresholds WHERE scope = 'profession' AND scope_value = 'backer';

INSERT INTO score_thresholds (scope, scope_value, threshold, note) VALUES
  ('profession', 'backer/in', 5.5, 'Bäcker/in (làm bánh, tiếng Đức) — khớp chính xác, không khớp chuỗi ghép nhiều nghề'),
  ('profession', 'backerin', 5.5, 'Bäckerin (làm bánh, tiếng Đức) — khớp chính xác'),
  ('profession', 'fleischer/-in', 5.5, 'Biến thể "Fleischer/-in" — khớp chính xác'),
  ('profession', 'xay dung', 5.5, 'Ngành xây dựng (Vietnamese) — chưa có dữ liệu thực tế, thêm sẵn khi có hồ sơ')
ON CONFLICT (scope, scope_value) WHERE scope_value IS NOT NULL
DO UPDATE SET threshold = EXCLUDED.threshold, note = EXCLUDED.note, updated_at = now();

-- Sau khi chạy: profession = 'fleischer', 'fleischer/-in', 'backer/in', 'backerin', 'flex',
-- 'lam banh', 'lebensmittelverarbeitung', 'xay dung' đều ở ngưỡng 5.5.
-- Ghi chú: các hồ sơ ghi ghép nhiều nghề (vd "Koch/Köchin - Fleischer", "Koch/Köchin, làm bánh, bán
-- bánh") từ nay rơi về ngưỡng default (6) vì không còn khớp chuỗi con — nếu công ty vẫn muốn các hồ
-- sơ ghép đó được ưu đãi, thêm scope_value đúng y nguyên cách ghi đó (vd 'koch/kochin - fleischer').
