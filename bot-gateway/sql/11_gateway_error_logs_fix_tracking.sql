-- Mo rong gateway.error_logs de luu lai CACH SUA sau khi 1 loi da duoc xu ly xong, tao thanh
-- 1 "fix knowledge base" ma agent (Claude Code) phien sau co the tra cuu qua workflow
-- "GW Error Knowledge" (webhook POST https://n8n.toididuhoc.net/webhook/gw-error-knowledge)
-- truoc khi bat dau debug 1 loi moi tuong tu, thay vi phai doc lai toan bo CHANGELOG.md.
--
-- Cot nay cung duoc chinh workflow "GW Error Knowledge" (node "Ensure Fix Columns") tu dong
-- ALTER idempotent moi lan chay - file nay chi de LUU CAU TRUC lai trong repo (tham khao),
-- khong phai buoc bat buoc phai chay tay.
ALTER TABLE gateway.error_logs ADD COLUMN IF NOT EXISTS fix_description TEXT;
ALTER TABLE gateway.error_logs ADD COLUMN IF NOT EXISTS fixed_at TIMESTAMPTZ;
ALTER TABLE gateway.error_logs ADD COLUMN IF NOT EXISTS fixed_by TEXT;
