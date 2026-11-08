# p2p-wallet Specification

## Purpose

錢包餘額模型、凍結與解凍、轉移、帳本與鎖。其他規格（掛單、訂單、糾紛、入金、出金）都透過本規格定義的操作異動餘額。

## Requirements

### Requirement: 餘額構成與幣種隔離
每位使用者每個幣種 SHALL 有一個錢包，`total_balance = available_balance + frozen_balance`。不同幣種的錢包完全獨立，不共享餘額或鎖。

#### Scenario: 凍結後總額不變
- **WHEN** 凍結 10 USDT
- **THEN** `available_balance` 減少 10、`frozen_balance` 增加 10，總額不變

### Requirement: 餘額非負
任何時刻 `available_balance >= 0` 且 `frozen_balance >= 0`。此約束 SHALL 由資料庫 CHECK 約束與程式碼雙重保證。

#### Scenario: 凍結超過可用餘額
- **WHEN** 可用餘額 100，要求凍結 150
- **THEN** 回應 HTTP 400 `insufficient balance`，餘額不變

#### Scenario: 解凍超過凍結餘額
- **WHEN** 凍結餘額 0，要求解凍 10
- **THEN** 操作失敗並整筆交易回滾，不得讓 `frozen_balance` 變成負數

#### Scenario: 轉移時賣方凍結不足
- **WHEN** 確認收款時賣方 `frozen_balance` 小於訂單數量
- **THEN** 整筆交易回滾，訂單狀態不變，並記錄告警

### Requirement: 餘額操作
所有餘額異動 SHALL 屬於下列操作之一，並且每個操作都要驗證金額為正的 Decimal。

| 操作 | available | frozen | 說明 |
|---|---|---|---|
| Freeze | -amount | +amount | 掛單或吃單凍結、出金申請 |
| Unfreeze | +amount | -amount | 取消掛單、取消或逾時、出金駁回 |
| TransferIn | 買方 +amount | 賣方 -amount | 確認收款或仲裁 complete，凍結量轉給買方 |
| Deposit | +amount | 0 | 入金確認 |
| DeductFrozen | 0 | -amount | 出金核可或鏈上確認 |

#### Scenario: 轉移的對象錢包不存在
- **WHEN** 買方沒有該幣種的錢包
- **THEN** 轉移時自動建立錢包並入帳

### Requirement: 鎖與交易
任何修改錢包的操作 SHALL 先取得分散式鎖（每位使用者每個幣種一把），再在資料庫交易內以 `SELECT ... FOR UPDATE` 鎖定錢包列。需要同時鎖定多位使用者時，MUST 依 userID 由小到大的順序取得。取鎖逾時 SHALL 回應 HTTP 500，且不得修改任何狀態。

#### Scenario: 雙方互相吃單
- **WHEN** 使用者 A 與 B 同時對彼此的掛單操作
- **THEN** 兩個操作都先鎖 userID 較小者，不會發生死鎖

#### Scenario: 取鎖逾時
- **WHEN** 等待鎖超過逾時時間
- **THEN** 回應 HTTP 500，餘額與訂單狀態都不變，由呼叫方重試

### Requirement: 帳本
每次餘額異動 SHALL 在同一個交易內寫入 `wallet_ledgers`，內容含錢包 ID、類型、金額、異動後餘額，以及關聯的訂單編號（若有）。同一錢包的帳本加總 SHALL 等於其餘額。

#### Scenario: 凍結寫入帳本
- **WHEN** 成功凍結 10 USDT
- **THEN** 同一交易內新增一筆 `freeze` 帳本

#### Scenario: 交易回滾
- **WHEN** 餘額異動所在的交易回滾
- **THEN** 對應的帳本也一併回滾

### Requirement: 錢包查詢
系統 SHALL 提供 `GET /app/wallets`（回傳使用者所有幣種的 `available` 與 `frozen`）與 `GET /app/wallets/:currency/ledgers`（帳本，分頁）。

#### Scenario: 查詢帳本
- **WHEN** 使用者查詢 `USDT` 帳本
- **THEN** 回傳該使用者 USDT 錢包的帳本，依時間新到舊排序

## 待確認事項

- 帳本加總等於餘額，目前沒有自動對帳機制；是否需要對帳排程。
- 非負約束需要在資料庫以 CHECK 約束落實（migration）。
