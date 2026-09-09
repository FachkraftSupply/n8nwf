-- gateway.error_logs — lịch sử lỗi từ mọi workflow (ghi bởi GW Error Handler, đọc bởi
-- GW Weekly Error Report). status mặc định 'open'; đánh dấu 'fixed'/'ignored' thủ công
-- sau khi đã xử lý (chưa có cơ chế tự động — cập nhật tay qua psql hoặc 1 lệnh bot sau này).
CREATE TABLE IF NOT EXISTS gateway.error_logs (
  id SERIAL PRIMARY KEY,
  workflow_name TEXT,
  workflow_id TEXT,
  node_name TEXT,
  error_message TEXT,
  execution_id TEXT,
  execution_url TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_error_logs_status_time ON gateway.error_logs(status, occurred_at);
