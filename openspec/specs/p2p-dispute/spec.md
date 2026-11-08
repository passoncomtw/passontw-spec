# p2p-dispute Specification

## Purpose

糾紛發起與後台仲裁。糾紛是訂單狀態機的一部分，狀態與轉換見 `p2p-order`。

## Requirements

### Requirement: 發起糾紛
買方或賣方 SHALL 能對 `paid` 訂單發起糾紛，請求 MUST 帶 `reason`。系統 SHALL 以條件式更新 `WHERE status='paid'` 轉為 `disputed`，寫入狀態日誌（含發起者與原因）、通知後台，並發布 `order.status.changed`。`matched` 訂單不可發起糾紛（買方尚未付款，沒有爭議標的）。糾紛期間賣方的加密貨幣額度 SHALL 維持凍結。

#### Scenario: 買方發起
- **WHEN** 買方對 `paid` 訂單發起糾紛並帶 reason
- **THEN** 訂單轉為 `disputed`，後台收到通知

#### Scenario: matched 不可糾紛
- **WHEN** 對 `matched` 訂單發起糾紛
- **THEN** 回應 HTTP 400 `order can only be disputed in paid status`

#### Scenario: 雙方同時發起
- **WHEN** 買方與賣方在毫秒內同時發起糾紛
- **THEN** 只有一個條件式更新成功，另一個回應 HTTP 400

#### Scenario: 非當事人
- **WHEN** 與訂單無關的使用者發起糾紛
- **THEN** 回應 HTTP 403

### Requirement: 糾紛期間不可確認收款
`disputed` 訂單 SHALL 不允許賣方 confirm。即使買方在發起糾紛後實際匯款，也 MUST 透過後台仲裁 `complete` 處理。

#### Scenario: 賣方嘗試 confirm
- **WHEN** 賣方對 `disputed` 訂單呼叫 confirm
- **THEN** 回應 HTTP 400，訂單狀態不變

### Requirement: 後台仲裁
後台人員 SHALL 能以 `PUT /backend/orders/:id/resolve` 仲裁 `disputed` 訂單，請求為 `{ action: "complete" | "refund", reason }`，`reason` 必填。系統 SHALL 在取得相關錢包鎖後，於單一交易內完成：

| action | 訂單狀態 | 資產處理 | escrow_records |
|---|---|---|---|
| `complete`（買方勝） | `completed`，寫入 `completedAt` | 賣方凍結額度轉給買方（`TransferIn`） | `release` |
| `refund`（賣方勝） | `refunded` | 依 `p2p-order` 的凍結規則返還額度並還原掛單 `remainingAmount`（與取消相同） | `refund` |

兩個分支都 MUST 寫入 `order_status_logs`（`operatorType=admin`、操作人 ID 取自 Backend JWT、`remark` 為 `reason`）並發布 `order.status.changed`。非 `disputed` 訂單回應 HTTP 400。`refunded` 為終態，`orders.status` 的資料庫 CHECK 約束 MUST 包含 `refunded`。

#### Scenario: 仲裁買方勝
- **WHEN** 管理員對 `disputed` 訂單 resolve `complete`
- **THEN** 訂單轉為 `completed`，額度轉給買方，日誌記錄管理員與原因

#### Scenario: 仲裁賣方勝（buy 掛單）
- **WHEN** 管理員 resolve `refund`，訂單來自 buy 掛單
- **THEN** 訂單轉為 `refunded`，吃單的賣方解凍，掛單 `remainingAmount` 還原

#### Scenario: 仲裁賣方勝（sell 掛單）
- **WHEN** 管理員 resolve `refund`，訂單來自 sell 掛單
- **THEN** 訂單轉為 `refunded`，掛單 `remainingAmount` 還原，額度留在該掛單的凍結內

#### Scenario: 缺少原因
- **WHEN** resolve 沒有 `reason`
- **THEN** 回應 HTTP 400

#### Scenario: 非糾紛訂單
- **WHEN** 對 `paid` 訂單 resolve
- **THEN** 回應 HTTP 400 `order is not in disputed status`

#### Scenario: 仲裁不可撤銷
- **WHEN** 對已 `completed` 或 `refunded` 的訂單再次 resolve
- **THEN** 回應 HTTP 400，狀態不變

### Requirement: 仲裁期間掛單狀態
掛單 SHALL 在存在 `disputed` 訂單期間不可被取消（`p2p-listing` 取消規則），因此 `refund` 還原剩餘量時掛單必為 `active` 或 `paused`。

#### Scenario: 糾紛中取消掛單
- **WHEN** 掛單有一筆 `disputed` 訂單，掛單者要取消掛單
- **THEN** 回應 HTTP 400

### Requirement: 糾紛逾時
系統 SHALL NOT 對 `disputed` 訂單自動逾時或自動仲裁，`disputed` 訂單由後台監控並人工處理。

#### Scenario: 長期未處理
- **WHEN** 糾紛建立 30 天沒有人仲裁
- **THEN** 訂單維持 `disputed`，額度維持凍結

## 待確認事項

- 糾紛 SLA 告警（未來可加）。
- 原 spec 寫 `refund` 後訂單為 `cancelled`；依 2026-11-08 決策改為獨立狀態 `refunded`，需同步更新資料庫 CHECK 約束與 App、後台前端的狀態顯示。
- `complete` 仲裁是否也要經過 `releasing`（目前規格為直接轉 `completed`）。
