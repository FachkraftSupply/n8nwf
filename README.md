# ⚙️ n8n Workflows – FS International

Kho lưu trữ các workflow n8n nội bộ của FS International (Elite Education), phục vụ tự động hoá quy trình tuyển sinh, đánh giá và vận hành chương trình Ausbildung Đức.

**n8n instance:** `https://n8n.toididuhoc.net`

> 🤖 **AI agent chuẩn bị triển khai dự án mới trong repo này**: đọc [`INDEX.md`](./INDEX.md) trước — file đó liệt kê toàn bộ resource (bảng DB, workflow, credential, pattern kỹ thuật) đã có sẵn để tái sử dụng, tránh xây lại từ đầu hoặc tạo bảng/workflow trùng lặp.
>
> 📌 **Muốn biết nhanh dự án nào đang cần làm gì?** đọc [`STATUS.md`](./STATUS.md) — tổng hợp trạng thái + việc cần làm của tất cả dự án con.

---

## 📂 Danh sách Workflow

| Folder | Workflow | Mô tả | Trạng thái |
|---|---|---|---|
| [`bot-gateway/`](./bot-gateway/) | Bot Gateway System | Gateway tập trung cho bot Telegram đa chức năng, đồng bộ ClickUp ↔ Postgres, backup hệ thống | ✅ Production (đang go-live) |
| [`interview-evaluation/`](./interview-evaluation/) | Interview Evaluation | Form đánh giá phỏng vấn tiếng Đức → 1 LLM call → Telegram + ClickUp + Supabase (có debug branch) | ✅ Production — 🔄 đang thiết kế lại cách chấm điểm |
| [`interview-result-lookup/`](./interview-result-lookup/) | Interview Result Lookup | Bot Telegram `/ketqua` tra cứu kết quả phỏng vấn từ Supabase, fuzzy-match tên bằng AI Agent, chọn qua inline keyboard khi có nhiều kết quả trùng | ✅ Production |
| [`elite-interview-bot/`](./elite-interview-bot/) | Elite Interview Bot | Bot Telegram luyện phỏng vấn tiếng Đức cho học sinh (tự luyện với AI) + tự động tạo hồ sơ Ausbildung (Anschreiben/CV/scan giấy tờ) qua ClickUp/OneDrive | 📝 Thiết kế (chưa build) |

---

## 🚀 Quy ước sử dụng repo

### Cấu trúc thư mục

```
n8nwf/
├── README.md                      ← file này — tổng quan repo
├── INDEX.md                       ← mục lục cho AI agent: resource/pattern tái sử dụng được
├── STATUS.md                      ← tổng hợp trạng thái + việc cần làm của tất cả dự án con
└── <workflow-name>/
    ├── <workflow-name>.json       ← file export từ n8n (import lại được)
    ├── README.md                  ← tài liệu chi tiết: kiến trúc, payload, hướng dẫn deploy
    ├── (một số dự án) PROJECT_STATUS.md / STATUS.md / RULES.md / ARCHITECTURE.md / ROADMAP.md / CHANGELOG.md
    │                              ← xem README của từng folder để biết thứ tự đọc đúng
    └── (tuỳ chọn) schema.sql, form.html, assets…
```

### Khi thêm workflow mới

1. Tạo folder mới theo tên workflow (kebab-case, tiếng Anh)
2. Export workflow từ n8n (⋯ → Download) → đặt vào folder
3. Viết README.md trong folder: sơ đồ luồng, node chính, credentials cần thiết, payload mẫu, hướng dẫn test
4. Cập nhật bảng **Danh sách Workflow** ở file này VÀ mục tương ứng trong `INDEX.md`

### Khi cập nhật workflow

1. Export bản mới từ n8n, ghi đè file JSON (hoặc thêm version vào tên file nếu cần giữ bản cũ)
2. Cập nhật README trong folder + ghi chú thay đổi
3. Commit message rõ ràng: `update: <workflow> - <thay đổi chính>`
4. Nếu resource dùng chung thay đổi (tên bảng, credential, endpoint) → cập nhật `INDEX.md`
5. Nếu trạng thái/việc cần làm thay đổi đáng kể → cập nhật `STATUS.md`

### ⚠️ Bảo mật

- File export từ n8n **chỉ chứa ID credential, không chứa secret** — an toàn để commit
- **Không commit** API key, token, service key Supabase, hoặc file `.env` vào repo
- Repo này là **private** — không chuyển public khi chưa rà soát lại toàn bộ nội dung

---

*FS International – Fachkraft Supply · Nội bộ*
