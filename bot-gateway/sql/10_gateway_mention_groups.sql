-- Tính năng "nhóm mention" (@@<ten_nhom> / @@all) — admin tạo nhóm chứa danh sách user qua
-- /tao_group + /user_list mở rộng; user thường gõ @@<ten_nhom> trong 1 nhóm Telegram để mention
-- tất cả user trong đó. ALTER thật chạy trong node "Ensure Mention Tables" của workflow
-- GW Mention Resolver, file này chỉ lưu lịch sử schema.
CREATE TABLE IF NOT EXISTS gateway.mention_groups (
  id SERIAL PRIMARY KEY,
  group_key TEXT UNIQUE NOT NULL,
  label TEXT NOT NULL,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS gateway.mention_group_members (
  group_id INT NOT NULL REFERENCES gateway.mention_groups(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  PRIMARY KEY (group_id, user_id)
);
