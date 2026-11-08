# p2p-listing Specification

## Purpose

掛單（Listing）的建立、狀態、取消與查詢，以及掛單階段的資產凍結。吃單（建立訂單）見 `p2p-order`。

## Requirements

### Requirement: 掛單狀態機
掛單 SHALL 只有 `active`、`paused`、`completed`、`cancelled` 四種狀態。

| 轉換 | 觸發者 | API |
|---|---|---|
| 建立為 `active` | 掛單者 | `POST /app/listings` |
| `active` 或 `paused` 轉 `cancelled` | 掛單者 | `PUT /app/listings/:id/cancel` |
| `active` 轉 `completed` | 系統（見「自動完成」） | 內部 |
| `active` 與 `paused` 互轉 | 掛單者 | 預留，尚無 API |

`completed` 與 `cancelled` 為終態。建立後 `type`、`cryptoCurrency`、`fiatCurrency` 不可修改。

#### Scenario: 終態不可回退
- **WHEN** 對 `cancelled` 或 `completed` 的掛單執行取消
- **THEN** 回應 HTTP 400 `only active or paused listings can be cancelled`

### Requirement: 建立掛單
系統 SHALL 在建立掛單前驗證：`type` 為 `buy` 或 `sell`；`cryptoCurrency`、`fiatCurrency` 存在於 `currencies` 且啟用；`totalAmount > 0`；`price > 0`；`minOrderFiat > 0`；`minOrderFiat <= maxOrderFiat`；`paymentTimeLimit >= 15`（分鐘，系統設定值，預設 15）；`type=sell` 時 `paymentMethodId` 必填，且屬於掛單者、狀態有效。手續費參數（`platformFeeBase`、`platformFeeRate`、`paymentFeeBase`、`paymentFeeRate`）由平台設定，使用者不可指定，目前皆為 0。建立成功的掛單 `status=active`、`remainingAmount=totalAmount`。

#### Scenario: 成功建立 sell 掛單
- **WHEN** 掛單者以有效欄位建立 `sell` 掛單，且可用餘額足夠
- **THEN** 建立 `active` 掛單並回傳 `id`，同一交易內凍結掛單者的 `totalAmount`

#### Scenario: 成功建立 buy 掛單
- **WHEN** 掛單者以有效欄位建立 `buy` 掛單
- **THEN** 建立 `active` 掛單，不凍結任何加密貨幣（掛單者是買方，不持有要出的幣）

#### Scenario: 最小金額大於最大金額
- **WHEN** `minOrderFiat` 大於 `maxOrderFiat`
- **THEN** 回應 HTTP 400

#### Scenario: 付款期限過短
- **WHEN** `paymentTimeLimit` 小於 15
- **THEN** 回應 HTTP 400

#### Scenario: sell 掛單缺少收款帳戶
- **WHEN** `type=sell` 且沒有 `paymentMethodId`
- **THEN** 回應 HTTP 400 `sell listing requires a payment method`

#### Scenario: sell 掛單餘額不足
- **WHEN** `type=sell` 且可用餘額小於 `totalAmount`
- **THEN** 回應 HTTP 400 `insufficient balance`，不建立掛單

### Requirement: 每個幣種每種類型只能有一筆進行中掛單
同一位使用者對每個加密貨幣幣種、每種掛單類型（`buy`、`sell`），同一時間 SHALL 最多有一筆 `active` 或 `paused` 的掛單。吃單（建立訂單）的數量不受限制。此限制 MUST 在建立掛單的鎖與交易內檢查，並以資料庫部分唯一索引（`(user_id, type, crypto_currency)`，條件 `status IN ('active','paused')`）作為最後防線。

#### Scenario: 已有進行中掛單
- **WHEN** 使用者已有某幣種的 `active` buy 掛單，又建立同幣種的 buy 掛單
- **THEN** 回應 HTTP 409，不建立掛單，也不凍結任何額度

#### Scenario: 並發建立
- **WHEN** 同一使用者同時送出兩個建立掛單請求
- **THEN** 只有一個成功，另一個回應 HTTP 409

#### Scenario: 不同幣種或不同類型
- **WHEN** 使用者已有 USDT 的 `active` buy 掛單，再建立 TRX 的 buy 掛單，或建立 USDT 的 sell 掛單
- **THEN** 建立成功

#### Scenario: 前一筆結束後再掛
- **WHEN** 使用者先前的掛單已是 `completed` 或 `cancelled`
- **THEN** 可以建立新掛單

### Requirement: 建立掛單的原子性
建立 `sell` 掛單時，凍結與寫入掛單 SHALL 在同一個資料庫交易內完成，並先取得掛單者錢包的分散式鎖。任何一步失敗，整筆交易回滾，不得留下已凍結但沒有掛單的餘額。

#### Scenario: 寫入掛單失敗
- **WHEN** 凍結成功但寫入 `listings` 失敗
- **THEN** 凍結一併回滾，掛單者的可用餘額不變

### Requirement: 取消掛單
掛單者 SHALL 能取消自己 `active` 或 `paused` 的掛單。若該掛單存在任何非終態訂單（`matched`、`paid`、`releasing`、`disputed`），系統 SHALL 拒絕取消。取消成功時，同一交易內 SHALL 把掛單狀態改為 `cancelled`，並（`type=sell`）解凍剩餘額度 `remainingAmount`。

#### Scenario: 有進行中訂單
- **WHEN** 掛單有一筆 `matched` 訂單，掛單者要取消
- **THEN** 回應 HTTP 400，掛單與餘額不變

#### Scenario: 取消 sell 掛單
- **WHEN** `sell` 掛單沒有進行中訂單，`remainingAmount=60`
- **THEN** 掛單轉為 `cancelled`，掛單者解凍 60

#### Scenario: 取消 buy 掛單
- **WHEN** `buy` 掛單沒有進行中訂單
- **THEN** 掛單轉為 `cancelled`，不需要解凍

#### Scenario: 非掛單者
- **WHEN** 其他使用者嘗試取消
- **THEN** 回應 HTTP 403

### Requirement: 剩餘量與凍結的一致性
`0 <= remainingAmount <= totalAmount` SHALL 恆成立。對 `sell` 掛單，掛單者錢包因該掛單而凍結的額度 SHALL 等於 `remainingAmount` 加上該掛單所有非終態訂單的數量。

#### Scenario: 吃單後
- **WHEN** `sell` 掛單 `totalAmount=100`，被吃 30
- **THEN** `remainingAmount=70`，該掛單對應的凍結額度仍為 100（70 可被吃，30 屬於進行中訂單）

### Requirement: 自動完成
當掛單 `remainingAmount=0` 且該掛單沒有任何非終態訂單時，系統 SHALL 在同一交易內把掛單狀態改為 `completed`。判斷時機為訂單進入終態（`completed`、`cancelled`、`timeout`、`refunded`）與訂單建立之後。`remainingAmount=0` 但仍有進行中訂單時，掛單維持 `active`（因剩餘量為零而無法再被吃單）；若該訂單後來取消，剩餘量還原後掛單仍為 `active`。

#### Scenario: 最後一筆訂單完成
- **WHEN** 掛單 `remainingAmount=0`，最後一筆進行中訂單轉為 `completed`
- **THEN** 掛單狀態轉為 `completed`

#### Scenario: 剩餘量為零但訂單仍進行
- **WHEN** 掛單被一筆訂單吃完，訂單狀態為 `matched`
- **THEN** 掛單維持 `active`，不可再被吃單

#### Scenario: 吃完的訂單被取消
- **WHEN** 上述訂單被取消，剩餘量還原
- **THEN** 掛單維持 `active`，剩餘量可再被吃單

### Requirement: 掛單查詢
系統 SHALL 提供 `GET /app/listings`（市場掛單，支援 `type`、`status` 篩選與分頁）、`GET /app/listings/:id`、`GET /app/listings/mine`（目前使用者全部掛單）。後台 SHALL 提供 `GET /backend/listings`。

#### Scenario: 市場列表預設
- **WHEN** 使用者未帶 `status`
- **THEN** 依分頁規則回傳掛單，篩選行為以 `openapi.yaml` 為準

## 待確認事項

- 一筆限制的範圍：使用者原話是「掛買單，每個幣種各一筆」，本規格解讀為 buy 與 sell 各自每個幣種一筆。若 sell 掛單不應受限，需要使用者決定。
- 本階段 `buy` 掛單者不凍結法幣（TWD）額度（2026-11-08 已決定）。
- `paused` 狀態的切換 API 尚未設計（規格預留）。
- `paymentTimeLimit` 最低 15 分鐘為原 spec 的「建議值」，是否固定為 15 或可由系統設定調整。
