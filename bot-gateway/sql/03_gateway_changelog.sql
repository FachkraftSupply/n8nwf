-- gateway.changelog — nguồn dữ liệu cho lệnh /version (Telebot Admin System).
-- Không có hệ version số hình thức trước đây trong dự án; bảng này định nghĩa versioning
-- đơn giản (v1, v2, ...) theo mốc ngày thật lấy từ CHANGELOG.md, KHÔNG thay thế CHANGELOG.md/
-- FEATURE_CATALOG.md (những file đó vẫn là nguồn chi tiết đầy đủ — /version chỉ trỏ link sang).
CREATE TABLE IF NOT EXISTS gateway.changelog (
  id SERIAL PRIMARY KEY,
  version TEXT NOT NULL,
  released_at DATE NOT NULL,
  bot_key TEXT,
  summary TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO gateway.changelog (version, released_at, bot_key, summary) VALUES
('v1', '2026-09-03', 'gateway', 'Gateway core: xac thuc user, tu onboarding, duyet/tu choi qua callback, dinh tuyen lenh (COMMAND_MAP), audit log'),
('v2', '2026-09-05', 'background', 'ClickUp Live Update (webhook real-time) dong bo task/comment ngay khi co thay doi ben ClickUp'),
('v3', '2026-09-06', 'telebot_main', 'Redesign /task chi tiet: nhan in dam xuong dong, link vua bam-mo vua copy duoc, them Youtube link con thieu; /sync + /sync_status + /db_status cho admin'),
('v4', '2026-09-07', 'admin', 'Tach Telebot Admin System thanh bot rieng (@elite_n8n_system_bot); SQL Full Reconcile + Sync Scheduler da ngay'),
('v5', '2026-09-08', 'gateway', 'Cutover sang bot PROD (@Elite_clickup_bot); Bot Xu Ly Anh: /xoanen (remove.bg) + /tomtat (OCR Mistral native + tom tat AI); fix loi parse_mode crash thong bao duyet user'),
('v6', '2026-09-08', 'admin', '/user_list: danh sach user dang hyperlink, panel chi tiet voi Them/Xoa quyen, Cap tat ca quyen, Block user, Xoa hoan toan (dual-write Postgres + Supabase)'),
('v7', '2026-09-08', 'telebot_main', 'Upload OneDrive tu chi tiet task: chon ten file (preset/tuy chinh/giu nguyen) roi gui anh/tai lieu, upload dung folder OneDrive cua task (dang debug - nut chua phan hoi)'),
('v8', '2026-09-09', 'admin', 'Them lenh /version (chi admin) doc gateway.changelog, tro link sang FEATURE_CATALOG.md day du')
ON CONFLICT DO NOTHING;
