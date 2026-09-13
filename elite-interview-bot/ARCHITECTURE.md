# ARCHITECTURE — Bot Luyện Phỏng Vấn & Tự Động Tạo Hồ Sơ Ausbildung

## 1. Tổng quan hệ thống

```
Học sinh (Telegram)
      │  gửi mã ClickUp
      ▼
[Telegram Trigger] ──▶ [Verify Sub-workflow]
                            │
                 ┌──────────┴───────────┐
                 │ ClickUp task tồn tại? │
                 └──────────┬───────────┘
                     có │        │ không → báo lỗi, dừng
                        ▼
             ┌─────────────────────┐
             │ Comment có link OneDrive? │
             └──────────┬───────────┘
                 chưa │      │ có
                       │      ▼
          báo "chưa sẵn sàng"   [Menu 2 chức năng]
                                 │
                    ┌────────────┬─────────────┐
                    ▼                           ▼
          [Upload Hồ Sơ Flow]          [Interview Flow]
                                        (chỉ nếu tên task khớp el*)
```

Ghi chú: repo đã có sẵn `interview-evaluation/` và `interview-result-lookup/` — cần rà soát xem có tái sử dụng/trùng lặp logic được với luồng Interview ở đây không, trước khi build mới từ đầu.

Toàn bộ state (đang ở câu hỏi nào, đã trả lời gì, session nào) lưu trong Postgres, KHÔNG lưu trong bộ nhớ workflow (n8n execution không có state giữa các lần trigger).

## 2. Câu hỏi mở cần chốt trước khi build
Xem mục "Blocker" trong `STATUS.md`. Đặc biệt: bot này route qua Gateway hiện có hay độc lập — quyết định ảnh hưởng toàn bộ cách wiring.

## 3. Data model (Postgres — schema riêng, vd `interview_app`)

### `application_session`
| cột | kiểu | ghi chú |
|---|---|---|
| session_id | uuid PK | |
| chat_id | bigint | Telegram chat |
| clickup_task_id | text | mã đã verify |
| onedrive_folder_link | text | cache từ comment ClickUp |
| flow_type | text | `upload` \| `interview` |
| current_step | text | bước hiện tại trong flow (vd `cv_frage_3`, `iv_q_12`) |
| status | text | `active` \| `paused` \| `cancelled` \| `completed` |
| answers_json | jsonb | toàn bộ câu trả lời tích lũy, để hỗ trợ nút Quay lại |
| created_at / updated_at | timestamptz | |

### `interview_bank`
| cột | kiểu | ghi chú |
|---|---|---|
| question_id | serial PK | |
| order_index | int | thứ tự hỏi |
| question_vi | text | câu hỏi hiển thị cho user (tiếng Việt) |
| question_de_hint | text | gợi ý ngữ cảnh tiếng Đức cho AI khi soạn câu trả lời mẫu |
| active | boolean | Mr có thể tắt/bật câu hỏi mà không xóa |

→ Bảng này Mr sửa trực tiếp qua SQL hoặc qua 1 mini form (Notion/ClickUp) nối vào — không hardcode trong workflow.

### `session_upload_files` (theo dõi để xóa khi Hủy)
| cột | kiểu | ghi chú |
|---|---|---|
| id | serial PK | |
| session_id | uuid FK | |
| onedrive_file_id | text | để gọi API xóa khi Hủy |
| doc_type | text | `anschreiben` \| `cv` \| `passport` \| `photo` \| `b1` \| `diploma` \| `other` |

## 4. Luồng Upload Hồ Sơ (chi tiết)

1. **Thư xin việc (Anschreiben)** — chuỗi câu hỏi qua Telegram → map vào input schema Zod đã có (`ausbildung-doc-generation`) → generate .docx → convert PDF (Gotenberg) → upload OneDrive → ghi `session_upload_files`.
2. **CV (Lebenslauf)** — tương tự, dùng chung hệ thống tạo hồ sơ hiện có.
3. Sau khi 2 văn bản trên xong, chuyển tuần tự: scan hộ chiếu → ảnh xin việc → scan B1 → scan bằng tốt nghiệp cấp 3 → giấy tờ khác (optional, không block flow nếu user skip).
4. Mỗi bước nhận file qua Telegram (photo/document) → validate định dạng cơ bản (kiểm tra là ảnh/PDF hợp lệ) → upload thẳng OneDrive vào đúng subfolder theo `doc_type`.
5. **Chế độ Upload nhanh**: user chọn chế độ này ngay từ menu → bỏ qua toàn bộ câu hỏi → nhận N file liên tiếp → đưa thẳng vào folder gốc của candidate trên OneDrive, không phân loại tự động (hoặc phân loại bằng tên file nếu có pattern).

## 5. Luồng Interview (chi tiết)

1. Kiểm tra tên ClickUp task khớp regex `/el/i` (hoặc danh sách cụ thể ELMC/ELHZ/ELHT nếu Mr muốn giới hạn chặt hơn — cấu hình được qua Config node).
2. Load `interview_bank` (WHERE active = true ORDER BY order_index) — khoảng 20 câu.
3. Với mỗi câu:
   - Bot gửi câu hỏi (tiếng Việt).
   - User trả lời tiếng Việt.
   - AI Agent (gợi ý dùng Claude API cho chất lượng tư vấn + tiếng Đức) nhận câu trả lời → trả về 2 phần: (a) nhận xét/tư vấn hướng trả lời phù hợp hơn nếu cần (tiếng Việt), (b) câu trả lời mẫu hoàn chỉnh bằng tiếng Đức.
   - Lưu cả 2 vào `answers_json` của session.
   - Next question / hoặc Quay lại / Tạm dừng / Hủy.
4. Sau câu 20: build 1 document text (Q&A tiếng Việt + bản mẫu tiếng Đức) → POST lên PrivateBin API (self-host) với mật khẩu (random tạo tự động hoặc theo mã ClickUp) → nhận về URL.
5. Ghi URL + mật khẩu vào comment của bảng kết quả phỏng vấn Supabase hiện có (không tạo bảng mới) — để tra cứu lại cho lần luyện sau.
6. Đánh dấu `application_session.status = completed`.

## 6. Công cụ publish — PrivateBin

- Lý do chọn: open-source, hỗ trợ password protection + expiration + burn-after-read, có REST API để n8n gọi trực tiếp (HTTP Request node), tự host được trên VPS hiện có (Docker + Caddy đã sẵn).
- Triển khai: 1 Docker container PrivateBin + subdomain riêng qua Caddy (vd `notes.fachkraft.supply`), theo đúng pattern `n8n-self-hosting` skill đã dùng cho n8n.
- Không dùng instance công cộng `privatebin.net` cho dữ liệu học sinh thật (chỉ dùng để test nhanh ban đầu nếu cần).

## 7. Xử lý nút Quay lại / Tạm dừng / Hủy (kỹ thuật)
- **Quay lại**: giảm `current_step` về bước trước, giữ nguyên `answers_json`, hiển thị lại câu trả lời cũ để sửa (pre-filled nếu Telegram cho phép, hoặc hỏi lại).
- **Tạm dừng**: chỉ set `status = paused`, không xóa gì. Khi user quay lại bot (bất kỳ lúc nào), bot check có session `paused` theo `chat_id` → hỏi "Tiếp tục từ chỗ cũ?" trước khi mở menu mới.
- **Hủy bỏ**: 
  1. Query `session_upload_files` theo `session_id`.
  2. Gọi OneDrive API xóa từng `onedrive_file_id`.
  3. `DELETE FROM application_session WHERE session_id = ...` (và cascade `session_upload_files`).
  4. Báo user đã xóa xong, quay về menu mã ClickUp.

## 8. Tích hợp với Gateway hiện có
- Nếu quyết định route qua Gateway: thêm entry vào `COMMAND_MAP`, đảm bảo `chatId` lấy qua `$('GW-01 Envelope').first().json.chat_id` theo đúng rule hiện có.
- Nếu độc lập: cần Telegram Trigger + auth check riêng (kiểm tra user có phải học sinh hợp lệ qua bảng `gateway.bot_users` hiện có, tránh trùng lặp hệ thống auth).
- Cần Mr xác nhận hướng nào trước khi builder bắt đầu.
