-- Mở rộng clickup.upload_notify_queue cho tính năng "xóa file vừa upload" +
-- "xóa & thu hồi tin đã forward" (09/09/2026). ALTER thật chạy trong node
-- "Ensure Notify Queue Columns" của Telebot ClickUp Reader, file này chỉ lưu lịch sử schema.
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS drive_id TEXT;
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS item_id TEXT;
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS fwd_chat_id TEXT;
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS fwd_message_id TEXT;
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS zalo_chat_id_used TEXT;
ALTER TABLE clickup.upload_notify_queue ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
