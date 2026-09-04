CREATE SCHEMA IF NOT EXISTS clickup;

CREATE TABLE IF NOT EXISTS clickup.tasks (
  id                TEXT PRIMARY KEY,
  name              TEXT,
  name_khong_dau    TEXT,
  url               TEXT,
  description       TEXT,
  status            TEXT,
  team_id           TEXT,
  space_id          TEXT,
  folder_id         TEXT,
  folder_name       TEXT,
  list_id           TEXT,
  list_name         TEXT,
  phu_trach         TEXT,
  b1_datum          TEXT,
  dob               TEXT,
  ma_hd             TEXT,
  nghe              TEXT,
  sdt               TEXT,
  email             TEXT,
  dia_chi_vn        TEXT,
  vfs               TEXT,
  du_kien_den_duc   TEXT,
  ngay_xuat_canh    TEXT,
  dkpv_2026         TEXT,
  pvtc_2026         TEXT,
  nha_cua_support   TEXT,
  youtube_link      TEXT,
  onedrive_link     TEXT,
  date_updated      TIMESTAMPTZ,
  synced_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clickup_tasks_name_khong_dau
  ON clickup.tasks USING gin (to_tsvector('simple', coalesce(name_khong_dau,'')));
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_date_updated
  ON clickup.tasks (date_updated DESC);
