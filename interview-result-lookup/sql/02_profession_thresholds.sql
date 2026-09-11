-- Ngưỡng điểm riêng theo nghề (scope='profession') cho nhóm chế biến/làm bánh. Yêu cầu bảng
-- score_thresholds đã tồn tại (sql/01_score_thresholds.sql).
--
-- scope_value lưu KHÔNG DẤU vì node "Format tin nhắn kết quả" so khớp profession bằng cách bỏ dấu
-- (umlaut Đức: ä/ö/ü -> a/o/u; dấu tiếng Việt) rồi kiểm tra profession có CHỨA scope_value hay không.
-- Cách này bắt được các dòng dữ liệu profession bị ghép nhiều nghề, ví dụ:
--   "Fleischer"                        -> khớp 'fleischer'
--   "Koch/Köchin - Fleischer"          -> khớp 'fleischer'
--   "Bäcker/in", "Bäckerin"            -> khớp 'backer'
--   "Refa/Fachverkäufer/Koch/Bäcker"   -> khớp 'backer'
--   "Fachverkäufer/in, flex"           -> khớp 'flex'
--   "Làm bánh"                         -> khớp 'lam banh'
--   "Lebensmittelverarbeitung"         -> khớp 'lebensmittelverarbeitung' (chế biến thực phẩm)
INSERT INTO score_thresholds (scope, scope_value, threshold, note) VALUES
  ('profession', 'fleischer', 5.5, 'Nghề Fleischer (chế biến thịt)'),
  ('profession', 'backer', 5.5, 'Nghề Bäcker/Bäckerin (làm bánh, tiếng Đức)'),
  ('profession', 'lam banh', 5.5, 'Nghề làm bánh (tiếng Việt)'),
  ('profession', 'flex', 5.5, 'Nghề Flex'),
  ('profession', 'lebensmittelverarbeitung', 5.5, 'Chế biến thực phẩm (Lebensmittelverarbeitung)')
ON CONFLICT (scope, scope_value) WHERE scope_value IS NOT NULL
DO UPDATE SET threshold = EXCLUDED.threshold, note = EXCLUDED.note, updated_at = now();
