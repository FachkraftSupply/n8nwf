-- Mở rộng gateway.notify_targets (xem 04_gateway_notify_targets.sql) sang category
-- 'system_notify' — định tuyến 3 loại thông báo hệ thống + 1 catch-all vào nhóm
-- -1003647848349, theo yêu cầu 09/09/2026. Nguồn dùng từng target_key: xem CHANGELOG.md
-- cùng ngày (GW Error Handler, SQL - ClickUp Live Update, SQL - Backup System).
INSERT INTO gateway.notify_targets (target_key, label, chat_id, topic_id, description, category) VALUES
('sys_clickup', '🔄 Cập nhật ClickUp', '-1003647848349', '2', 'Thông báo khi có task ClickUp được cập nhật (không phải tìm task)', 'system_notify'),
('sys_schedule', '⏰ Hệ thống / Lịch chạy', '-1003647848349', '6', 'Thông báo tác vụ theo lịch (sync, backup...)', 'system_notify'),
('sys_error', '🚨 Lỗi hệ thống', '-1003647848349', '4', 'Thông báo lỗi workflow', 'system_notify'),
('sys_catchall', '📋 Khác', '-1003647848349', '1', 'Thông báo chưa phân loại — CHƯA có nguồn nào nối vào, giữ chỗ cho tương lai', 'system_notify')
ON CONFLICT (target_key) DO NOTHING;
