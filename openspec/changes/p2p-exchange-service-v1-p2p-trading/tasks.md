## 1. Schema 更新

- [x] 1.1 更新 `schemas/common.yaml`：新增共用列舉（幣種代碼 CurrencyCode、Order 狀態 OrderStatus、Trade 狀態 TradeStatus）
- [x] 1.2 更新 `schemas/order.yaml`：補齊 Order 欄位（orderId、initiatorUserId、baseCurrency、quoteCurrency、amount、price、status、createdAt 等），移除「內容後續補充」
- [x] 1.3 更新 `schemas/trade.yaml`：補齊 Trade 欄位（tradeId、orderId、counterpartyUserId、status、escrowAmount、paidAt、confirmedAt、cancelledAt 等）及狀態機列舉

## 2. API Paths

- [x] 2.1 新增 `POST /orders`（建立掛單）
- [x] 2.2 新增 `GET /orders`、`GET /orders/{orderId}`（查詢掛單清單/單筆）
- [x] 2.3 新增 `POST /orders/{orderId}/trades`（對掛單下單成交，觸發託管凍結）
- [x] 2.4 新增 `POST /trades/{tradeId}/mark-paid`（付款方標記已付款）
- [x] 2.5 新增 `POST /trades/{tradeId}/confirm-receipt`（收款方確認收款並放幣）
- [x] 2.6 新增 `POST /trades/{tradeId}/cancel`（取消 Trade，解除凍結）
- [x] 2.7 新增 `GET /trades`、`GET /trades/{tradeId}`（查詢交易清單/單筆）

## 3. 錯誤與安全

- [x] 3.1 各 API 標註對應錯誤 responses（400/401/403/404/409，如掛單已成交後不可再下單、狀態不符時的操作衝突）
- [x] 3.2 確認 `security` 沿用既有 `bearerAuth`

## 4. 驗證

- [x] 4.1 執行 `./scripts/validate-all.sh` 確認 openapi.yaml 通過驗證（註：腳本本身因缺少 spectral ruleset 而在 pos-systems 就中斷，屬既有、跨專案的環境問題，非本次變更所致；改用 `npx @redocly/cli lint` 驗證 p2p-exchange-service，結果為 valid，僅有既有專案也都有的 operationId/license/server-url 風格警告）
- [x] 4.2 對照 `openspec/changes/p2p-exchange-service-v1-p2p-trading/specs/p2p-exchange-service/spec.md` 逐條需求確認 path/schema 皆已覆蓋（7 條 Requirement 皆有對應 path 或欄位）
