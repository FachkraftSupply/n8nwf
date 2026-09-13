# INDEX — Mục lục tái sử dụng cho AI Agent

> File này dành cho AI agent chuẩn bị build/triển khai một dự án MỚI trong repo `n8nwf`.
> Mục đích: liệt kê resource, pattern, quy ước đã có sẵn để agent tái sử dụng thay vì xây lại từ
> đầu, và tránh tạo trùng bảng DB / workflow / bot đã tồn tại.
>
> Đọc theo thứ tự: **1. File này (INDEX.md) → 2. README.md của folder liên quan → 3.
> STATUS/PROJECT_STATUS.md của folder đó (nếu có) → 4. RULES.md của folder đó (nếu có)**.

## 1. Hạ tầng chung

| Thành phần | Giá trị | Ghi chú |
|---|---|---|
| n8n instance | `https://n8n.toididuhoc.net` | Self-hosted, Docker Hardened Image |
| GitHub repo | `FachkraftSupply/n8nwf` | repo này |
| Postgres (n8n) | container `n8n_stack-postgres-1`, db `n8n` | dùng cho Gateway (`gateway` schema, `clickup` schema) |
| Supabase project | "Test tiếng" — id `oreodamslizkrmdpvgye` | dùng cho `interview-evaluation` + `interview-result-lookup`; dashboard: `https://supabase.com/dashboard/project/oreodamslizkrmdpvgye` |
| AI models đang dùng | OpenRouter (Gemini, DeepSeek), Claude API, OpenAI GPT-4 | chọn theo nhu cầu chất lượng vs chi phí |
| OCR | OCR.space (lang=ger, Engine=2), Mistral OCR | |
| Document generation | docxtemplater (Word), Gotenberg (PDF) | dùng trong hệ thống tạo hồ sơ Ausbildung |
| Lưu trữ file | OneDrive (ưu tiên hơn Google Drive) | |

## 2. Bảng dữ liệu đã có sẵn (đừng tạo trùng)

| Bảng | Ở đâu | Field chính | Dùng cho |
|---|---|---|---|
| `gateway.bot_users` | Postgres n8n | user auth/permission | Gateway — kiểm tra user hợp lệ |
| `gateway.bot_permissions`, `gateway.interaction_logs`, `gateway.config` | Postgres n8n | | Gateway |
| `clickup.tasks`, `clickup.task_links`, `clickup.sync_targets` | Postgres n8n | | Sync ClickUp ↔ Postgres |
| `interview_evaluations` | Supabase "Test tiếng" | student_name, company, profession, scores, `notes`, situations (JSON) | Lưu kết quả đánh giá phỏng vấn (evaluator chấm) — dự án `interview-evaluation` ghi vào, `interview-result-lookup` đọc ra qua `/ketqua` |
| `score_thresholds` | Supabase "Test tiếng" | scope (company/profession/default), scope_value, threshold | Ngưỡng điểm "Đạt/Chưa đạt", sửa qua Table Editor không cần SQL |

> ⚠️ Bảng `interview_evaluations` là kết quả **evaluator con người chấm** — KHÁC với bảng dự kiến
> `application_session`/`interview_bank` của dự án `elite-interview-bot` (học sinh tự luyện với AI).
> Nếu muốn lưu link PrivateBin của buổi tự luyện vào `interview_evaluations.notes`, cần xác nhận có
> đúng học sinh/candidate tương ứng đã có dòng evaluation chưa — KHÔNG mặc định trùng khớp 1-1.

## 3. Telegram bots (tóm tắt, xem chi tiết ở `bot-gateway/docs/BOT_INVENTORY.md`)

| Bot | Vai trò |
|---|---|
| `@Elite_clickup_bot` | Gateway PROD |
| `@elite_n8n_test_bot` | Gateway DEV |
| `@elite_n8n_system_bot` | Error Handler |
| `@Elite_system_bot` | Crawl/backup output |
| `@elite_tele_help_bot` | Đang retire vào Gateway |
| Bot dùng credential `telegramApi` = "CSFSINT" | dùng cho `interview-result-lookup` |

## 4. Pattern kỹ thuật tái sử dụng được

| Pattern | Ở đâu | Mô tả |
|---|---|---|
| Gateway COMMAND_MAP routing | `bot-gateway/workflows/new_architecture/GW_Gateway_Telegram.json` | Cách route lệnh bot qua 1 gateway trung tâm, `chatId` lấy qua `$('GW-01 Envelope').first().json.chat_id` |
| AI Agent fuzzy-match tên | `interview-result-lookup/interview-result-lookup.json` | Fuzzy match tên học sinh (sai dấu, viết tắt), phân loại theo số lượng kết quả khớp (0/1/2-5/>5), build inline keyboard khi nhiều kết quả |
| 1-LLM-call gộp nhiều output | `interview-evaluation/interview-evaluation-workflow-v4-final.json` | 1 lần gọi LLM trả JSON chứa nhiều định dạng output (`telegram_html` + `clickup_markdown`) thay vì gọi nhiều lần tuần tự — tiết kiệm chi phí + latency |
| Parse LLM output không throw lỗi | `interview-evaluation` — node `Parse LLM Output` | Trả `_parse_ok: true/false` thay vì throw, tách nhánh Debug riêng khi parse hỏng, không ảnh hưởng nhánh chính đã lưu xong |
| CTE pass-through | `bot-gateway` — `SQL_ClickUp_Full_Reconcile.json` | Fix cross-node item reference collapse khi batch xử lý ClickUp↔Postgres |
| Ngưỡng điểm cấu hình động qua DB | `interview-result-lookup` — bảng `score_thresholds` | Thay vì hardcode ngưỡng trong workflow, đọc từ bảng, sửa qua Supabase Table Editor |
| Ausbildung doc generation (Zod + docx) | ngoài repo này (dự án riêng `ausbildung-doc-generation`) | Input schema Zod validate → generate .docx Anschreiben/Lebenslauf |
| `bewerbung-audit` skill | ngoài repo — skill Claude riêng | Audit hồ sơ Bewerbungsunterlagen, chấm điểm traffic-light |

## 5. Quy tắc chung áp dụng cho MọI workflow trong repo

- ClickUp `getAll` luôn cần `"filters": {}` kể cả rỗng, nếu không workflow không Publish được.
- `team`/`space` field trong ClickUp node phải là expression, không phải string thường.
- Không dùng inline keyboard mặc định trừ khi có lý do rõ ràng (xem ngoại lệ trong `elite-interview-bot/RULES.md`).
- `chatId`/giá trị từ node trước luôn lấy qua reference tường minh `$('NodeName').first().json.field`, không dùng `$json.field` trần sau node DB (Postgres/Supabase ghi đè `$json`).
- Community Edition không có Pro Variables → dùng Code node `⚙️ Config` trả JSON object làm nguồn cấu hình tập trung.

## 6. Bản đồ folder → entry point đọc

| Folder | Đọc theo thứ tự |
|---|---|
| `bot-gateway/` | `README.md` → `docs/PROJECT_STATUS.md` → `docs/RULES.md` |
| `interview-evaluation/` | `README.md` (đầy đủ trong 1 file) |
| `interview-result-lookup/` | `README.md` → `PROJECT_STATUS.md` |
| `elite-interview-bot/` | `STATUS.md` → `RULES.md` → `ARCHITECTURE.md` → `ROADMAP.md` |

## 7. Trước khi build dự án mới — checklist cho agent

1. Đọc bảng mục 2 — có bảng DB nào tái sử dụng được không, tránh tạo trùng.
2. Đọc bảng mục 4 — có pattern kỹ thuật nào áp dụng được không, tránh code lại từ đầu.
3. Đọc mục 5 — áp dụng quy tắc chung, tránh lỗi đã biết.
4. Sau khi build xong, cập nhật `README.md` (bảng Danh sách Workflow) VÀ file này (`INDEX.md`) nếu có resource/pattern mới đáng ghi nhận.
