-- ClickUp -> Postgres sync schema (chay tren Postgres Docker, credential "Postgres account")
-- Duoc n8n workflow "SQL - ClickUp to Postgres Sync" tu dong chay (CREATE ... IF NOT EXISTS)
-- moi lan sync, nhung cung co the chay tay 1 lan truoc de kiem tra.

CREATE SCHEMA IF NOT EXISTS clickup;

CREATE TABLE IF NOT EXISTS clickup.tasks (
  id              TEXT PRIMARY KEY,
  name            TEXT,
  name_khong_dau  TEXT,
  url             TEXT,
  description     TEXT,
  status          TEXT,
  phu_trach       TEXT,
  dkpv            TEXT,
  pvtc            TEXT,
  folder_name     TEXT,
  list_name       TEXT,
  vfs             TEXT,
  planbay         TEXT,
  ngaybay         TEXT,
  youtube_link    TEXT,
  onedrive_link   TEXT,
  color           TEXT,
  other_link      TEXT,
  date_updated    TIMESTAMPTZ,
  synced_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clickup_tasks_name_khong_dau
  ON clickup.tasks USING gin (to_tsvector('simple', coalesce(name_khong_dau,'')));
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_date_updated
  ON clickup.tasks (date_updated DESC);
