-- Mo rong gateway.group_chat_log (da tao truoc do) cho tinh nang ghi log tin nhan nhom +
-- tom tat AI hang dem + lenh /lichsu, /timkiem (Telebot Admin System).
ALTER TABLE gateway.group_chat_log ADD COLUMN IF NOT EXISTS message_thread_id BIGINT;
ALTER TABLE gateway.group_chat_log ADD COLUMN IF NOT EXISTS reply_to_message_id BIGINT;
CREATE INDEX IF NOT EXISTS idx_group_chat_log_user ON gateway.group_chat_log (user_id, chat_id);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_group_chat_log_text_trgm ON gateway.group_chat_log USING gin (message_text gin_trgm_ops);
