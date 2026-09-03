# ⚙️ n8n Workflows – FS International

Kho lưu trữ các workflow n8n nội bộ của FS International (Elite Education), phục vụ tự động hoá quy trình tuyển sinh, đánh giá và vận hành chương trình Ausbildung Đức.

**n8n instance:** `https://n8n.toididuhoc.net`

---

## 📂 Danh sách Workflow

| Folder | Workflow | Mô tả | Trạng thái |
|---|---|---|---|
| [`interview-evaluation/`](./interview-evaluation/) | Interview Evaluation | Form đánh giá phỏng vấn tiếng Đức → 1 LLM call → Telegram + ClickUp + Supabase (có debug branch) | ✅ Production |
| [`interview-result-lookup/`](./interview-result-lookup/) | Interview Result Lookup | Bot Telegram `/ketqua` tra cứu kết quả phỏng vấn từ Supabase, fuzzy-match tên bằng AI Agent, chọn qua inline keyboard khi có nhiều kết quả trùng | ✅ Production |

---

## 🚀 Quy ước sử dụng repo

### Cấu trúc thư mục

```
n8nwf/
├── README.md                      ← file này
└── <workflow-name>/
    ├── <workflow-name>.json       ← file export từ n8n (import lại được)
    ├── README.md                  ← tài liệu chi tiết: kiến trúc, payload, hướng dẫn deploy
    └── (tuỳ chọn) schema.sql, form.html, assets…
```

### Khi thêm workflow mới

1. Tạo folder mới theo tên workflow (kebab-case, tiếng Anh)
2. Export workflow từ n8n (⋯ → Download) → đặt vào folder
3. Viết README.md trong folder: sơ đồ luồng, node chính, credentials cần thiết, payload mẫu, hướng dẫn test
4. Cập nhật bảng **Danh sách Workflow** ở file này

### Khi cập nhật workflow

1. Export bản mới từ n8n, ghi đè file JSON (hoặc thêm version vào tên file nếu cần giữ bản cũ)
2. Cập nhật README trong folder + ghi chú thay đổi
3. Commit message rõ ràng: `update: <workflow> - <thay đổi chính>`

### ⚠️ Bảo mật

- File export từ n8n **chỉ chứa ID credential, không chứa secret** — an toàn để commit
- **Không commit** API key, token, service key Supabase, hoặc file `.env` vào repo
- Repo này là **private** — không chuyển public khi chưa rà soát lại toàn bộ nội dung

---

*FS International – Fachkraft Supply · Nội bộ*
