# RULES.md — Quy tắc BẮT BUỘC khi sửa/build workflow n8n (dự án Bot Gateway)

> File này gộp lại TOÀN BỘ quy tắc đã rút ra qua nhiều phiên làm việc. ĐỌC FILE NÀY TRƯỚC khi sửa
> bất kỳ workflow nào. Vi phạm các quy tắc này đã gây lỗi lặp lại nhiều lần trong dự án.

## 1. ⚠️ Gateway COMMAND_MAP (có điều kiện)
Mỗi khi thêm/sửa 1 lệnh mới trong sub-workflow: kiểm tra sub-workflow đó có **Trigger riêng** hay không.
- Nếu gọi qua Gateway (Execute Workflow Trigger, ví dụ `Telebot_ClickUp_Reader.json`): BẮT BUỘC cập nhật
  `COMMAND_MAP` trong node `⚙️ Config` của `GW_Gateway_Telegram.json`.
- Nếu có Trigger riêng (ví dụ `Telebot_Admin_System.json` — Telegram Trigger trực tiếp trên System Bot):
  KHÔNG cần đụng Gateway.

## 2. ⚠️ KHÔNG BAO GIỜ dùng `$json` trần cho dữ liệu quan trọng
`$json` trong 1 node CHỈ lấy từ output của node NỐI TRỰC TIẾP — không đảm bảo field cần (chatId,
message_id...) có mặt. LUÔN tham chiếu tường minh qua tên node:
```
{{ $('Phân tích lệnh').first().json.chatId }}
{{ $('GW-01 Envelope').first().json.chat_id }}
```
Áp dụng cho CẢ `chatId` LẪN `reply_to_message_id` (để bot trả lời đúng group/topic khi được thêm vào
group — không dùng field `chatId` trần bao giờ).

## 3. ⚠️ KHÔNG dùng inline keyboard — mặc định LUÔN dùng deep-link dạng text
Deep-link: `https://t.me/<bot>?start=<param>` (giống `chitiet_<id>` đã chạy ổn định từ đầu dự án).
- Deep-link Telegram CHỈ cho phép ký tự `[A-Za-z0-9_-]` — dùng `_` làm dấu phân cách, KHÔNG dùng `:`.
- Inline keyboard đã gây lỗi lặp lại NHIỀU LẦN qua nhiều nguyên nhân khác nhau (Gateway route callback
  sai luồng; n8n không lưu được field `inlineKeyboard` khi `replyMarkup` là expression động...). Dù
  từng nguyên nhân đã fix được, tổng thể vẫn KHÔNG đáng tin bằng deep-link.
- CHỈ dùng inline keyboard khi user yêu cầu RÕ RÀNG — hỏi lại lý do + cảnh báo lịch sử không ổn định.

## 4. ⚠️ Node ClickUp native — 2 lưu ý bắt buộc
- Dùng THAM SỐ PHẲNG (`team: "9018351620"`), KHÔNG dùng resource-locator `{__rl:true,...}`.
- Operation `getAll` BẮT BUỘC có field `"filters": {}` trong parameters (dù để rỗng) — thiếu sẽ chặn
  Publish workflow với lỗi khó hiểu.
- Field `team`/`space`: nếu bị kẹt "Error fetching options from ClickUp" trên UI — đổi giá trị đó
  thành EXPRESSION (`={{ '9018351620' }}` hoặc tham chiếu từ node Config) thay vì giá trị chữ thường
  trần — n8n sẽ không cố tải dropdown gợi ý cho field dạng expression.

## 5. ⚠️ `.item` vs `.first()`
Không dùng `$('TenNode').item` nếu chuỗi xử lý phía trước có node Postgres/ClickUp làm mất pairedItem
— lỗi "Multiple matching items". Dùng `.first()` khi chỉ có đúng 1 item cần lấy.

## 6. Code node & node bị "im lặng" không chạy
- Code node mặc định "Run Once for All Items" — nếu code viết theo kiểu từng item (`$json`,
  `return {json:{...}}`), phải set `"mode": "runOnceForEachItem"`.
- n8n bỏ qua (skip) hoàn toàn 1 node nếu nhận 0 item đầu vào, kéo theo mọi node phía sau. Set
  `"alwaysOutputData": true` cho node nào cần LUÔN chạy dù có thể ra 0 kết quả.

## 7. Postgres
- `queryReplacement` LUÔN dùng mảng `={{ [$json.x] }}`, kể cả chỉ 1 tham số `$1`.
- Sau khi qua 1 node Postgres, `$json` bị GHI ĐÈ hoàn toàn bằng kết quả SQL — tham chiếu dữ liệu từ
  trước đó qua tên node, không dùng `$json`.

## 8. Quy trình sửa file
- Sửa JSON lớn: Composio remote workbench (fetch GitHub → sửa Python → commit), không dán nguyên
  workflow vào chat.
- Validate TRƯỚC khi commit: check connections orphan, dup id, surrogate pairs lỗi encoding.
- Đang debug/thử nghiệm 1 thay đổi: KHÔNG tự động commit — đưa nội dung node cho user tự copy/paste
  test trong n8n. Chỉ commit sau khi user xác nhận chạy ổn.
- Rủi ro cao: commit file `_v2`/`_wip` riêng, merge vào file chính sau khi xác nhận.
- Rút gọn/mở rộng hoạt động 1 workflow: LUÔN đối chiếu checklist tính năng trước/sau để không bỏ sót.
- Sau khi 1 thay đổi được xác nhận thành công: cập nhật `CHANGELOG.md` + file này nếu có bài học mới.

## 9. Bot Telegram — 3 loại, không được nhầm
| Bot | Vai trò |
|---|---|
| `@elite_n8n_test_bot` (DEV) | Gateway đang lắng nghe — user thường |
| `@Elite_clickup_bot` (PROD) | Sẽ thay bot DEV ở Giai đoạn 4 cutover |
| `@elite_n8n_system_bot` (System) | Admin control panel (`Telebot_Admin_System.json`, Trigger riêng) + thông báo nền (Full Reconcile/Live Update Notify) |

Mỗi khi thêm node Telegram reply mới: xác nhận đúng credential ứng với bot dự định — không suy luận,
kiểm tra `result.from.username` khi test thực tế.


## 10. ⚠️ Test với vài item KHÔNG đảm bảo đúng khi xử lý HÀNG LOẠT (batch)
Tham chiếu `$('TenNode').first()` hoặc `.item` giữa các node CÁCH NHAU 2 BƯỚC trở lên (đặc biệt khi có
Postgres DELETE/UPDATE không RETURNING ở giữa) có thể chạy "đúng" khi test với vài item, nhưng SAI hoàn
toàn khi xử lý hàng loạt (vd 612 task) — `.first()` luôn lấy item ĐẦU TIÊN bất kể đang xử lý item nào;
`.item` có thể mất pairedItem qua nhiều bước, gây "Multiple matching items" hoặc âm thầm cắt còn 1 item.
**Cách sửa triệt để:** GỘP các bước Postgres liên quan (DELETE+INSERT, UPDATE+SELECT...) thành **1 câu
query duy nhất** (dùng CTE: `WITH x AS (DELETE...) INSERT...`) để chỉ cần tham chiếu THẲNG từ node
TRỰC TIẾP đứng trước (1 bước, luôn an toàn) — không tham chiếu chéo qua 2+ bước.
**Luôn test với DATASET THẬT (đủ lớn) trước khi coi 1 luồng Postgres nhiều bước là ổn định** — test
với 5 item không đủ để phát hiện lỗi loại này.
