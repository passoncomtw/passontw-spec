# p2p-conventions Specification

## Purpose

p2p-exchange-service 全部 API 共用的約定：回應格式、驗證、資料型別、分頁，以及不屬於基準規格的 legacy 路由。

基準來源：獨立程式碼庫 `passoncomtw/p2p-exchange-service` 的 `openspec/specs` 與實際路由（`server.go`，HEAD `4497883`），並套用 2026-11-08 的規格決策。規格與現行實作的落差見 `documents/spec-code-gap-analysis.md` 第七節。

本規格集共 7 份：`p2p-conventions`、`p2p-listing`、`p2p-order`、`p2p-dispute`、`p2p-wallet`、`p2p-deposit`、`p2p-withdrawal`。API 的欄位與路徑細節見 `api-specs/projects/p2p-exchange-service/openapi.yaml`。

## Requirements

### Requirement: 統一回應格式
所有 JSON API SHALL 以 `{ code, message, data }` 回應。成功時 HTTP 200、`code` 為整數 `0`、`message` 為 `success`。失敗時 HTTP status 與 `code` 相同（400、401、403、404、409、500），`data` 為 `null`。建立類端點成功時同樣回 HTTP 200。

例外（依現行實作，`openapi.yaml` 已照實描述）：`GET /api/v1/version` 直接回 `{ "version": ... }`；`GET /healthz` 直接回依賴檢查結果，不健康時 HTTP 503；`POST /webhook/ecpay/notify` 回純文字 `1|OK` 或 `0|<message>`（一律 HTTP 200）。帳本（ledger）的 `amount` 為帶正負號的 Decimal 字串（扣減為負）。

#### Scenario: 成功回應
- **WHEN** 任何端點處理成功
- **THEN** 回應為 HTTP 200，本文為 `{ "code": 0, "message": "success", "data": ... }`

#### Scenario: 失敗回應
- **WHEN** 端點因業務規則拒絕請求（例如餘額不足）
- **THEN** HTTP status 與本文 `code` 相同，`message` 說明原因，`data` 為 `null`

### Requirement: 身分驗證分區
`/app/*` 端點 SHALL 使用 App JWT，`/backend/*` 端點 SHALL 使用 Backend JWT，兩者使用各自獨立的簽章金鑰。以下端點不需要 JWT：`POST /app/auth/register`、`POST /app/auth/login`、`POST /backend/auth/login`、`POST /webhook/ecpay/notify`（以 ECPay CheckMacValue 驗簽）、`GET /healthz`、`GET /api/v1/version`。任何會修改資料的後台端點 MUST 要求 Backend JWT，且操作人 ID MUST 取自 JWT，不可取自請求本文。

#### Scenario: 缺少 JWT
- **WHEN** 呼叫需要 JWT 的端點但沒有帶 token
- **THEN** 回應 HTTP 401

#### Scenario: App token 呼叫後台
- **WHEN** 以 App JWT 呼叫 `/backend/*`
- **THEN** 回應 HTTP 401

#### Scenario: 操作人來源
- **WHEN** 後台人員審核提領或仲裁訂單
- **THEN** 紀錄的操作人 ID 取自 Backend JWT，請求本文中若有同名欄位一律忽略

### Requirement: 金額一律使用 Decimal
所有金額類欄位（加密貨幣數量、單價、法幣金額、手續費、餘額、入金與出金金額）SHALL 統一使用同一種 Decimal 型別：資料庫為 `NUMERIC(38,18)`，API 為十進位字串，格式 `^\d{1,20}(\.\d{1,18})?$`（非負、無正負號、無科學記號；帳本的帶號金額除外）。禁止使用 `float64` 或 `big.Float` 做金額運算。乘法等運算結果超過 18 位小數時 SHALL 以四捨五入（half up）取至 18 位。費率（`platformFeeRate`、`paymentFeeRate`）是比例而非金額，資料庫為 `NUMERIC(10,8)`，同樣以字串傳輸。

#### Scenario: 金額欄位為字串
- **WHEN** API 回傳掛單或訂單
- **THEN** `totalAmount`、`remainingAmount`、`price`、`fiatAmount` 等欄位皆為字串

#### Scenario: 超過精度的輸入
- **WHEN** 請求的金額小數位數超過 18 位
- **THEN** 回應 HTTP 400，不做靜默截斷或四捨五入

#### Scenario: 負數或非數字
- **WHEN** 金額欄位為負數、零（要求正數的欄位）、空字串或含科學記號
- **THEN** 回應 HTTP 400 `invalid amount`

### Requirement: 識別碼與時間格式
資源 ID SHALL 為 `int64`，訂單另有人類可讀的 `orderNo`。所有時間 SHALL 以 UTC 儲存，API 以 ISO 8601（RFC 3339）字串回傳。

#### Scenario: 付款期限
- **WHEN** 訂單建立
- **THEN** `paymentDeadline` 以 UTC 的 RFC 3339 字串回傳，由前端轉為本地時間顯示

### Requirement: 分頁
列表端點 SHALL 使用 `limit` 與 `offset` 查詢參數，預設 `limit=20`、`offset=0`。

#### Scenario: 預設分頁
- **WHEN** 列表端點未帶分頁參數
- **THEN** 回傳最多 20 筆，從第 0 筆開始

### Requirement: Legacy 路由不屬於基準規格
`/v1/orders`、`/v1/orders/mine`、`/v1/orders/:id/cancel`、`/v1/admin/orders`、`/v1/admin/orders/:id`、`/v1/admin/orders/:id/complete` 為舊版 demo 路由，不納入基準規格，服務 SHALL NOT 提供這些路由（已移除）。

#### Scenario: 已移除的路由
- **WHEN** 任何請求呼叫上述 `/v1/*` 路由
- **THEN** 回應 HTTP 404

## 待確認事項

- 乘法結果取至 18 位小數的捨入方式（四捨五入）為整理時暫定，未經使用者確認。
- 法幣欄位（`orders.fiat_amount`、手續費、`fiat_deposits`、`fiat_withdrawals`）目前資料庫精度為 `NUMERIC(20,4)` 或 `NUMERIC(18,2)`，需要 migration 統一為 `NUMERIC(38,18)`。
