-- gateway.notify_targets — bảng cấu hình nhóm/topic Telegram nhận thông báo, mở rộng được
-- (thêm nhóm/topic mới chỉ cần INSERT 1 dòng, không cần sửa code/workflow). Dùng lần đầu cho
-- tính năng "forward thông báo upload OneDrive" — xem PROJECT_STATUS.md mục ROADMAP để biết
-- kế hoạch dùng chung bảng này cho việc định tuyến thông báo hệ thống (category khác).
CREATE TABLE IF NOT EXISTS gateway.notify_targets (
  id SERIAL PRIMARY KEY,
  target_key TEXT UNIQUE NOT NULL,
  label TEXT NOT NULL,
  chat_id TEXT NOT NULL,
  topic_id TEXT,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO gateway.notify_targets (target_key, label, chat_id, topic_id, description, category) VALUES
('od_kammer_bav', '🏛️ Kammer/BAV', '-1002954420822', '2', 'Hợp đồng với Kammer và hợp đồng nghề BAV', 'onedrive_forward'),
('od_hoadon', '🧾 Hóa đơn', '-1002954420822', '6', 'Các loại hóa đơn', 'onedrive_forward'),
('od_giayto', '📄 Giấy tờ', '-1002954420822', '7', 'Nhập học muộn, giấy VAZ, xác nhận trình độ khóa tiếng, giấy bao ăn ở', 'onedrive_forward')
ON CONFLICT (target_key) DO NOTHING;

-- Trạng thái tạm 1 lượt upload để nút forward callback tra lại được (callback_data Telegram
-- giới hạn 64 byte, không đủ chỗ nhét tên file + link đầy đủ).
CREATE TABLE IF NOT EXISTS clickup.upload_notify_queue (
  id SERIAL PRIMARY KEY,
  chat_id TEXT NOT NULL,
  task_id TEXT,
  final_name TEXT NOT NULL,
  web_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
