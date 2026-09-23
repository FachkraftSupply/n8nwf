# VPS Monitor — lệnh `/vps` cho Telebot Admin System

Endpoint HTTP nội bộ chạy trên chính VPS (ngoài container n8n), trả về JSON: CPU load, RAM,
dung lượng ổ đĩa (tổng/dùng/còn trống), và top container Docker theo dung lượng. n8n gọi endpoint
này qua HTTP Request node, format lại thành tin nhắn Telegram cho lệnh `/vps` (chỉ admin dùng được
— xem `bot-gateway/docs/RULES.md` mục quyền admin).

**Cập nhật 23/09/2026**: thêm 2 endpoint để xem chi tiết + khởi động lại 1 container cụ thể (bấm
deep-link "chi tiết" trong tin nhắn `/vps`, admin-only, xem mục "Routes" bên dưới).

## Routes

- `GET /vps-info` — tổng quan hệ thống + top container theo dung lượng (không đổi, đã có từ đầu).
- `GET /container-info?id=<id>` — chi tiết 1 container (image, trạng thái, uptime, số lần restart,
  ports, CPU%/RAM tức thời qua `docker inspect` + `docker stats --no-stream`).
- `POST /container-restart` (`{"id": "<id>"}`) — `docker restart <id>`, trả `{"success": bool, "name": ..., "error"?: ...}`.

`<id>` là Docker container ID dạng short (12 ký tự hex trở lên, khớp regex `^[a-f0-9]{12,64}$`,
validate ở cả `server.py` lẫn `vps_info.py` trước khi đưa vào `subprocess` — dùng list-form
`subprocess.run([...])`, không `shell=True`, nên an toàn khỏi command injection ngay cả nếu bỏ qua
bước validate, nhưng vẫn validate để chặn id sai định dạng/không tồn tại sớm, trả lỗi rõ ràng).

**Vì sao chạy ngoài container n8n:** n8n tự host bằng Docker Hardened Image — image này không có
sẵn `docker` CLI/shell đầy đủ bên trong để SSH-exec lệnh hệ thống host một cách an toàn. Chạy 1
service Python thuần (stdlib, không cần cài thêm gì) trực tiếp trên host là cách chắc chắn nhất để
đọc đúng thông tin host thật + Docker socket thật.

## Cấu trúc

- `vps_info.py` — script thu thập dữ liệu, in JSON ra stdout. Chạy độc lập được: `python3 vps_info.py`
- `server.py` — HTTP server tối giản (chỉ stdlib), bind `127.0.0.1:8787` mặc định, xác thực bằng
  header `X-Auth-Token`, gọi `vps_info.py` mỗi request.
- `vps-monitor.service` — systemd unit để chạy `server.py` như 1 service luôn bật, tự restart khi lỗi.

## Bước triển khai trên VPS

1. Copy 2 file `vps_info.py` + `server.py` vào `/opt/vps-monitor/` trên VPS:
   ```bash
   sudo mkdir -p /opt/vps-monitor
   sudo cp vps_info.py server.py /opt/vps-monitor/
   ```
2. Tạo token bí mật riêng (KHÔNG dùng lại token nào đã từng xuất hiện trong chat/log):
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
3. Tạo file env (không commit vào git, nằm ngoài repo):
   ```bash
   sudo tee /etc/vps-monitor.env <<'EOF'
   VPS_MONITOR_TOKEN=<dán token vừa tạo>
   VPS_MONITOR_PORT=8787
   VPS_MONITOR_BIND=127.0.0.1
   EOF
   sudo chmod 600 /etc/vps-monitor.env
   ```
4. Cài + bật service:
   ```bash
   sudo cp vps-monitor.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now vps-monitor
   sudo systemctl status vps-monitor
   ```
5. Test ngay trên VPS (từ host, chưa qua Docker):
   ```bash
   curl -H "X-Auth-Token: <token>" http://127.0.0.1:8787/vps-info
   ```

## Việc quan trọng nhất: cho container n8n gọi được vào host

`127.0.0.1` bên trong container n8n trỏ vào chính container đó, KHÔNG phải host — đây là bẫy
Docker networking phổ biến nhất. Chọn 1 trong 2 cách sau tuỳ theo Docker Engine đang dùng (hầu hết
bản hiện đại ≥20.10 hỗ trợ cách 1):

**Cách 1 (khuyến nghị) — `host.docker.internal`:** thêm vào service n8n trong docker-compose:
```yaml
services:
  n8n:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```
Sau đó `docker compose up -d` để áp dụng, và URL gọi từ n8n là:
`http://host.docker.internal:8787/vps-info`

**Cách 2 (fallback) — IP gateway của Docker bridge network:**
```bash
docker network inspect <ten-network-cua-n8n> | grep Gateway
# hoặc mặc định: ip addr show docker0 | grep 'inet '
```
Dùng IP đó thay cho `host.docker.internal` trong URL.

Sau khi xác nhận URL nào gọi được (test bằng cách exec vào container n8n rồi `curl` thử), báo lại
để cập nhật node HTTP Request trong workflow `Telebot Admin System`.

## Bảo mật

- Endpoint chỉ bind `127.0.0.1` (không expose ra internet) — chỉ container trên cùng máy gọi được
  qua cơ chế ở trên, không public port này ra ngoài firewall.
- Token lưu trong n8n dưới dạng **Credential kiểu "Header Auth"** (tên gợi ý: `VPS Monitor Token`,
  header name `X-Auth-Token`), KHÔNG hardcode trong node/workflow JSON — nhất quán với quy ước
  "không commit secret" của repo.
- Không cần mở port ra ngoài, không cần TLS vì traffic chỉ đi trong loopback/bridge network nội bộ.
