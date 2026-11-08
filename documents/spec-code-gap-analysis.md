# 規格與程式碼落差分析（公開版）

本文件只記錄 API 層級的對應、欄位與狀態差異，以及已做的規格決策與待確認事項。實作細節的驗證（記帳、鎖、並行等）另行處理，不在本文公開。

基準規格見 `openspec/specs/p2p-*` 與 `api-specs/projects/p2p-exchange-service/openapi.yaml`。

## 一、總覽

| 規格專案 | 程式碼現況 |
|---|---|
| p2p-exchange-service | 獨立程式碼庫有實作。舊版規格（`/orders`、`/trades`）與實作沒有任何一個 path 一致，已改寫為實際路由（`/app/*`、`/backend/*` 等） |
| pos-systems | pos-backend-api 與規格一致；pos-merchant-api 的多數路由不在規格內 |
| games-system | `paths: {}`，三個程式碼庫皆未找到 |
| staff-scheduling | `paths: {}`，三個程式碼庫皆未找到 |

## 二、p2p-exchange-service

### 2.1 資源命名

舊版規格以 Order（掛單）與 Trade（成交）建模，實作以 Listing（掛單）與 Order（成交訂單）建模，命名錯位。基準規格已改採實作的命名：

| 舊規格 | 實作與現行規格 |
|---|---|
| `POST /orders` | `POST /app/listings` |
| `POST /orders/{id}/trades` | `POST /app/orders`（掛單 ID 放在 body 的 `listingId`） |
| `POST /trades/{id}/mark-paid` | `PUT /app/orders/:id/pay` |
| `POST /trades/{id}/confirm-receipt` | `PUT /app/orders/:id/confirm` |
| `POST /trades/{id}/cancel` | `PUT /app/orders/:id/cancel`（必須帶 `reason`） |

規格沒有、實作有：取消掛單、查詢我的掛單、糾紛、後台仲裁、錢包、入金與出金、收款帳戶、註冊與登入、ECPay 通知、WebSocket 等，皆已納入 `openapi.yaml`（39 paths、42 operations）。

### 2.2 欄位與行為差異

| 項目 | 舊規格 | 實作 |
|---|---|---|
| 建立掛單欄位 | `baseCurrency, quoteCurrency, amount, price` | `type, cryptoCurrency, fiatCurrency, totalAmount, price, minOrderFiat, maxOrderFiat, paymentTimeLimit, paymentMethodId` |
| 買賣方向 | 角色對稱 | 掛單有 `type`（`buy`、`sell`） |
| 手續費與單筆限額 | 未提 | 有（`platformFee*`、`paymentFee*`、`minOrderFiat`、`maxOrderFiat`） |
| 建立成功的 HTTP 狀態碼 | 201 | 200 |
| 回應格式 | `code` 為字串 | `{ code, message, data }`，`code` 為整數，成功為 `0` |
| 分頁參數 | `page, pageSize` | `limit, offset` |
| ID 型別 | uuid 字串 | `int64`，訂單另有 `orderNo` |

### 2.3 狀態值

| 舊規格 | 實作與現行規格 |
|---|---|
| TradeStatus `PENDING_PAYMENT` | `matched` |
| `PAID_PENDING_CONFIRMATION` | `paid` |
| `COMPLETED` | `completed` |
| `CANCELLED` | `cancelled` |
| 無 | `releasing`（確認收款的中間態）、`timeout`、`disputed`、`refunded` |
| OrderStatus `OPEN` / `FILLED` / `CANCELLED` | 掛單 `active`、`paused`、`completed`、`cancelled` |

### 2.4 管理後台與前端

- 舊規格完全沒有涵蓋後台。後台路由（登入、掛單與訂單查詢、仲裁、會員、手動入金、平台錢包、法幣提領審核）已納入 `openapi.yaml`。
- 前端 App 實際呼叫的路由與後端路由表一致；舊規格沒有描述 App 實際使用的任何路徑。
- 舊版 demo 路由（`/v1/*`）沒有前端呼叫者，已自服務移除。

## 三、pos-systems

規格僅有 5 個 path：`/health`、`/ready`、`/api/admin/auth/login`、`/api/admin/auth/logout`、`/api/admin/merchants`。pos-backend-api 與之逐一對上；pos-merchant-api 約 15 條路由中，除 `/health`、`/ready` 外全部不在規格內，且路徑前綴不一致。待決定：規格補上 pos-merchant-api，或標明 pos-systems 僅涵蓋 pos-backend-api。

## 四、規格庫本身

1. `api-specs/dist/` 被 git 忽略，只存在本機，需以 `scripts/bundle.sh` 重建。
2. p2p-exchange-service 的 `CHANGELOG.md` 已更新到 1.0.0。
3. 舊的 `openspec/changes/p2p-exchange-service-v1-p2p-trading` 已標註被取代，尚未移入 `archive/`。
4. 其他專案（pos-systems、games-system、staff-scheduling）尚無主規格。

## 五、已做的規格決策（2026-11-08）

| 項目 | 決策 |
|---|---|
| 規格基準 | 以獨立程式碼庫的 `openspec/specs`（`/app/*`、`/backend/*`）為基準，統一為本 repo 的 7 份主規格 |
| 路由 | 以程式碼為準，規格同步 |
| 金額 | 所有金額類欄位統一同一種 Decimal：資料庫 `NUMERIC(38,18)`、API 十進位字串；實作端另開工項 |
| 掛單數量 | 每個使用者、每個幣種各一筆進行中掛單（buy 與 sell 各自一筆）；吃單沒有限制 |
| 取消 | 掛單有進行中訂單時不能取消；取消成功才返還剩餘額度；吃單取消成功才返還額度並還原掛單剩餘量 |
| 逾時 | 與取消的邏輯相同 |
| 確認收款 | 經 `releasing` 中間態，規格說明誰寫入 |
| 掛單完成 | 剩餘量為 0 且沒有進行中訂單時自動 `completed` |
| 禁止事項 | 禁止吃自己的掛單 |
| 狀態 | `timeout`、`refunded` 保留為獨立狀態 |
| 待補強行為 | 原 spec 標「待補強」「待確認」的行為，在規格中先定下來 |
| `minOrderFiat` | 允許為 0（現行 App 送出 0） |
| 買方法幣凍結 | 本階段不需要 |

## 六、待確認事項

1. 一筆限制是否只限 buy 掛單（使用者原話為「掛買單，每個幣種各一筆」，規格解讀為 buy 與 sell 各自一筆）。
2. 乘法結果取至 18 位小數的捨入方式（暫定四捨五入）。
3. `releasing` 失敗後的重試入口。
4. 加密貨幣出金手續費的收取方式；法幣出金核可後退票流程。
5. `PUT /app/orders/:id/pay` 規格照現行行為（僅買方、`matched` 轉 `paid`）。
6. `openapi.yaml` 中標註「待確認」的欄位：收款帳戶 `type` 列舉、帳本 `type` 完整列舉、入金與加密貨幣出金的狀態列舉、`GET /app/listings` 未帶 status 的預設、`GET /backend/members` 的 keyword 比對欄位、WebSocket 驗證與訊息格式。
7. `fiat/deposit` 的 `amount` 原為整數 TWD，規格依 Decimal 規則改為 Decimal 字串。
