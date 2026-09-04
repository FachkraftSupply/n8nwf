# HƯỚNG DẪN TRIỂN KHAI DATABASE — CHO NGƯỜI MỚI BẮT ĐẦU

> Mục tiêu: chạy file `01_gateway_schema.sql` lên **2 nơi**: Postgres trong Docker
> (trên Mac Mini) và Supabase (cloud). Làm xong phần này mới import workflow.
> Thời gian: ~20 phút. Không cần biết SQL.

---

## PHẦN A — POSTGRES TRONG DOCKER (trên Mac Mini)

### A1. Tìm tên container Postgres

Mở Terminal trên Mac Mini (hoặc SSH vào), gõ:

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

Nhìn cột IMAGE, dòng nào có chữ `postgres` thì cột NAMES chính là tên container.
Ví dụ kết quả: `n8n-postgres-1` — từ giờ gọi nó là `<TÊN_CONTAINER>`.

### A2. Tìm user và tên database

Thông tin này nằm trong file `docker-compose.yml` của stack n8n (thường cùng thư mục
anh chạy `docker compose up`). Mở file, tìm 3 dòng:

```yaml
POSTGRES_USER: n8n        # <USER>
POSTGRES_PASSWORD: ...
POSTGRES_DB: n8n          # <DB>
```

Không tìm thấy file? Lấy trực tiếp từ container:

```bash
docker exec <TÊN_CONTAINER> env | grep POSTGRES
```

### A3. Chạy file SQL

Đứng ở thư mục chứa file `01_gateway_schema.sql` (ví dụ vừa tải về Downloads):

```bash
cd ~/Downloads
docker exec -i <TÊN_CONTAINER> psql -U <USER> -d <DB> < 01_gateway_schema.sql
```

Ví dụ cụ thể:

```bash
docker exec -i n8n-postgres-1 psql -U n8n -d n8n < 01_gateway_schema.sql
```

**Kết quả đúng** sẽ in ra nhiều dòng dạng:

```
CREATE SCHEMA
CREATE TABLE
CREATE TABLE
CREATE INDEX
INSERT 0 1
...
```

Thấy `ERROR` màu đỏ → chụp màn hình gửi lại, đừng làm tiếp.
Chạy lại lần 2 mà thấy `INSERT 0 0` hay `NOTICE: relation already exists` là **bình thường**
(file được thiết kế chạy lại không hỏng dữ liệu).

### A4. Kiểm tra đã vào chưa

```bash
docker exec -it <TÊN_CONTAINER> psql -U <USER> -d <DB> -c "SELECT user_id, role, status FROM gateway.bot_users;"
```

Phải thấy 1 dòng: `7030500584 | admin | active`. Xong Phần A. ✅

---

## PHẦN B — SUPABASE (cloud)

### B1. Tạo project (bỏ qua nếu đã có)

1. Vào https://supabase.com → Sign in (đăng nhập bằng GitHub cho nhanh).
2. Bấm **New project** → chọn Organization → đặt tên ví dụ `elite-bot-gateway`.
3. **Database Password**: bấm Generate, rồi **COPY VÀ LƯU LẠI NGAY** (vào trình quản lý
   mật khẩu) — Supabase không cho xem lại password này.
4. Region: chọn **Southeast Asia (Singapore)** cho gần Việt Nam.
5. Bấm Create, chờ ~2 phút cho project khởi tạo xong.

### B2. Chạy file SQL

1. Menu trái → biểu tượng **SQL Editor** (hình tờ giấy có dấu >).
2. Bấm **New query**.
3. Mở file `01_gateway_schema.sql` bằng bất kỳ trình soạn thảo nào → Select All → Copy
   → dán vào ô soạn thảo của Supabase.
4. Bấm nút **Run** (hoặc Cmd+Enter).
5. Kết quả đúng: góc dưới hiện `Success. No rows returned`.

### B3. Kiểm tra

Vẫn trong SQL Editor, xóa nội dung cũ, dán và Run:

```sql
SELECT user_id, role, status FROM gateway.bot_users;
```

Thấy dòng admin `7030500584` là xong. Có thể xem bảng trực quan tại
**Table Editor** → đổi schema từ `public` sang `gateway` ở dropdown phía trên.

### B4. Lấy connection string cho n8n (QUAN TRỌNG)

n8n sẽ kết nối Supabase như một Postgres bình thường:

1. Trong project Supabase → bấm nút **Connect** trên thanh trên cùng.
2. Chọn tab **Connection pooler** (KHÔNG dùng Direct connection — Mac Mini mạng VNPT
   dễ gặp vấn đề IPv6 với direct).
3. Chọn **Transaction mode** (port `6543`).
4. Ghi lại các giá trị hiện ra, dạng:
   - Host: `aws-0-ap-southeast-1.pooler.supabase.com`
   - Port: `6543`
   - Database: `postgres`
   - User: `postgres.abcdefghijk` (có đuôi project ref)
   - Password: password đã lưu ở bước B1.3

### B5. Tạo credential trong n8n

1. n8n → **Credentials** → Add credential → tìm **Postgres**.
2. Đặt tên chính xác: `Supabase Postgres` (các workflow đã trỏ theo tên này).
3. Điền 5 giá trị từ B4. Mục **SSL**: bật, chọn `require`.
4. Bấm **Test** → phải hiện chữ xanh "Connection tested successfully" → Save.

Test đỏ? 90% do: sai password (tạo lại ở Settings → Database → Reset database password),
hoặc chọn nhầm Direct thay vì Pooler, hoặc quên bật SSL.

---

## PHẦN C — CÂU HỎI THƯỜNG GẶP

**Chạy nhầm file 2 lần có sao không?** Không. Mọi lệnh đều có `IF NOT EXISTS` /
`ON CONFLICT`, dữ liệu cũ giữ nguyên.

**Muốn đổi admin?** Sửa số `7030500584` trong file SQL thành Telegram ID của anh
(lấy ID bằng cách nhắn cho bot @userinfobot) rồi chạy lại file.

**Muốn thêm bot mới (vd `zalo_bot`)?** Chạy trên cả 2 DB:
```sql
UPDATE gateway.config SET value = value || ',zalo_bot' WHERE key = 'available_bots';
```
và thêm nút mới trong node "Báo admin duyệt user" của workflow Gateway.

**Xóa sạch làm lại từ đầu?** (cẩn thận — mất hết log)
```sql
DROP SCHEMA gateway CASCADE;
```
rồi chạy lại `01_gateway_schema.sql`.
