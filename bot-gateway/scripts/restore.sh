#!/bin/bash
# ============================================================================
# restore.sh — Khôi phục n8n + Postgres + Credentials sau khi VPS sập
#
# CHẠY TRÊN VPS MỚI (sau khi đã docker-compose up -d lại đúng stack n8n_stack)
# CHƯA TỪNG test thật trên production — test trên 1 n8n instance rỗng trước.
#
# Cách dùng:
#   ./restore.sh <postgres_backup.sql> <n8n_workflows_backup.json> <credentials_backup.json.enc> <userId>
#
# 4 tham số lấy từ đâu:
#   1. postgres_backup_YYYY-MM-DD.sql        -> tải từ OneDrive folder "N8N Workflow backup"
#   2. n8n_backup_YYYY-MM-DD.json             -> tải từ OneDrive folder "N8N Workflow backup"
#   3. n8n_credentials_backup_YYYY-MM-DD.json.enc -> tải từ OneDrive (file đã MÃ HÓA)
#   4. userId  -> ID user owner trên n8n MỚI (Settings > Users trong UI n8n, hoặc lấy qua
#      lệnh: docker exec n8n_stack-n8n-1 n8n user-management:reset  --help  (n8n >=1.x có
#      lệnh liệt kê user riêng tùy version — nếu không chắc, để trống --userId thì n8n CLI
#      tự gán cho owner mặc định trong single-user setup)
#
# ============================================================================
set -euo pipefail

POSTGRES_CONTAINER="n8n_stack-postgres-1"
N8N_CONTAINER="n8n_stack-n8n-1"
DB_USER="n8n"
DB_NAME="n8n"
PASSPHRASE_FILE="/root/.n8n_backup_passphrase"

SQL_BACKUP_FILE="${1:?Thiếu tham số 1: đường dẫn file postgres_backup_*.sql}"
N8N_BACKUP_FILE="${2:?Thiếu tham số 2: đường dẫn file n8n_backup_*.json}"
CRED_BACKUP_FILE="${3:?Thiếu tham số 3: đường dẫn file n8n_credentials_backup_*.json.enc}"
USER_ID="${4:-}"

echo "=============================================================="
echo "BƯỚC 0 — KIỂM TRA ĐIỀU KIỆN TIÊN QUYẾT"
echo "=============================================================="

for f in "$SQL_BACKUP_FILE" "$N8N_BACKUP_FILE" "$CRED_BACKUP_FILE"; do
  [[ -f "$f" ]] || { echo "LỖI: không tìm thấy file $f"; exit 1; }
done

if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}\$"; then
  echo "LỖI: container $POSTGRES_CONTAINER chưa chạy."
  echo "  -> Cần docker-compose up -d trước (dùng docker-compose.yml đã backup riêng,"
  echo "     xem mục 'LỖ HỔNG CHƯA XỬ LÝ' trong báo cáo kèm theo script này)."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${N8N_CONTAINER}\$"; then
  echo "LỖI: container $N8N_CONTAINER chưa chạy."
  exit 1
fi

if [[ ! -f "$PASSPHRASE_FILE" ]]; then
  echo "CẢNH BÁO: không tìm thấy $PASSPHRASE_FILE trên máy này (bình thường nếu đây là VPS mới)."
  read -rp "Dán passphrase gốc (đã backup riêng ở nơi khác) vào đây: " -s MANUAL_PASSPHRASE
  echo
  echo -n "$MANUAL_PASSPHRASE" > /root/.n8n_backup_passphrase_restore_tmp
  chmod 600 /root/.n8n_backup_passphrase_restore_tmp
  PASSPHRASE_FILE="/root/.n8n_backup_passphrase_restore_tmp"
fi

echo ""
echo "=============================================================="
echo "BƯỚC 1 — RESTORE POSTGRES (clickup + gateway schema)"
echo "=============================================================="
read -rp "Bước này sẽ ghi đè dữ liệu Postgres hiện tại. Gõ 'yes' để tiếp tục: " CONFIRM1
[[ "$CONFIRM1" == "yes" ]] || { echo "Đã hủy."; exit 1; }

docker cp "$SQL_BACKUP_FILE" "${POSTGRES_CONTAINER}:/tmp/restore.sql"
docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/restore.sql
docker exec "$POSTGRES_CONTAINER" rm -f /tmp/restore.sql
echo "-> Postgres restore xong."

echo ""
echo "=============================================================="
echo "BƯỚC 2 — GIẢI MÃ + RESTORE CREDENTIALS"
echo "=============================================================="
openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass file:"$PASSPHRASE_FILE" \
  -in "$CRED_BACKUP_FILE" -out /tmp/creds_restore_local.json
docker cp /tmp/creds_restore_local.json "${N8N_CONTAINER}:/tmp/creds_restore.json"
rm -f /tmp/creds_restore_local.json /root/.n8n_backup_passphrase_restore_tmp 2>/dev/null || true

IMPORT_CRED_CMD="n8n import:credentials --input=/tmp/creds_restore.json"
[[ -n "$USER_ID" ]] && IMPORT_CRED_CMD="$IMPORT_CRED_CMD --userId=$USER_ID"
docker exec "$N8N_CONTAINER" sh -c "$IMPORT_CRED_CMD"
docker exec "$N8N_CONTAINER" rm -f /tmp/creds_restore.json
echo "-> Credentials restore xong (plaintext đã bị xóa khỏi container ngay sau import)."

echo ""
echo "=============================================================="
echo "BƯỚC 3 — RESTORE WORKFLOWS"
echo "=============================================================="
docker cp "$N8N_BACKUP_FILE" "${N8N_CONTAINER}:/tmp/workflows_restore.json"
IMPORT_WF_CMD="n8n import:workflow --input=/tmp/workflows_restore.json"
[[ -n "$USER_ID" ]] && IMPORT_WF_CMD="$IMPORT_WF_CMD --userId=$USER_ID"
docker exec "$N8N_CONTAINER" sh -c "$IMPORT_WF_CMD"
docker exec "$N8N_CONTAINER" rm -f /tmp/workflows_restore.json
echo "-> Workflows restore xong (mặc định TẤT CẢ ở trạng thái deactivated — bật tay lại workflow"
echo "   nào cần active, xem flag --activeState=fromJson nếu muốn tự động theo đúng trạng thái cũ)."

echo ""
echo "=============================================================="
echo "HOÀN TẤT — việc còn lại cần làm TAY:"
echo "=============================================================="
echo "1. Vào n8n UI, kiểm tra danh sách workflow + credential đã khôi phục đúng chưa."
echo "2. Gán lại credential cho từng node SSH/OneDrive/Telegram/Postgres nếu bị mất liên kết"
echo "   (import theo ID gốc thường tự nối lại đúng, nhưng credential SSH riêng — private key —"
echo "   cần gán lại KHÓA MỚI nếu SSH key cũ đã mất theo VPS cũ)."
echo "3. Bật (activate) lại các workflow có Trigger tự động (Schedule/Webhook)."
echo "4. Nếu SSH key n8n dùng để tự SSH lại vào VPS đã mất (nằm trong ~/.ssh của VPS CŨ, không"
echo "   phải trong Postgres/n8n backup) -> phải tạo key mới + add vào authorized_keys VPS mới."
