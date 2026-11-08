# p2p-withdrawal Specification

## Purpose

出金：法幣（TWD，銀行轉帳，後台人工審核）與加密貨幣（Tron，自動批次廣播）。

## Requirements

### Requirement: 法幣出金申請
使用者 SHALL 能以 `POST /app/wallets/fiat/withdraw`（`{ amount, currency: "TWD", bankCode, bankAccount, accountName }`）申請出金。系統 SHALL 在單一交易內凍結申請金額並建立 `pending` 的 `fiat_withdrawals`。可用餘額不足 SHALL 回應 HTTP 400 `insufficient balance`。使用者 SHALL 能以 `GET /app/wallets/fiat/withdrawals` 查詢紀錄（銀行帳號遮罩顯示）。

#### Scenario: 申請成功
- **WHEN** 可用餘額 1000，申請 400
- **THEN** 凍結 400、建立 `pending` 紀錄

#### Scenario: 餘額不足
- **WHEN** 申請金額大於可用餘額
- **THEN** 回應 HTTP 400，不建立紀錄

### Requirement: 法幣出金審核
後台 SHALL 能以 `PUT /backend/fiat-withdrawals/:id/review`（`{ action: "approve" | "reject", reason }`）審核。狀態只有 `pending`、`approved`、`rejected`。`approve` SHALL 從凍結餘額永久扣除（`DeductFrozen`）；`reject` SHALL 把凍結額度退回可用餘額（`Unfreeze`），且 `reject` MUST 帶 `reason`。審核人 ID MUST 取自 Backend JWT 並記錄。審核 SHALL 以條件式更新 `WHERE status='pending'`，已審核過的申請 SHALL 回應 HTTP 409 `此申請已審核完畢`。`approved` 為終態，不可撤銷。

#### Scenario: 核可
- **WHEN** 後台核可 `pending` 申請
- **THEN** 狀態轉 `approved`，凍結額度永久扣除，記錄審核人

#### Scenario: 駁回
- **WHEN** 後台駁回並填原因
- **THEN** 狀態轉 `rejected`，凍結額度退回可用餘額

#### Scenario: 雙擊核可
- **WHEN** 同一申請被快速核可兩次
- **THEN** 第二次回應 HTTP 409，不重複扣款

#### Scenario: 駁回缺少原因
- **WHEN** `reject` 沒有 `reason`
- **THEN** 回應 HTTP 400

### Requirement: 法幣出金的待處理筆數
系統 SHALL NOT 限制同一使用者同時 `pending` 的法幣出金筆數；每筆申請 SHALL 各自凍結，凍結總額不得超過可用餘額。

#### Scenario: 多筆申請
- **WHEN** 第一筆 `pending` 時使用者再申請第二筆
- **THEN** 第二筆只要剩餘可用餘額足夠就成立

### Requirement: 加密貨幣出金申請
使用者 SHALL 能以 `POST /app/wallets/crypto/withdraw`（`{ currency: "USDT", amount, toAddress }`）申請出金。系統 SHALL 先驗證 `toAddress` 為合法 Tron Base58Check 位址，再在單一交易內凍結金額並建立 `pending` 的 `crypto_withdrawals`。使用者 SHALL 能以 `GET /app/wallets/crypto/withdrawals` 查詢紀錄。

#### Scenario: 非法位址
- **WHEN** `toAddress` 不是合法 Tron 位址
- **THEN** 回應 HTTP 400，不凍結、不建立紀錄

### Requirement: 加密貨幣出金廣播
Tron 出金任務 SHALL 以條件式更新認領 `pending` 並轉為 `broadcasting`，廣播成功後記錄 `tx_hash`；廣播失敗 SHALL 以 `WHERE status='broadcasting'` 的守衛轉為 `failed` 並解凍，僅在轉換實際發生時才解凍，避免重複解凍。廣播前 SHALL 驗證平台熱錢包的 USDT 餘額與 TRX 手續費餘額：USDT 不足時該筆轉 `failed`、解凍並通知管理員補充；TRX 不足時暫停出金並告警。`broadcasting` 的交易由掃描任務追蹤確認，不依賴私鑰；鏈上確認後 SHALL 在單一交易內轉 `confirmed` 並扣除凍結餘額，鏈上失敗轉 `failed` 並解凍。`HotWalletPrivateKey` 只存於環境變數，不得寫入版本控制。

#### Scenario: 廣播失敗
- **WHEN** 廣播交易失敗
- **THEN** 紀錄轉 `failed`，凍結額度解凍一次

#### Scenario: 熱錢包 USDT 不足
- **WHEN** 平台熱錢包 USDT 少於提領金額
- **THEN** 該筆轉 `failed` 並解凍，通知管理員

#### Scenario: 熱錢包 TRX 不足
- **WHEN** 熱錢包 TRX 不足以支付手續費
- **THEN** 暫停出金並告警，紀錄維持 `pending`

#### Scenario: 鏈上確認
- **WHEN** `broadcasting` 的交易達到確認數
- **THEN** 轉 `confirmed` 並從凍結餘額扣除

### Requirement: 後台出金可見性
後台 SHALL 能以 `GET /backend/fiat-withdrawals` 查詢法幣出金申請（含完整銀行帳號供核對），以 `GET /backend/platform/wallet-info` 查看平台熱錢包與 ECPay 設定摘要。

#### Scenario: 審核時核對
- **WHEN** 後台開啟待審核申請
- **THEN** 可見使用者填寫的完整銀行帳號

## 待確認事項

- 加密貨幣出金的手續費：是否由使用者金額內扣、另外收取或由平台吸收（原 spec 標「待確認」）。
- 核可後銀行轉帳失敗（退票）的處理流程；目前系統不追蹤轉帳結果，`approved` 為最終狀態。
- 法幣出金同一使用者同時 `pending` 筆數的風控上限。
- 原 spec 寫重複審核回 HTTP 400，實作為 409；本規格採 409。
