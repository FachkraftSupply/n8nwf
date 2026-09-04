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

## PHẦN A' — LÀM Ở PHẦN A BẰNG pgAdmin (thay vì gõ lệnh Terminal)

> Bỏ qua phần này nếu anh đã làm xong A1–A4 bằng Terminal. Đây là cách làm tương đương
> nhưng dùng giao diện đồ họa — hợp với người không quen dòng lệnh. Chọn **1 trong 2
> cách** bên dưới tùy Postgres của anh có "mở cổng ra ngoài" hay không.

### A'.0 Xác định cổng Postgres có được mở ra ngoài container không

Trên Mac Mini, mở file `docker-compose.yml` của stack n8n, tìm service Postgres, xem có
đoạn `ports:` không:

```yaml
services:
  postgres:
    image: postgres:16
    ports:
      - "5432:5432"      # <-- CÓ dòng này = cổng đã mở ra ngoài, dùng CÁCH 1
    environment:
      POSTGRES_USER: n8n
      ...
```

- **Có dòng `ports:`** → dùng **Cách 1** (kết nối thẳng, đơn giản nhất).
- **Không có** (chỉ có `expose:` hoặc không có gì) → Postgres chỉ tự nói chuyện được
  với các container khác trong cùng mạng Docker (n8n), không nghe từ bên ngoài — an
  toàn hơn nhưng cần **Cách 2** (chạy pgAdmin dạng container trong cùng mạng).

> Khuyến nghị bảo mật: KHÔNG mở cổng 5432 ra Internet công khai (chỉ mở trong mạng nội
> bộ / localhost là đủ để dùng pgAdmin Desktop qua Cách 1).

---

### CÁCH 1 — pgAdmin Desktop (khi cổng 5432 đã mở, dùng khi pgAdmin chạy trên máy tính của anh)

**Bước 1 — Cài đặt**
1. Vào https://www.pgadmin.org/download/ → chọn đúng hệ điều hành máy anh đang dùng
   (macOS / Windows) → tải và cài như phần mềm bình thường.
2. Mở pgAdmin lần đầu, nó sẽ hỏi đặt **Master Password** (mật khẩu mở app, khác mật
   khẩu database) — đặt và ghi nhớ.

**Bước 2 — Đăng ký kết nối tới Postgres Docker**
1. Trong pgAdmin, cây bên trái → chuột phải vào **Servers** → **Register** → **Server...**
2. Tab **General**: ô **Name** đặt tùy ý, ví dụ `Elite Gateway - Docker Postgres`.
3. Tab **Connection**:
   - **Host name/address**: nếu pgAdmin chạy TRÊN CHÍNH Mac Mini → gõ `localhost`.
     Nếu pgAdmin chạy trên máy khác trong cùng mạng LAN → gõ IP của Mac Mini
     (vd `192.168.1.50`, xem bằng `ifconfig` trên Mac Mini).
   - **Port**: `5432` (hoặc số cổng bên trái dấu `:` trong `ports: "5432:5432"` nếu khác).
   - **Maintenance database**: tên DB, ví dụ `n8n` (lấy từ `POSTGRES_DB` trong compose).
   - **Username**: `n8n` (lấy từ `POSTGRES_USER`).
   - **Password**: giá trị `POSTGRES_PASSWORD` trong file compose → tick **Save password**.
4. Bấm **Save**. Nếu hiện lỗi `connection refused` → cổng chưa mở đúng, quay lại A'.0
   hoặc dùng Cách 2.

**Bước 3 — Chạy file schema**
1. Cây bên trái: bung `Elite Gateway - Docker Postgres` → `Databases` → chọn đúng DB
   (vd `n8n`).
2. Menu trên cùng → **Tools** → **Query Tool** (hoặc icon hình tia sét ⚡).
3. Mở file `01_gateway_schema.sql` bằng trình soạn thảo bất kỳ → Select All (Cmd/Ctrl+A)
   → Copy → dán vào ô Query Tool vừa mở.
4. Bấm nút **▶ Execute/Refresh** (hoặc phím **F5**).
5. Panel **Messages** phía dưới hiện các dòng `CREATE SCHEMA`, `CREATE TABLE`... và cuối
   cùng `Query returned successfully` → đúng. Có dòng đỏ `ERROR` → chụp màn hình gửi lại.

**Bước 4 — Kiểm tra**
1. Cây bên trái: bung `Databases` → DB của anh → `Schemas` → phải thấy schema mới
   tên **`gateway`** → bung tiếp `Tables` → thấy 4 bảng: `bot_users`, `bot_permissions`,
   `interaction_logs`, `config`.
2. Chuột phải bảng `bot_users` → **View/Edit Data** → **All Rows** → phải thấy 1 dòng
   `user_id = 7030500584, role = admin, status = active`.

---

### CÁCH 2 — pgAdmin chạy dạng container trong cùng mạng Docker (khi KHÔNG mở cổng 5432)

An toàn hơn vì không cần mở cổng Postgres ra ngoài. Thêm pgAdmin làm 1 service nữa
ngay trong file `docker-compose.yml` hiện có của n8n.

**Bước 1 — Thêm service vào docker-compose.yml**

Mở file `docker-compose.yml`, thêm đoạn sau vào cùng cấp với service `postgres` hiện có
(giữ nguyên indent 2 dấu cách, đặt trong cùng `services:`):

```yaml
  pgadmin:
    image: dpage/pgadmin4:latest
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@local.dev
      PGADMIN_DEFAULT_PASSWORD: doi-mat-khau-nay
    ports:
      - "127.0.0.1:5050:80"   # chỉ nghe từ chính Mac Mini, không lộ ra ngoài
    networks:
      - default                # phải TRÙNG tên network mà service postgres đang dùng
```

> Nếu file compose của anh đặt tên network riêng cho Postgres/n8n (xem trong khối
> `networks:` ở cuối file), sửa `default` thành đúng tên đó để pgAdmin nằm chung mạng.

**Bước 2 — Khởi động**

```bash
cd <thư mục chứa docker-compose.yml>
docker compose up -d pgadmin
```

**Bước 3 — Mở pgAdmin qua trình duyệt**

Trên chính Mac Mini, mở trình duyệt vào `http://localhost:5050` → đăng nhập bằng
`PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` vừa đặt.

> Truy cập từ máy khác (không phải Mac Mini)? Vì cổng bị giới hạn `127.0.0.1` (chỉ
> localhost) cho an toàn, hãy SSH tunnel từ máy anh vào Mac Mini:
> `ssh -L 5050:localhost:5050 <user>@<ip-mac-mini>` rồi mở `http://localhost:5050`
> trên trình duyệt máy anh như bình thường.

**Bước 4 — Đăng ký server (giống Cách 1 nhưng Host khác)**

Làm y hệt "Bước 2" của Cách 1, chỉ khác duy nhất 1 ô:
- **Host name/address**: gõ đúng **tên service** Postgres trong docker-compose, ví dụ
  `postgres` (không phải `localhost` — vì pgAdmin giờ ở trong mạng Docker, nó gọi
  Postgres bằng tên service).
- Port vẫn là cổng NỘI BỘ container, thường là `5432` (không phải cổng map ra ngoài).

Sau đó **Bước 3 và Bước 4 giống hệt Cách 1** (mở Query Tool, dán SQL, Execute, kiểm tra).

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
