-- gateway.image_action_queue — state ngắn hạn cho các nút follow-up (AI xoá nền, upscale, huỷ)
-- trên kết quả /xoanen của Bot Xử Lý Ảnh. Cùng lý do như clickup.upload_notify_queue: callback_data
-- Telegram giới hạn 64 byte, không đủ chỗ nhét file_id đầy đủ + ngữ cảnh khác.
CREATE TABLE IF NOT EXISTS gateway.image_action_queue (
  id SERIAL PRIMARY KEY,
  chat_id TEXT NOT NULL,
  message_id BIGINT,
  source_file_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
