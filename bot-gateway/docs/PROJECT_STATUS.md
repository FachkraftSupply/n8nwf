# PROJECT STATUS — Bot Gateway (bàn giao sang phiên chat mới)

> Dán file này (hoặc link GitHub của nó) vào đầu chat mới để Claude nắm đủ ngữ cảnh
> mà không cần đọc lại lịch sử debug dài ở phiên trước.

## Repo
`FachkraftSupply/n8nwf`, folder `bot-gateway/` — kết nối GitHub qua Composio (OAuth, không dùng token).

## Cấu trúc repo hiện tại
```
bot-gateway/
├── README.md
├── sql/01_gateway_schema.sql
├── workflows/
│   ├── original/                          5 workflow production NGUYÊN BẢN
│   └── new_architecture/
│       ├── GW_Gateway_Telegram.json       workflow Gateway (đang chạy trên n8n)
│       ├── GW_Error_Handler.json
│       └── sub_workflows_modernized/      5 workflow đã nâng n8n 2.37.7 + dual storage
└── docs/ (ARCHITECTURE, BOT_INVENTORY, GUIDE_DEPLOY_DATABASE, SETUP_PHASE_0_1, PROJECT_STATUS)
```

## Đã HOÀN THÀNH (Giai đoạn 0–1)
- Schema `gateway` (4 bảng) đã tạo trên CẢ Postgres Docker (`n8n_stack-postgres-1`, db `n8n`)
  và Supabase (project "Telegram authentication DB", ref `nlgmkfqtmarsdcqismzz`).
- Admin ID đúng: **`975005174`**, đồng bộ 2 DB + workflow.
- Đã import + gắn credential đủ (`Telegram Dev Bot`, `Telegram System Bot`, `Supabase Postgres`).
- Đã sửa lỗi cú pháp `queryReplacement` (phải dùng dạng mảng `={{ [$json.a, $json.b] }}`,
  không phải `={{ $json.a }},{{ $json.b }}`) ở 4 node Postgres đa tham số.
- Đã sửa lỗi Telegram "can't parse entities": node "Báo admin duyệt user" chèn username/text
  tự do của user vào tin nhắn có parse_mode Markdown mặc định -> ký tự _ * [ ] trong nội dung
  user gõ làm Telegram từ chối gửi. Đã set parse_mode='' (None) cho node này trên GitHub
  (commit cb1207f) — CẦN ANH TỰ SỬA field tương ứng trong n8n UI nếu workflow đang chạy
  chưa đồng bộ lại từ repo (Additional Fields -> Parse Mode -> None).
- Test #1 (admin route đúng) PASS.

## Đang làm dở — 7 test nghiệm thu (`docs/SETUP_PHASE_0_1.md`)
| # | Test | Trạng thái |
|---|---|---|
| 1 | Admin route đúng | PASS |
| 2 | User lạ -> chờ duyệt + admin nhận nút | PASS (sau fix parse_mode) |
| 3 | Admin bấm approve -> cả 2 bên nhận thông báo | PASS (sau fix chat_id + fix data Postgres phía admin) |
| 4 | User được duyệt dùng lệnh | Chưa test |
| 5 | User chưa có quyền bị chặn đúng cách | Chưa test |
| 6 | Log ghi đủ cả 2 DB | Chưa verify lại |
| 7 | Non-admin bấm nút approve bị chặn | Chưa test |

## Bot inventory (chi tiết: docs/BOT_INVENTORY.md)
- @elite_n8n_test_bot -> Gateway DEV (đang dùng)
- @Elite_clickup_bot -> Gateway PROD (Giai đoạn 4 - cutover)
- @elite_n8n_system_bot -> kênh Error Handler
- @Elite_system_bot (backup_data) -> output crawl_bot + BACKUP N8N
- @elite_tele_help_bot -> nghỉ hưu dần, gộp vào Gateway (bot_key: help_bot)

## VIỆC TIẾP THEO — Giai đoạn 2
Chuyển Elite Help Bot GPT (đã có bản modernized trong
workflows/new_architecture/sub_workflows_modernized/Elite_Help_Bot_GPT.json) thành sub-workflow:
1. ✅ XONG — Đã nối "When Executed by Another Workflow" (đã có sẵn trong file, trước đó bị bỏ trơ,
   nối thẳng qua node phân tích intent bỏ qua toàn bộ logic) qua node Code mới "Envelope → Legacy Shape"
   rồi mới vào "SET ENV" → Code1 (giữ 100% luồng cũ). Node adapter chỉ map field Envelope (mục 3
   ARCHITECTURE.md: text/chat_id/user_id/username) thành object `message.{text,chat.id,from.id,from.username}`
   mà Code1 đang parse, đồng thời spread nguyên envelope gốc (request_id, platform, auth, bot_key, route,
   callback, raw...) ra root để không mất Correlation ID khi đi tiếp xuống AI Agent.
   Commit: https://github.com/FachkraftSupply/n8nwf/commit/9262e2d6f50fbacac69ba8cb33b050059f71f395
2. ✅ Giữ nguyên 100% logic AI Agent / Notion / Switch (Intent) bên trong — không đụng.
3. ⏳ ĐANG CHỜ — Gắn workflow ID thật vào node "→ Sub: Help Bot" trong Gateway (đang placeholder
   REPLACE_HELP_BOT_ID). CẦN anh cung cấp workflow ID (hoặc URL) thật của "Elite Help Bot GPT" trên n8n live
   — Claude không có tool truy vấn n8n API trực tiếp trong phiên này (chỉ có Composio GitHub + Supabase MCP),
   không tự suy ra được ID.
4. Production Elite Help Bot GPT (trigger cũ, Telegram Trigger1 / Telegram Trigger PROD) vẫn chạy song song,
   không tắt — chưa động tới, chỉ thêm nhánh mới.

## Quy tắc làm việc để tránh phình context
- KHÔNG dán lại toàn bộ nội dung file JSON lớn vào chat để sửa 1-2 trường.
- Cách hiệu quả đã kiểm chứng: dùng Composio remote workbench (run_composio_tool trong
  COMPOSIO_REMOTE_WORKBENCH) để GET file từ GitHub -> sửa bằng Python trong sandbox ->
  COMMIT lại, tất cả không đi qua context chính của chat.
- File > 60KB cần thêm mới (chưa có trên GitHub) thì đóng gói zip, để user tự kéo-thả upload
  qua GitHub web UI thay vì dán vào chat.
- Credential Postgres docker: `Postgres account` (id iNVsYeDUnMl6pq4M).
  Credential Supabase: `Supabase Postgres`.


## LẦN SỬA MỚI NHẤT (sau lần cutover thử nghiệm)
- Lỗi "chat_id is empty" ở node "Bỏ qua (không phải admin)": nguyên nhân là node Postgres
  "Check admin" phía trước GHI ĐÈ toàn bộ $json bằng kết quả SQL (chỉ còn cột `role`), làm
  mất chat_id gốc. ĐÃ SỬA: chatId giờ đọc từ `{{ $('GW-01 Envelope').first().json.chat_id }}`
  thay vì `{{ $json.chat_id }}`. Đã rà toàn bộ workflow, không còn node nào khác mắc lỗi
  tương tự (mọi node khác đều đi qua Code node trung gian giữ nguyên envelope).
- Bài học chung: BẤT KỲ lúc nào thêm node Postgres/DB query vào giữa luồng, node theo SAU nó
  không được đọc thẳng $json cho các field gốc (chat_id, user_id...) — phải tham chiếu ngược
  về node Envelope hoặc Merge Auth bằng $('TênNode').first().json.field.


## Fix bổ sung (đã xong)
- "Bỏ qua (không phải admin)" từng báo sai admin không phải admin do dữ liệu Postgres
  (không phải lỗi workflow) — user đã tự sửa trực tiếp trên DB, đã hoạt động đúng.

## Việc tiếp theo khi mở chat mới
1. Test #4, #5, #6, #7 còn lại (xem docs/SETUP_PHASE_0_1.md mục Test nghiệm thu).
2. Sau khi 7/7 test pass -> bắt đầu Giai đoạn 2 (chuyển Elite Help Bot GPT thành sub-workflow).
