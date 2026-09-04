# BOT INVENTORY — sơ đồ gán bot Telegram vào Gateway

> Anh có 8 bot Telegram (BotFather). Bảng dưới xác định vai trò từng bot trong kiến trúc
Gateway mới, để không ai nhầm lẫn khi gắn credential trong n8n.

## Bảng ánh xạ

| Bot (BotFather) | Username | Vai trò trong Gateway | Ghi chú |
|---|---|---|---|
| Elite N8N Test Bot | @elite_n8n_test_bot | Gateway DEV — gắn vào Telegram Trigger của GW Gateway - Telegram (DEV) | Dùng cho Giai đoạn 0–3, test trước khi cutover |
| ClickupElite | @Elite_clickup_bot | Gateway PROD (Giai đoạn 4 — cutover) | User đã quen nhắn bot này để tra task -> giữ nguyên trải nghiệm, chỉ đổi bộ não phía sau thành Gateway |
| elite_n8n_system_main | @elite_n8n_system_bot | Kênh báo lỗi hệ thống — gắn vào node Báo admin Telegram trong GW Error Handler | Tách riêng khỏi bot chính: nếu bot chính chết, kênh báo lỗi vẫn phải sống |
| Elite_backup_data | @Elite_system_bot | Kênh output cho crawl_bot (lưu trữ/tóm tắt chat) + nơi BACKUP N8N gửi file backup | Giữ nguyên chức năng hiện tại |
| Elite Help Bot | @elite_tele_help_bot | Nghỉ hưu dần sau cutover | Chức năng gộp vào Gateway làm bot_key: help_bot (lệnh /ask hoặc tin nhắn tự do). Lý do: một cửa duy nhất, AI tự route theo lệnh, quyền vẫn kiểm soát riêng từng chức năng — duy trì bot riêng cho help buộc user phải nhớ hỏi thì nhắn bot A, tra task thì nhắn bot B, đúng vấn đề kiến trúc cũ |
| Trợ lý hồ sơ Elite | @fs_claude_bot | Ngoài phạm vi hệ Gateway | Không đụng |
| Elite Bề Bề Bot | @HA89clawbot | Ngoài phạm vi hệ Gateway | Không đụng |
| Openclaw của Hải Anh | @thukichandai_bot | Ngoài phạm vi hệ Gateway | Không đụng |

## Credential cần tạo trong n8n

| Tên credential (n8n) | Token của bot | Dùng cho |
|---|---|---|
| Telegram Dev Bot | @elite_n8n_test_bot | Mọi node Telegram trong GW Gateway - Telegram (DEV) |
| Telegram System Bot | @elite_n8n_system_bot | Node Báo admin Telegram trong GW Error Handler |
| Telegram Prod Bot (tạo sau, chưa dùng ở Phase 0–1) | @Elite_clickup_bot | Chỉ gắn khi cutover (Giai đoạn 4) |

⚠️ Lưu ý webhook: 1 bot Telegram chỉ có 1 webhook active tại một thời điểm. Trước khi
gắn @elite_n8n_test_bot vào Gateway, kiểm tra không workflow nào khác đang active dùng
bot này làm trigger — workflow active sau sẽ giật webhook của workflow trước, làm workflow
kia ngừng nhận tin ngay lập tức mà không có cảnh báo.

## Liên quan node ⚙️ Config trong GW Gateway

ADMIN_CHAT_ID vẫn là chat ID của admin (không phải bot ID) — không đổi gì ở đây, chỉ cần
đảm bảo admin đã /start với cả @elite_n8n_test_bot và @elite_n8n_system_bot để 2 bot
này được phép gửi tin cho admin.
