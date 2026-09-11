-- score_thresholds — ngưỡng điểm "Đạt/Chưa đạt" cấu hình trực tiếp trong Supabase, thay cho mảng
-- specialCompanies hardcode trong node "Format tin nhắn kết quả" (workflow interview-result-lookup).
-- Cho phép cấu hình riêng theo đối tác (company) hoặc theo nghề (profession), có 1 dòng default
-- dùng chung khi không có cấu hình riêng. Thứ tự ưu tiên khi tra cứu: company > profession > default.
-- Thêm/sửa ngưỡng cho đối tác/nghề mới chỉ cần INSERT/UPDATE 1 dòng, không cần sửa code node.
CREATE TABLE IF NOT EXISTS score_thresholds (
  id SERIAL PRIMARY KEY,
  scope TEXT NOT NULL CHECK (scope IN ('company', 'profession', 'default')),
  scope_value TEXT,
  threshold NUMERIC NOT NULL,
  note TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT score_thresholds_scope_value_check CHECK (
    (scope = 'default' AND scope_value IS NULL)
    OR (scope IN ('company', 'profession') AND scope_value IS NOT NULL)
  )
);

-- company/profession: mỗi giá trị chỉ 1 dòng (scope_value nên lưu sẵn dạng lowercase, trim)
CREATE UNIQUE INDEX IF NOT EXISTS score_thresholds_scope_value_uidx
  ON score_thresholds (scope, scope_value)
  WHERE scope_value IS NOT NULL;

-- default: chỉ cho phép 1 dòng duy nhất
CREATE UNIQUE INDEX IF NOT EXISTS score_thresholds_default_uidx
  ON score_thresholds (scope)
  WHERE scope = 'default';

-- Seed dữ liệu tương đương logic hardcode cũ (specialCompanies -> ngưỡng 5, còn lại -> ngưỡng 6).
-- Node "Format tin nhắn kết quả" vẫn có fallback = 6 trong code nếu bảng này trống/thiếu dòng default.
INSERT INTO score_thresholds (scope, scope_value, threshold, note) VALUES
  ('default', NULL, 6, 'Ngưỡng mặc định, áp dụng khi không có cấu hình riêng theo công ty/nghề'),
  ('company', 'elmc', 5, NULL),
  ('company', 'el', 5, NULL),
  ('company', 'elhz', 5, NULL),
  ('company', 'elts', 5, NULL),
  ('company', 'elht', 5, NULL),
  ('company', 'elnb', 5, NULL),
  ('company', 'elmb', 5, NULL),
  ('company', 'eltshz', 5, NULL),
  ('company', 'eltsht', 5, NULL)
ON CONFLICT DO NOTHING;

-- Ví dụ cấu hình ngưỡng riêng theo nghề (bỏ comment và chỉnh giá trị khi cần dùng):
-- INSERT INTO score_thresholds (scope, scope_value, threshold, note)
-- VALUES ('profession', 'dieu duong', 6.5, 'Ngành Điều dưỡng yêu cầu ngưỡng cao hơn')
-- ON CONFLICT DO NOTHING;

-- Tạm dừng 1 dòng ngưỡng (giữ lại lịch sử) mà không xoá:
-- UPDATE score_thresholds SET active = false WHERE scope = 'company' AND scope_value = 'elmc';
