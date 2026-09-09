-- Mirror OneDrive-forward notifications to Zalo. Cột này được workflow tự tạo (node
-- "Ensure Zalo Notify Column" trong Telebot ClickUp Reader, chạy mỗi lần dùng tính năng forward),
-- file này chỉ để lưu lại lịch sử schema trong repo, KHÔNG cần chạy tay.
ALTER TABLE gateway.notify_targets ADD COLUMN IF NOT EXISTS zalo_chat_id TEXT;

-- Sau khi có Zalo group chat_id thật, điền vào đây (hoặc UPDATE trực tiếp qua psql/n8n):
-- UPDATE gateway.notify_targets SET zalo_chat_id = '<zalo_group_chat_id>' WHERE target_key = 'od_kammer_bav';
-- UPDATE gateway.notify_targets SET zalo_chat_id = '<zalo_group_chat_id>' WHERE target_key = 'od_hoadon';
-- UPDATE gateway.notify_targets SET zalo_chat_id = '<zalo_group_chat_id>' WHERE target_key = 'od_giayto';
-- Để trống (NULL) = không mirror sang Zalo cho category đó (mặc định hiện tại, an toàn — Send Zalo
-- Notify chỉ chạy khi zalo_chat_id có giá trị, xem node "Has Zalo Target?").
