## Why

`staff-scheduling` 專案目前只有初始化時建立的空殼骨架，`openapi.yaml` 沒有任何 API endpoint，`Employee`、`Shift` schema 皆為空殼，沒有任何業務邏輯或資料模型定義。使用者需要一個最小可行的預約式排班原型：後台為人員與客戶建立預約時段，避免同一人員或同一客戶的時段衝突，人員與客戶可透過同一支 App 查看（及取消）自己的預約。本次提案補上這個角色（後台使用者、人員、客戶）的核心流程，作為 v1 prototype。

## What Changes

- 新增後台 Web 能力：新增人員帳號（手機＋密碼，建立時同時設定初始密碼，人員不可自行註冊）、建立預約（選人員、選客戶、選時段）、取消任一筆預約。
- 新增客戶 App 能力：自行註冊（手機＋密碼）、登入查看並取消自己名下的預約。
- 新增人員 App 能力：登入（帳號由後台建立）查看自己名下的班表，唯讀，無取消/修改權限。
- 新增雙重時段衝突檢查：建立預約時，同一人員時段重疊、同一客戶時段重疊皆不可建立；同一客戶的重疊檢查排除已取消（cancelled）的預約。
- 重新定義 `Employee`、新增 `Customer`，`Shift` 改為 `Appointment` 並補上實際欄位，取代目前「內容後續補充」的佔位 schema。
- **架構決策**：人員與客戶共用同一支 App（依登入身份顯示對應角色內容）；後台使用者使用獨立的 Web 後台（非 App）；認證沿用既有 `bearerAuth`（JWT）機制。

## Capabilities

### New Capabilities
- `staff-appointment-scheduling`：後台建立人員與客戶的預約式排班能力，涵蓋後台人員帳號管理、客戶自助註冊、建立預約與雙重時段衝突檢查、取消預約（後台/客戶）、人員與客戶 App 查看班表。

### Modified Capabilities
（無。`staff-scheduling` 目前尚無 baseline spec。）

## Impact

- 影響 `api-specs/projects/staff-scheduling/openapi.yaml`：新增人員帳號管理、客戶註冊、預約建立/取消、班表查詢相關 API endpoint（實作階段補上）。
- 影響 `api-specs/projects/staff-scheduling/schemas/employee.yaml`：`Employee` schema 從空殼補上 `id`、`name`、`phone`、`password` 等欄位。
- 影響 `api-specs/projects/staff-scheduling/schemas/shift.yaml`：改為 `Appointment` schema，補上 `id`、`employeeId`、`customerId`、`startTime`、`endTime`、`status`、`cancelledBy` 等欄位。
- 新增 `Customer` schema（客戶帳號）。
- 不影響 `pos-systems`、`p2p-exchange-service`、`games-system`。

## 本次不含（留給後續版本）

- 修改/改期既有預約（v1 只有新增與取消）
- 人員自行調整班表、請假排休
- 通知/提醒功能
- 預約取消時間限制（例如開始前 X 小時內禁止取消）
