-- ============================================================================
-- GATEWAY SCHEMA v1.0 — chạy file này 2 LẦN: 1 lần trên Postgres Docker,
-- 1 lần trên Supabase SQL Editor. Idempotent (chạy lại không lỗi).
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS gateway;

-- ----------------------------------------------------------------------------
-- Người dùng của hệ thống bot (mọi nền tảng: telegram / zalo / discord ...)
-- status: pending -> active | denied | banned
-- role:   user | admin
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gateway.bot_users (
    user_id       TEXT NOT NULL,              -- ID trên nền tảng (telegram user id...)
    platform      TEXT NOT NULL DEFAULT 'telegram',
    username      TEXT,                        -- @username nếu có
    display_name  TEXT,
    status        TEXT NOT NULL DEFAULT 'pending',
    role          TEXT NOT NULL DEFAULT 'user',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (platform, user_id)
);

-- ----------------------------------------------------------------------------
-- Phân quyền user x bot (RBAC lớp 1)
-- bot_key: 'telebot_main' | 'help_bot' | 'crawl_bot' | ... (thêm tùy ý)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gateway.bot_permissions (
    platform    TEXT NOT NULL DEFAULT 'telegram',
    user_id     TEXT NOT NULL,
    bot_key     TEXT NOT NULL,
    granted_by  TEXT,                          -- admin user_id đã duyệt
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (platform, user_id, bot_key)
);

-- ----------------------------------------------------------------------------
-- Audit log: mọi tương tác inbound/outbound
-- request_id là correlation ID — dùng để truy vết 1 tin nhắn xuyên hệ thống
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gateway.interaction_logs (
    id           BIGSERIAL PRIMARY KEY,
    request_id   TEXT NOT NULL,
    platform     TEXT NOT NULL DEFAULT 'telegram',
    user_id      TEXT,
    username     TEXT,
    chat_id      TEXT,
    bot_key      TEXT,                         -- bot được route tới (null nếu chưa qua router)
    direction    TEXT NOT NULL DEFAULT 'in',   -- in | out | system
    event        TEXT,                         -- message | callback | approve | deny | error ...
    content      TEXT,                         -- nội dung tin nhắn / mô tả sự kiện
    meta         JSONB,                        -- payload phụ (media info, error stack...)
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_logs_request ON gateway.interaction_logs (request_id);
CREATE INDEX IF NOT EXISTS idx_logs_user    ON gateway.interaction_logs (platform, user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_time    ON gateway.interaction_logs (created_at DESC);

-- ----------------------------------------------------------------------------
-- Cấu hình hệ thống (thay cho hardcode trong workflow)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gateway.config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- ============================================================================
-- SEED — sửa ID admin nếu cần rồi chạy
-- ============================================================================
INSERT INTO gateway.bot_users (user_id, platform, display_name, status, role)
VALUES ('7030500584', 'telegram', 'Admin', 'active', 'admin')
ON CONFLICT (platform, user_id) DO UPDATE SET role = 'admin', status = 'active';

-- Admin có full quyền mọi bot
INSERT INTO gateway.bot_permissions (platform, user_id, bot_key, granted_by)
VALUES
  ('telegram', '7030500584', 'telebot_main', 'seed'),
  ('telegram', '7030500584', 'help_bot',     'seed'),
  ('telegram', '7030500584', 'crawl_bot',    'seed')
ON CONFLICT DO NOTHING;

INSERT INTO gateway.config (key, value) VALUES
  ('admin_chat_id', '7030500584'),
  ('available_bots', 'telebot_main,help_bot,crawl_bot')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
