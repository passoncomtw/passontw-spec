# p2p-order Specification

## Purpose

訂單（Order）的建立（吃單）、付款、確認收款、取消、逾時，以及訂單階段的資產凍結與釋放。糾紛與仲裁見 `p2p-dispute`；掛單見 `p2p-listing`；餘額操作見 `p2p-wallet`。

## Requirements

### Requirement: 訂單狀態機
訂單 SHALL 只有下列狀態。`completed`、`cancelled`、`timeout`、`refunded` 為終態，不可再轉換。

| 狀態 | 說明 |
|---|---|
| `matched` | 已建立，等待買方付款 |
| `paid` | 買方已標記付款，等待賣方確認 |
| `releasing` | 賣方已確認收款，系統正在釋放加密貨幣（中間態） |
| `completed` | 加密貨幣已轉給買方 |
| `cancelled` | 買方或賣方在 `matched` 階段取消 |
| `timeout` | 付款期限到期，系統取消 |
| `disputed` | 糾紛中，等待後台仲裁 |
| `refunded` | 後台仲裁判賣方勝，額度已退還 |

| 轉換 | 觸發者 | API |
|---|---|---|
| 建立為 `matched` | 吃單者 | `POST /app/orders` |
| `matched` 轉 `paid` | 買方 | `PUT /app/orders/:id/pay` |
| `matched` 轉 `cancelled` | 買方或賣方 | `PUT /app/orders/:id/cancel` |
| `matched` 轉 `timeout` | 系統 | NATS `order.timeout.check` |
| `paid` 轉 `releasing` 轉 `completed` | 賣方 | `PUT /app/orders/:id/confirm` |
| `paid` 轉 `disputed` | 買方或賣方 | `PUT /app/orders/:id/dispute` |
| `disputed` 轉 `completed` 或 `refunded` | 後台 | `PUT /backend/orders/:id/resolve` |

每次狀態轉換 SHALL 以條件式更新（`UPDATE ... WHERE id = ? AND status = <預期狀態>`）執行，並檢查影響列數；影響 0 列代表狀態已被其他請求改變，該請求視為失敗或冪等結束（依各 Requirement）。

#### Scenario: 終態不可逆
- **WHEN** 對 `completed`、`cancelled`、`timeout`、`refunded` 的訂單執行任何狀態轉換
- **THEN** 回應 HTTP 400，狀態不變

#### Scenario: 轉換競速
- **WHEN** 兩個請求同時嘗試轉換同一筆訂單
- **THEN** 只有一個的條件式更新影響 1 列並成功，另一個影響 0 列

### Requirement: 建立訂單（吃單）
系統 SHALL 在建立訂單前驗證：掛單 `status=active`；`cryptoAmount > 0` 且不超過 `remainingAmount`；吃單者不是掛單者本人；`fiatAmount = cryptoAmount × price`（Decimal，取至 18 位小數）落在 `minOrderFiat` 與 `maxOrderFiat` 之間。手續費 `platformFeeAmount = fiatAmount × platformFeeRate`、`paymentFeeAmount = fiatAmount × paymentFeeRate`、`totalFee = platformFeeBase + platformFeeAmount + paymentFeeBase + paymentFeeAmount`、`totalAmount = fiatAmount + totalFee`，皆以 Decimal 計算。訂單 `paymentDeadline = 建立時間 + 掛單 paymentTimeLimit 分鐘`。吃單的次數沒有限制。

角色：掛單 `type=sell` 時，掛單者是賣方、吃單者是買方，收款帳戶為掛單的 `paymentMethodId`；`type=buy` 時，掛單者是買方、吃單者是賣方，收款帳戶為吃單者（賣方）第一筆有效收款帳戶。

#### Scenario: 成功吃 sell 掛單
- **WHEN** 買方對 `active` 的 sell 掛單吃 30
- **THEN** 建立 `matched` 訂單並回傳 `id`、`orderNo`，掛單 `remainingAmount` 減 30

#### Scenario: 吃自己的掛單
- **WHEN** 掛單者本人呼叫吃單
- **THEN** 回應 HTTP 400 `cannot take own listing`

#### Scenario: 超過剩餘量
- **WHEN** 掛單剩餘 50，吃單者要吃 60
- **THEN** 回應 HTTP 400 `insufficient remaining amount in listing`

#### Scenario: 金額低於或高於限額
- **WHEN** `fiatAmount` 小於 `minOrderFiat` 或大於 `maxOrderFiat`
- **THEN** 回應 HTTP 400

#### Scenario: buy 掛單吃單者沒有收款帳戶
- **WHEN** 吃 buy 掛單的賣方沒有有效收款帳戶
- **THEN** 回應 HTTP 400 `seller has no active payment method`

### Requirement: 吃單的凍結規則
訂單階段的凍結對象 SHALL 是持有加密貨幣的賣方，且「掛單凍結掛單者的額度，吃單凍結吃單者的額度」依下表執行：

| 掛單類型 | 掛單時凍結 | 吃單時凍結 | 取消、逾時 | 確認收款 |
|---|---|---|---|---|
| `sell` | 掛單者（賣方）凍結 `totalAmount` | 不再額外凍結，從掛單已凍結的額度中分配給訂單，`remainingAmount` 扣減 | 還原掛單 `remainingAmount`，額度留在掛單的凍結內，不解凍 | 掛單者的凍結額度轉給吃單者（買方） |
| `buy` | 不凍結 | 吃單者（賣方）凍結 `cryptoAmount`，`remainingAmount` 扣減 | 吃單者解凍 `cryptoAmount`，並還原掛單 `remainingAmount` | 吃單者的凍結額度轉給掛單者（買方） |

#### Scenario: 吃 buy 掛單的凍結
- **WHEN** 賣方吃 buy 掛單 40 USDT，可用餘額 100
- **THEN** 賣方可用餘額變 60、凍結增加 40

#### Scenario: 吃 buy 掛單餘額不足
- **WHEN** 賣方可用餘額 30，要吃 40
- **THEN** 回應 HTTP 400 `insufficient balance`，不建立訂單，掛單剩餘量不變

### Requirement: 建立訂單的鎖與原子性
建立訂單 SHALL 先取得下列鎖：該掛單的分散式鎖，以及被凍結一方錢包的分散式鎖（多把鎖依固定順序取得）。其後在單一資料庫交易內依序完成：以 `SELECT ... FOR UPDATE` 重新讀取掛單並再驗證狀態與剩餘量、凍結（僅 buy 掛單）、寫入訂單、扣減掛單剩餘量、寫入 `escrow_records`（`action=lock`）、寫入 `order_status_logs`（轉為 `matched`）。任何一步失敗，整筆交易回滾；任何一步的錯誤都 MUST NOT 被忽略。NATS `order.status.changed` 在交易提交之後才發布。

#### Scenario: 並發吃單
- **WHEN** 掛單剩餘 100，A 與 B 同時各吃 60
- **THEN** 只有一個成功；另一個回應 HTTP 400 或 409，掛單剩餘量不會小於 0

#### Scenario: 扣減剩餘量失敗
- **WHEN** 寫入訂單成功但扣減掛單剩餘量失敗
- **THEN** 整筆交易回滾，不留下訂單、不留下凍結

#### Scenario: 凍結後寫入訂單失敗
- **WHEN** buy 掛單吃單時，凍結成功但寫入 `orders` 違反約束
- **THEN** 凍結一併回滾，賣方餘額不變

### Requirement: 標記付款
買方 SHALL 能將 `matched` 訂單標記為已付款，系統記錄 `paidAt`、寫入狀態日誌、發布 `order.status.changed`。非買方回應 HTTP 403；非 `matched` 狀態回應 HTTP 400。

#### Scenario: 買方標記付款
- **WHEN** 買方對 `matched` 訂單呼叫 pay
- **THEN** 訂單轉為 `paid`，`paidAt` 有值

#### Scenario: 賣方呼叫 pay
- **WHEN** 賣方對訂單呼叫 pay
- **THEN** 回應 HTTP 403

### Requirement: 確認收款與 releasing 中間態
賣方 SHALL 能對 `paid` 訂單確認收款。系統 SHALL 依下列順序處理：先以條件式更新把 `paid` 轉為 `releasing`（此寫入由 confirm 請求自己完成，同時作為防止重複放幣的守衛），隨後在單一交易內完成加密貨幣轉移（`TransferIn`）、狀態轉為 `completed`、寫入 `escrow_records`（`action=release`）與狀態日誌。對 `releasing` 的訂單，賣方重複呼叫 confirm SHALL 重新嘗試轉移並完成；對已 `completed` 的訂單重複呼叫 SHALL 冪等回應成功；對 `disputed` 訂單 SHALL 回應 HTTP 400。取鎖 SHALL 一次取得賣方與買方兩把錢包鎖。

#### Scenario: 正常放幣
- **WHEN** 賣方對 `paid` 訂單呼叫 confirm
- **THEN** 訂單經 `releasing` 到 `completed`，凍結額度轉給買方，帳本寫入 `transfer_out` 與 `transfer_in`

#### Scenario: 轉移失敗
- **WHEN** 訂單已轉為 `releasing`，但轉移交易失敗
- **THEN** 訂單停留在 `releasing`，額度不變，賣方可再次呼叫 confirm 重試，系統記錄告警

#### Scenario: 重複 confirm
- **WHEN** 賣方因網路重試對已 `completed` 的訂單再次呼叫 confirm
- **THEN** 回應成功，不重複轉移

#### Scenario: 糾紛中 confirm
- **WHEN** 賣方對 `disputed` 訂單呼叫 confirm
- **THEN** 回應 HTTP 400

#### Scenario: 買方呼叫 confirm
- **WHEN** 買方對訂單呼叫 confirm
- **THEN** 回應 HTTP 403

### Requirement: 取消訂單
買方或賣方 SHALL 能取消 `matched` 訂單，請求 MUST 帶 `reason`。取消 SHALL 在單一交易內完成：條件式更新轉為 `cancelled`、依「吃單的凍結規則」返還額度並還原掛單 `remainingAmount`、寫入 `escrow_records`（`action=refund`）與狀態日誌。取消成功才返還額度；取消失敗不得改變額度。取消後 SHALL 重新評估掛單的自動完成條件。

#### Scenario: 取消 buy 掛單的訂單
- **WHEN** 賣方取消自己吃 buy 掛單所產生的 `matched` 訂單
- **THEN** 賣方解凍 `cryptoAmount`，掛單 `remainingAmount` 還原

#### Scenario: 取消 sell 掛單的訂單
- **WHEN** 買方取消吃 sell 掛單所產生的 `matched` 訂單
- **THEN** 掛單 `remainingAmount` 還原，賣方的凍結額度不變（仍屬於該掛單）

#### Scenario: 已付款不可取消
- **WHEN** 對 `paid` 訂單呼叫 cancel
- **THEN** 回應 HTTP 400 `order can only be cancelled in matched status`

#### Scenario: 缺少原因
- **WHEN** cancel 沒有 `reason`
- **THEN** 回應 HTTP 400

### Requirement: 逾時處理
系統 SHALL 每 60 秒發布 `order.timeout.check`；消費者 SHALL 對每筆 `paymentDeadline` 已過且仍為 `matched` 的訂單，以 `processing:order:{id}` 的分散式鎖與資料庫交易處理。逾時的資產處理邏輯 SHALL 與取消完全相同（返還額度、還原掛單剩餘量、寫入 `escrow_records` 的 `refund` 與狀態日誌），差別只有：目標狀態為 `timeout`、操作者為 `system`。已是 `paid` 的訂單 SHALL 跳過。

#### Scenario: 逾時取消
- **WHEN** `matched` 訂單超過 `paymentDeadline`
- **THEN** 訂單轉為 `timeout`，額度返還與還原邏輯與取消相同

#### Scenario: 與付款競速
- **WHEN** 買方在期限前一刻完成 pay，逾時任務同時執行
- **THEN** 條件式更新 `WHERE status='matched'` 只有一方成功；訂單已是 `paid` 時逾時任務跳過

#### Scenario: 與取消競速
- **WHEN** 使用者取消與逾時任務同時發生
- **THEN** 只有一個成功，另一個影響 0 列，額度只返還一次

### Requirement: 狀態日誌與託管紀錄
每次訂單狀態轉換 SHALL 在同一交易內寫入 `order_status_logs`（含 `fromStatus`、`toStatus`、`operatorType`、`operatorId`、`remark`）。`operatorType` 為 `buyer`、`seller`、`admin`、`system`。`escrow_records` SHALL 在訂單建立時寫 `lock`，在 `completed` 時寫 `release`，在 `cancelled`、`timeout`、`refunded` 時寫 `refund`。

#### Scenario: 操作者留存
- **WHEN** 後台管理員仲裁後帳號被停用
- **THEN** 日誌中的 `operatorType=admin` 與 `operatorId` 永久保留

### Requirement: 訂單通知
訂單狀態轉換提交後，系統 SHALL 發布 NATS `order.status.changed`，內容含訂單 ID、新狀態、買方與賣方 ID。發布失敗 MUST NOT 讓已提交的轉換回滾。

#### Scenario: 通知對象
- **WHEN** 訂單轉為 `paid`
- **THEN** 賣方與後台收到通知

### Requirement: 訂單查詢
系統 SHALL 提供 `GET /app/orders`（支援 `role`、`status`、分頁）與 `GET /app/orders/:id`。訂單詳情 SHALL 只對買方、賣方開放；後台透過 `GET /backend/orders` 查詢。

#### Scenario: 查詢他人訂單
- **WHEN** 與該訂單無關的使用者查詢 `GET /app/orders/:id`
- **THEN** 回應 HTTP 403

## 待確認事項

- 本階段只凍結持有加密貨幣的一方；買方的法幣（TWD）額度不凍結（2026-11-08 已決定本階段不需要），日後若要凍結需另行修訂凍結規則表。
- `releasing` 的重試入口目前只有賣方重打 confirm；是否需要後台手動補完或自動重試任務。
- 手續費與法幣金額的捨入方式（見 `p2p-conventions`，四捨五入為暫定）。
