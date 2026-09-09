# BOT GATEWAY ARCHITECTURE v1.0

> **Mục đích của tài liệu này**: Cho phép một AI (Claude/GPT) hoặc kỹ sư mới đọc xong là
> triển khai lại toàn bộ hệ thống bot trên một nền tảng nhắn tin khác (Zalo, Discord,
> WhatsApp, Slack...) trong trường hợp Telegram không còn khả dụng tại Việt Nam.
> Hệ thống chạy trên n8n self-hosted (>= 2.37.x), Postgres trong Docker + Supabase.

---

## 1. Nguyên tắc thiết kế

1. **Một Gateway duy nhất cho mỗi nền tảng** — mọi tin nhắn đi qua 1 trigger, không bot
   chức năng nào có trigger riêng. Bảo mật tập trung: không thể gọi tắt logic mà không
   qua xác thực.
2. **Business logic là platform-agnostic** — các sub-workflow (Telebot Main, Help Bot,
   Crawl Bot...) chỉ nhận **Message Envelope** chuẩn hóa, không biết gì về Telegram.
   Đổi nền tảng = viết lại DUY NHẤT lớp Adapter (Gateway), không đụng business logic.
3. **Dual storage** — mọi dữ liệu (user, quyền, log) ghi song song Postgres Docker
   (primary) + Supabase (secondary, offsite). Nhánh Supabase luôn set
   `onError: continueRegularOutput` để không kéo sập luồng chính.
4. **Correlation ID** — mỗi tin nhắn sinh 1 `request_id` tại Gateway, đi xuyên suốt mọi
   sub-workflow và mọi dòng log. Debug = truy 1 ID.

## 2. Sơ đồ luồng

```
Platform Trigger (telegram | zalo | discord ...)
   │
   ▼
⚙️ Config (Code node: ADMIN_CHAT_ID, COMMAND_MAP, DEFAULT_BOT)
   │
   ▼
GW-01 Envelope  ──────────────► Audit Log (Docker) ‖ Audit Log (Supabase)
   │
   ▼
Loại update? ──┬─ message ──► GW-02 Auth ──► GW-02b Merge ──► Trạng thái user?
               │                                    ├─ new     → tạo pending + báo user
               │                                    │            + inline keyboard cho admin
               │                                    ├─ pending → nhắc chờ duyệt
               │                                    ├─ denied  → từ chối lịch sự
               │                                    └─ active  → GW-03 Router → Route bot?
               │                                                   ├→ Sub: Telebot Main
               │                                                   ├→ Sub: Help Bot
               │                                                   ├→ Sub: Crawl Bot
               │                                                   ├→ "không có quyền"
               │                                                   └→ "lệnh không hợp lệ"
               └─ callback ─► Check admin ─► Là admin? ─► Parse ─► Approve/Deny quyền
                                                                    → báo admin + báo user
```

## 3. Message Envelope Spec (HỢP ĐỒNG cốt lõi — KHÔNG được đổi khi thêm nền tảng)

Mọi adapter PHẢI chuẩn hóa update thô của nền tảng về đúng object này trước khi đi tiếp:

```jsonc
{
  "request_id":  "req_1725400000000_a1b2c3",  // sinh tại Gateway, unique
  "platform":    "telegram",                   // telegram | zalo | discord | ...
  "kind":        "message",                    // message | callback
  "user_id":     "123456789",                  // LUÔN là string, ID gốc của nền tảng
  "username":    "nguyenvana",                 // rỗng nếu nền tảng không có
  "display_name":"Nguyễn Văn A",
  "chat_id":     "123456789",                  // nơi cần reply về
  "text":        "/task DH-2026-001",          // text hoặc caption
  "command":     "task",                        // từ đầu tiên sau '/', null nếu không có
  "callback":    { "id":"...", "data":"ap:123:help_bot", "message_id": 42 }, // null nếu kind=message
  "has_media":   false,
  "ts":          "2026-09-04T10:00:00.000Z",
  "raw":         { }                            // update gốc, để sub-workflow cần chi tiết thì tự lấy
}
```

Sub-workflow nhận thêm 2 field do Gateway gắn sau auth/router:
`auth: {state, role, bots[]}` và `bot_key`, `route`.

## 4. Database schema

File `01_gateway_schema.sql` — chạy trên CẢ Postgres Docker VÀ Supabase. 4 bảng:

| Bảng | Vai trò |
|---|---|
| `gateway.bot_users` | user + status (pending/active/denied/banned) + role (user/admin). PK (platform, user_id) — cùng 1 người trên 2 nền tảng là 2 record. |
| `gateway.bot_permissions` | RBAC lớp 1: user × bot_key |
| `gateway.interaction_logs` | audit log, index theo request_id / user / time |
| `gateway.config` | admin_chat_id, available_bots — không hardcode trong workflow |

## 5. Giao thức approve (callback_data)

Telegram giới hạn callback_data 64 byte nên format tối giản:
- Cấp quyền 1 bot: `ap:<user_id>:<bot_key>`
- Cấp tất cả:      `ap:<user_id>:ALL` (đọc danh sách từ `gateway.config.available_bots`)
- Từ chối:         `dn:<user_id>:-`

Bảo mật: nhánh callback LUÔN kiểm tra người bấm có `role='admin'` trong DB trước khi
thực thi — chống trường hợp tin nhắn approve bị forward cho người khác bấm.

## 6. HƯỚNG DẪN TRIỂN KHAI NỀN TẢNG DỰ PHÒNG (dành cho AI)

Khi cần dựng adapter mới (ví dụ Zalo), làm đúng 6 bước, KHÔNG sửa sub-workflow:

1. **Clone workflow `GW Gateway - Telegram`**, đổi tên `GW Gateway - Zalo`.
2. **Thay Trigger**: Telegram Trigger → Webhook node nhận event từ Zalo OA
   (hệ thống đã có sẵn `ZALO BOT DEV` workflow chứa mẫu nhận/gửi Zalo — tham khảo nó).
3. **Viết lại GW-01 Envelope**: map payload Zalo về đúng Envelope Spec mục 3.
   Zalo: `sender.id` → user_id; `message.text` → text; Zalo KHÔNG có username → để rỗng;
   `platform: 'zalo'`.
4. **Thay các node gửi tin** (Telegram send) bằng HTTP Request tới Zalo OA API
   (`https://openapi.zalo.me/v3.0/oa/message/cs`). Inline keyboard admin → Zalo dùng
   template buttons hoặc fallback: admin trả lời bằng lệnh `/approve <user_id> <bot_key>`
   — Gateway đã route lệnh qua COMMAND_MAP nên chỉ cần thêm entry `approve`.
5. **DB dùng chung** — không tạo bảng mới. User Zalo là record mới với `platform='zalo'`.
   Admin phải được seed lại cho platform zalo (INSERT bot_users với zalo user_id của admin).
6. **Sub-workflow giữ nguyên 100%** — chúng chỉ đọc Envelope. Duy nhất lưu ý: node nào
   bên trong sub-workflow reply trực tiếp Telegram thì phải chuyển thành trả kết quả về
   Gateway để Gateway gửi (nguyên tắc: CHỈ Gateway được nói chuyện với nền tảng).

Checklist nghiệm thu adapter mới: gửi tin từ user lạ → nhận thông báo chờ duyệt →
admin approve → user dùng được lệnh → kiểm tra `interaction_logs` có đủ record với
`platform` mới → rút mạng Supabase thử → luồng chính vẫn chạy.

## 7. Vận hành & Debug

- Truy vết 1 tin nhắn: `SELECT * FROM gateway.interaction_logs WHERE request_id = 'req_...' ORDER BY id;`
- Lịch sử 1 user:      `SELECT * FROM gateway.interaction_logs WHERE user_id='...' ORDER BY created_at DESC LIMIT 50;`
- Ai đang dùng bot gì: `SELECT user_id, array_agg(bot_key) FROM gateway.bot_permissions GROUP BY user_id;`
- Lỗi runtime: workflow `GW Error Handler` (Error Trigger) báo Telegram admin kèm tên
  workflow, node lỗi, message. Gán nó vào Settings → Error Workflow của MỌI workflow.
- Đối soát dual storage: so `count(*)` interaction_logs giữa 2 DB theo ngày; lệch = Supabase
  từng down (chấp nhận được vì là secondary, có thể backfill từ primary).

## 8. Lộ trình migration từ hệ cũ (production không gián đoạn)

Hệ cũ (Telebot main/sql, Elite Help, Elite Crawl — mỗi bot 1 trigger riêng) TIẾP TỤC
chạy nguyên trạng trong toàn bộ quá trình. Gateway build trên **bot Telegram DEV riêng**.

| Phase | Việc | Điều kiện chuyển phase |
|---|---|---|
| 0 | Chạy DDL trên 2 DB, tạo bot dev, seed admin | SQL chạy không lỗi trên cả 2 DB |
| 1 | Import Gateway + Error Handler, gắn credential, test luồng approve | User lạ nhắn bot dev → approve → dùng được |
| 2 | Chuyển Elite Help Bot thành sub-workflow (thêm Execute Workflow Trigger nhận Envelope) | Bot dev trả lời đúng như bot prod |
| 3 | Đập đi làm lại Telebot Main -> "Telebot ClickUp Reader" (workflow mới, gọn hơn, bỏ /taotask + zalo + xử lý ảnh); chuyển Crawl Bot tương tự; chạy song song 1-2 tuần, so log | Log 2 hệ khớp, không lỗi mới |
| 4 | Cutover: đổi credential trigger Gateway sang bot prod; TẮT trigger các workflow cũ nhưng GIỮ workflow 30 ngày | Rollback = đổi lại credential (< 1 phút) |
| 5 | Xoá workflow cũ, cập nhật tài liệu này | — |

## 9. Nợ kỹ thuật thực tế + định hướng refactor (đúc kết từ vận hành, cập nhật 09/09/2026)

Mục 1-8 ở trên là bản thiết kế v1.0 gốc. Sau nhiều phiên vận hành/vá lỗi thật, hệ thống đã lệch
khỏi thiết kế gốc ở vài điểm — ghi lại đây để phiên refactor sau này không phải dò lại từ đầu.

**9.1. Vi phạm nguyên tắc "1 Gateway duy nhất"**: `Telebot Admin System` có Telegram Trigger RIÊNG
(bot `@elite_n8n_system_bot`), không qua Gateway — trái mục 1.1. Lý do chấp nhận: admin cần 1 bot
tách biệt hoàn toàn khỏi bot user thường để không lẫn quyền/nhầm ngữ cảnh. Nếu refactor: có thể giữ
nguyên (đây là quyết định có chủ đích, không phải nợ kỹ thuật cần xoá), nhưng nên tài liệu hoá rõ đây
là "Gateway thứ 2" dành riêng cho admin, không phải ngoại lệ tạm thời.

**9.2. Bẫy `inlineKeyboard`/`replyMarkup` set bằng expression động — đã gây ≥3 lần lỗi im lặng**:
n8n KHÔNG áp dụng field này khi set bằng 1 expression cho CẢ field (`={{ $json.xxxKeyboard }}`) —
gửi tin nhắn thành công nhưng hoàn toàn không có nút, không lỗi không cảnh báo. Đã xảy ra ở: nút
Upload OneDrive, menu chọn tên file, (suýt) panel user. Cách khắc phục ĐÚNG (đã áp dụng): rẽ nhánh
IF trước khi gửi, mỗi nhánh 1 node Telegram với `inlineKeyboard` là OBJECT TĨNH (chỉ nội dung
`text`/`callback_data` bên trong mới được là expression). Refactor nên: (a) audit lại TOÀN BỘ node
Telegram còn set `inlineKeyboard` bằng expression cho cả field (tìm bằng cách grep JSON export cho
`"inlineKeyboard": "="`), (b) cân nhắc viết 1 sub-workflow "Send With Keyboard" dùng chung nếu n8n
sau này không hỗ trợ tốt hơn.

**9.3. `addConnection`/`removeConnection` qua n8n MCP dùng SAI tên field (`sourceOutput`/`targetInput`
thay vì `sourceIndex`/`targetIndex`) bị ÂM THẦM bỏ qua** — xem RULES.md #13. Đây là nguyên nhân gốc
của nhiều lần "connection dồn hết vào 1 output" tưởng là lỗi build tay. Đã sửa dùng đúng tên từ
09/09/2026, nhưng CÁC WORKFLOW CŨ có thể vẫn còn sai sót kiểu này chưa bị phát hiện (chỉ lộ ra khi
route đó thực sự được test). Refactor nên: viết 1 script/checklist đối chiếu `rules.values` của mọi
Switch/IF node với `connections` JSON tương ứng, xác nhận số output khớp số connection.

**9.4. Whitelist prefix callback trong `GW-03 Router` (`resolveBotKeyForCallback`) là danh sách
`startsWith()` hardcode, phải cập nhật tay MỖI KHI sub-workflow thêm callback prefix mới** — đã quên
2 lần (`od_` lúc đầu, rồi `odfwd_`/`odhelp`/`od_cancel` lúc sau), gây bug im lặng "bấm nút không phản
hồi gì" (0 execution ở sub-workflow đích, không lỗi ở Gateway vì route hợp lệ `no_permission`/
`unknown` vẫn "thành công"). Refactor đề xuất: mỗi sub-workflow tự khai báo prefix của mình vào 1
bảng `gateway.callback_prefixes` (bot_key, prefix) thay vì hardcode trong code Gateway — Gateway chỉ
cần `SELECT bot_key FROM gateway.callback_prefixes WHERE $1 LIKE prefix || '%' LIMIT 1`.

**9.5. State tạm thời (multi-turn) hiện chỉ có 1 bảng bespoke `clickup.pending_uploads`** — nếu thêm
tính năng multi-turn khác (ở bot khác), sẽ lại phải tạo bảng riêng + sửa Gateway ép route y hệt
pattern đã làm cho OneDrive upload. Refactor đề xuất: gộp thành 1 bảng chung
`gateway.pending_state (chat_id PK, bot_key, state_type, payload JSONB, created_at)` — Gateway chỉ
cần 1 lần logic "có pending_state thì ép route theo bot_key của nó", không cần sửa thêm mỗi tính
năng mới.

**9.6. Rủi ro 2 phiên chat sửa song song CÙNG 1 workflow** — đã xảy ra thật (09/09/2026, xem
CHANGELOG cùng ngày), gây lệch `Switch (Admin Extras)` giữa 2 phiên không biết về nhau. Không có cơ
chế khoá; giải pháp hiện tại thuần quy trình: BẮT BUỘC đọc lại `PROJECT_STATUS.md` mới nhất trên
GitHub (không tin bộ nhớ hội thoại) trước khi sửa 1 workflow đã có lịch sử phức tạp, đặc biệt nếu
`nodeCount` khác con số mình nhớ.

**9.7. `gateway.notify_targets` (mới, 09/09/2026) là bước đầu của hướng "config thay vì hardcode"** —
nên tiếp tục áp dụng cho các giá trị khác hiện đang hardcode trong code node (`ADMIN_CHAT_ID`,
`AVAILABLE_BOTS`, `COMMAND_MAP`...) nếu refactor lớn — chuyển dần sang bảng `gateway.config`
(đã tồn tại nhưng đang dùng rất ít) để sửa cấu hình không cần deploy lại workflow.

**9.8. `/cancel` hiện chỉ THẬT SỰ cần thiết ở 2 nơi**: `Telebot ClickUp Reader` (bot chính, xoá
`clickup.pending_uploads`) và `Telebot Admin System` (bot riêng, hiện chưa có state thật để huỷ —
chỉ trả lời "không có gì để huỷ", giữ cho nhất quán UX). Các sub-workflow còn lại (`Bot Xử Lý Ảnh`,
`help_bot`/`crawl_bot` tương lai) dùng CHUNG vật lý bot Telegram với ClickUp Reader qua Gateway
(`Elite_clickup_bot`) nên KHÔNG cần `/cancel` riêng — Gateway đã route `/cancel` thẳng về
`telebot_main` bất kể user đang "ở" sub-bot nào, và vì cùng 1 bot Telegram nên user không nhận thấy
khác biệt. Nếu sau này 1 sub-workflow khác có state đa lượt riêng, áp dụng lại đúng pattern 9.5.
