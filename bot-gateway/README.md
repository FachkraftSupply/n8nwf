# Bot Gateway System

He thong automation cho **FS International / Elite Education** (cong ty dua hoc sinh Viet Nam di
Ausbildung tai Duc): gateway tap trung cho bot da nen tang (Telegram, du kien mo rong Zalo/Discord),
dong bo du lieu ClickUp <-> Postgres, backup he thong. Chay tren n8n self-hosted + Postgres Docker.

> **AI doc file nay lan dau:** nen doc theo thu tu **1. Muc nay (cau truc repo) -> 2. `docs/PROJECT_STATUS.md`
> (trang thai/checklist hien tai) -> 3. `docs/RULES.md` (quy tac bat buoc truoc khi sua bat ky workflow
> nao)**. 3 file nay du de nam toan bo ngu canh du an ma khong can doc lai lich su chat.

## Cau truc repo

```
bot-gateway/
|-- README.md                          <- file nay - bat dau doc tu day
|-- docs/                               <- TOAN BO tai lieu, xem bang chi tiet ben duoi
|-- sql/                                <- schema SQL goc (deploy DB lan dau)
|   |-- 01_gateway_schema.sql              schema `gateway` (auth, duyet user, config)
|   `-- 02_clickup_tasks_schema.sql        schema `clickup` (tasks/task_links/sync_targets) - LUU Y:
|                                          cac bang da tien hoa nhieu qua ALTER TABLE trong Ensure
|                                          Schema cua workflow - file nay KHONG con phan anh 100%
|                                          cau truc bang hien tai, chi dung cho lan khoi tao dau tien.
|-- scripts/
|   `-- restore.sh                         script khoi phuc DB tu backup
|-- original/                           <- 5 workflow PRODUCTION GOC, chi de THAM KHAO, KHONG SUA
|   |-- BACKUP_N8N.json                    mau tham khao cho SQL_Backup_System.json
|   |-- Elite_Crawl_Bot.json                mau tham khao cho tinh nang tom tat/crawl (chua xay)
|   |-- Elite_Help_Bot_GPT.json             mau goc - ban da nang cap nam o new_architecture/
|   |-- Telebot_main.json                   mau tham khao xu ly anh (xoa nen, OCR) - CHUA XAY
|   `-- Telebot_sql.json                    QUAN TRONG: mau tham so ClickUp node DUNG (xem RULES.md #4)
`-- workflows/new_architecture/         <- TOAN BO workflow dang trien khai/se trien khai
    |-- GW_Gateway_Telegram.json            OK ACTIVE - Gateway, chay tren bot user thuong (DEV/PROD)
    |-- GW_Error_Handler.json               OK ACTIVE - xu ly loi tap trung
    |-- SQL_ClickUp_Full_Reconcile.json     OK ACTIVE - "engine" sync 1 List ClickUp -> Postgres
    |-- SQL_ClickUp_Sync_Scheduler.json     OK ACTIVE - dieu phoi da-List, goi Full Reconcile dinh ky
    |-- SQL_ClickUp_Live_Update.json        OK ACTIVE - webhook real-time khi ClickUp thay doi
    |-- SQL_Backup_System.json              DANG XAY - backup n8n + Postgres, xem PROJECT_STATUS.md
    `-- sub_workflows_modernized/
        |-- Telebot_ClickUp_Reader.json     OK ACTIVE - bot user thuong (qua Gateway): /task, chi tiet
        |-- Telebot_Admin_System.json       OK ACTIVE - bot Admin (Trigger rieng, KHONG qua Gateway):
        |                                      /task, /sync, /sync_status, /db_status, /backup_n8n,
        |                                      /backup_db, /help - day du moi lenh
        |-- Elite_Help_Bot_GPT.json         SAN SANG - da nhan Envelope, cho Workflow ID gan Gateway
        |-- Telebot_main.json               KHONG DUNG - ban copy tham khao, da thay bang Reader+AdminSystem
        |-- Telebot_sql.json                KHONG DUNG - ban copy tham khao
        |-- Elite_Crawl_Bot.json            KHONG DUNG - ban copy tham khao, cho xay tinh nang moi
        `-- BACKUP_N8N.json                 KHONG DUNG - ban copy tham khao, da thay bang SQL_Backup_System.json
```

## Nhiem vu tung file trong `docs/`

| File | Khi nao doc | Noi dung |
|---|---|---|
| **`PROJECT_STATUS.md`** | **Luon doc dau tien** khi bat dau phien lam viec moi | Trang thai hien tai, checklist viec dang do, phat hien/loi moi nhat chua xu ly xong |
| **`RULES.md`** | **Luon doc truoc khi sua bat ky workflow nao** | Quy tac bat buoc: Gateway COMMAND_MAP, tham chieu `$json` tuong minh, khong dung inline keyboard, format node ClickUp, cach giu du lieu qua chuoi Postgres node... |
| `FAQ.md` | Khi gap loi | Loi thuong gap + cach da sua, tra cuu nhanh truoc khi debug lai tu dau |
| `CHANGELOG.md` | Muon biet lich su | Lich su thay doi theo ngay, chi tiet ky thuat day du hon PROJECT_STATUS |
| `ARCHITECTURE.md` | Hieu kien truc tong the | Kien truc gateway, Envelope Spec, huong dan AI dung them sub-workflow moi |
| `BOT_INVENTORY.md` | Can biet vai tro tung bot | Danh sach bot Telegram, vai tro, bot nao dung cho viec gi |
| `GO_LIVE_CHECKLIST.md` | Chuan bi go-live | Checklist doi credential khi cutover sang bot PROD |
| `GUIDE_SQL_CLICKUP_SYNC.md` | Van hanh sync ClickUp | Huong dan van hanh Full Reconcile + Live Update + Sync Scheduler |
| `GUIDE_DEPLOY_DATABASE.md` | Deploy DB lan dau | Huong dan trien khai 2 DB (Postgres + Supabase) cho nguoi moi |
| `SETUP_PHASE_0_1.md` | Setup ban dau | Import workflow, 7 test nghiem thu Phase 0-1 |
| `GUIDE_FULL_RECONCILE_EXPLAINED.md` | Hoc/hieu code | Giai thich chi tiet tung node Code trong Full Reconcile (Van de->Y tuong->Cach lam) |
| `GUIDE_gateway_explained.md` | Hoc/hieu code | Giai thich chi tiet node Code trong Gateway, danh cho nguoi moi hoc lap trinh |
| `GUIDE_live_update_explained.md` | Hoc/hieu code | Giai thich chi tiet node Code trong Live Update |
| `GUIDE_reader_adminsystem_explained.md` | Hoc/hieu code | Giai thich chi tiet node Code trong Reader + Admin System |
| `GUIDE_scheduler_explained.md` | Hoc/hieu code | Giai thich Sync Scheduler (khong co node Code, giai thich y nghia tung node co san) |
| `README.md` (trong docs/) | Muc luc nhanh | Bang lien ket ngan gon toi tat ca file tren (ban rut gon cua bang nay) |

## Kien truc luong chinh

```
User thuong -> @elite_n8n_test_bot (-> @Elite_clickup_bot khi go-live)
             -> GW_Gateway_Telegram.json -> Telebot_ClickUp_Reader.json
                (/task, chitiet_, /help rut gon)

Admin -> @elite_n8n_system_bot (Trigger rieng, KHONG qua Gateway)
      -> Telebot_Admin_System.json (day du moi lenh)

Dong bo du lieu (chay nen)
   SQL_ClickUp_Sync_Scheduler.json (dinh ky 5 ngay, dieu phoi da-List)
     -> SQL_ClickUp_Full_Reconcile.json (engine sync 1 List)
   SQL_ClickUp_Live_Update.json (webhook real-time)

Backup (chay nen hoac theo lenh admin)
   SQL_Backup_System.json (Manual/Schedule/Execute Workflow Trigger)
```

## Ha tang dang dung

- **n8n**: self-hosted, VPS Hostinger (AlmaLinux 10 + DirectAdmin), Docker Compose stack `n8n_stack`,
  image `n8nio/n8n:2.37.7` (Docker Hardened Image - khong co `apk`, khong cai them goi truc tiep duoc).
- **Postgres**: Docker container `n8n_stack-postgres-1`, image `postgres:16-alpine`, database `n8n`,
  schema `clickup` (tasks/task_links/sync_targets) + `gateway` (auth/config).
- **Supabase**: project "Telegram authentication DB" - dung song song cho 1 phan schema `gateway`.
- **OneDrive**: luu tru file backup (da chuyen tu Google Drive).
- **Repo**: `FachkraftSupply/n8nwf`, ket noi qua Composio (OAuth, khong dung token tho).

## Quy trinh lam viec chuan (cho AI ho tro du an)

1. Doc `docs/PROJECT_STATUS.md` truoc.
2. Doc `docs/RULES.md` truoc khi sua bat ky workflow nao.
3. Sua file JSON lon: dung Composio remote workbench (fetch GitHub -> sua Python trong sandbox -> commit).
4. Validate truoc khi commit (connections orphan, dup id, surrogate loi encoding).
5. Sau moi thay doi duoc xac nhan: cap nhat `CHANGELOG.md` + `PROJECT_STATUS.md`.
6. Moi khi them lenh moi: kiem tra CO DIEU KIEN xem sub-workflow do goi qua Gateway hay co Trigger rieng
   - chi cap nhat `COMMAND_MAP` cua Gateway neu goi qua Gateway.
