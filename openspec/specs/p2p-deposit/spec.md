# p2p-deposit Specification

## Purpose

入金：法幣（TWD，經 ECPay）與加密貨幣（USDT／TRX，Tron 鏈上）。

## Requirements

### Requirement: 法幣入金流程
使用者 SHALL 能以 `POST /app/wallets/fiat/deposit`（`{ amount, currency: "TWD" }`）建立入金單，系統建立 `pending` 的 `fiat_deposits` 並回傳 ECPay 付款連結。狀態只有 `pending`、`paid`、`failed`：`pending` 轉 `paid`（ECPay 通知付款成功）、`pending` 轉 `failed`（付款失敗）。使用者 SHALL 能以 `GET /app/wallets/fiat/deposits` 查詢入金紀錄。

#### Scenario: 建立入金單
- **WHEN** 使用者要求入金 1000 TWD
- **THEN** 建立 `pending` 入金單，回傳 ECPay 付款連結

### Requirement: ECPay Webhook 驗簽
`POST /webhook/ecpay/notify` 是唯一不使用 JWT 的資料異動端點。系統 SHALL 先確認 ECPay 設定已啟用（`HashKey`、`HashIV` 非空），再驗證 `CheckMacValue`；驗簽失敗或未啟用 SHALL 拒絕（回 `0|<message>`），不得以空金鑰放行。`HashKey`、`HashIV` 只存於環境變數，不得寫入版本控制。日誌 MUST NOT 記錄整包通知參數。

#### Scenario: 簽章錯誤
- **WHEN** 通知的 `CheckMacValue` 不符
- **THEN** 拒絕通知，不改變入金單與餘額

#### Scenario: ECPay 未設定
- **WHEN** 服務未注入 `HashKey` 與 `HashIV`
- **THEN** 一律拒絕所有通知

### Requirement: ECPay 入帳的冪等與原子性
通知付款成功時，系統 SHALL 在單一交易內以條件式更新（`WHERE status='pending'`）把入金單轉為 `paid`，並僅在影響 1 列時入帳（`Deposit`，帳本類型 `fiat_deposit`）。入帳金額 MUST 取自資料庫既有的入金單金額，不採用通知帶入的 `TradeAmt`。付款失敗（`RtnCode` 非 `1`）SHALL 把入金單轉為 `failed` 並回 `1|OK`，已 `paid` 的入金單不得被改為 `failed`。處理失敗時 SHALL 回非成功，讓 ECPay 重送。

#### Scenario: 重複通知
- **WHEN** 同一 `MerchantTradeNo` 的通知重複送達
- **THEN** 只入帳一次，後續通知回 `1|OK`

#### Scenario: 金額竄改
- **WHEN** 通知的 `TradeAmt` 與入金單金額不同
- **THEN** 入帳金額仍為入金單的金額

#### Scenario: 資料庫故障
- **WHEN** 處理通知時資料庫不可用
- **THEN** 回非成功，系統恢復後由 ECPay 重送再處理

### Requirement: 加密貨幣入金偵測
Tron 掃描任務 SHALL 偵測進入使用者充值地址的 TRX／TRC20 USDT 交易，只對屬於系統使用者的地址處理。狀態只有 `pending`、`confirmed`、`failed`。同一 `tx_hash` MUST 只入帳一次（`crypto_deposits.tx_hash` UNIQUE），重複掃描視為冪等。使用者 SHALL 能以 `GET /app/wallets/crypto/deposit-info` 取得充值地址、以 `GET /app/wallets/crypto/deposits` 查詢紀錄。

#### Scenario: 重複掃描
- **WHEN** 掃描任務多次看到同一筆交易
- **THEN** 只有一筆入金紀錄，只入帳一次

#### Scenario: 鏈上失敗
- **WHEN** 交易在鏈上狀態為失敗
- **THEN** 紀錄為 `failed`，不入帳

### Requirement: 加密貨幣入金確認與入帳
當區塊確認數達到設定門檻（`Tron.ConfirmationBlocks`）時，系統 SHALL 在單一交易內把 `pending` 轉為 `confirmed` 並入帳。未達門檻 MUST NOT 入帳。鏈上重組導致已入帳交易消失的情況目前不處理，以足夠高的確認數門檻降低風險。

#### Scenario: 達到確認數
- **WHEN** 目前區塊與交易區塊的差達到門檻
- **THEN** 入金單轉為 `confirmed` 並增加可用餘額

#### Scenario: 未達確認數
- **WHEN** 確認數不足
- **THEN** 維持 `pending`，餘額不變

### Requirement: 加密貨幣精度
TRC20 USDT 在鏈上以 6 位小數計算（1 USDT = 1,000,000 sun）。系統 SHALL 以 Decimal 換算，儲存於 `NUMERIC(38,18)`，不得使用浮點數。

#### Scenario: 換算
- **WHEN** 掃描到 1,500,000 sun 的 USDT 轉入
- **THEN** 入帳金額為 `1.5` USDT

## 待確認事項

- 鏈上重組的處理（目前明確不處理）。
- 法幣入金逾時（`pending` 長時間未付款）轉 `failed` 的機制，目前只由 ECPay 通知觸發。
