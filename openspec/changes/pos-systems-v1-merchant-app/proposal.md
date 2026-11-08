## Why

`pos-systems` 的營運後台已實作完成（管理員登入/登出、商家列表查詢），但商家端 App（Electron，部署於樹莓派、商家區域網路）完全尚未實作，目前僅存在於原始 commit message 的一句話描述與 Jira 上的 4 個 Story，沒有正式規格可依循。本次提案把商家端 App 的核心流程（員工登入、商品管理、結帳、出單機連線）補上正式規格，讓實作有明確的 Requirement 可依循。

## What Changes

- 新增商家端 App 能力：員工以帳密登入/登出（沿用既有 `bearerAuth` JWT 機制）。
- 新增商品管理：員工可新增商品、查詢商品列表；v1 不支援編輯或刪除。
- 新增結帳流程：員工選擇商品建立訂單，計算總金額，以現金收款完成結帳；v1 不整合第三方金流或信用卡。
- 新增出單機連線：結帳完成後，透過區域網路直連 ESC/POS 相容出單機列印收據；不透過雲端列印服務。
- 重新定義 `Product`、`Order`、`Payment`、`Receipt`、`EmployeeSession`，取代目前「內容後續補充」的佔位 schema。

## Capabilities

### New Capabilities
- `pos-merchant-app`：商家端 App 的核心營運流程，涵蓋員工登入/登出、商品管理、結帳、出單機連線列印收據。

### Modified Capabilities
（無。`pos-systems` 既有的營運後台能力不受影響，本次只新增商家端 App 範疇。）

## Impact

- 影響 `api-specs/projects/pos-systems/openapi.yaml`：新增商家端 App 相關 API endpoint（實作階段補上，可能需要新增第二組 `servers` 對應商家端部署環境）。
- 影響 `api-specs/projects/pos-systems/schemas/product.yaml`：`Product` schema 從空殼補上 `id`、`name`、`price`、`createdAt`。
- 影響 `api-specs/projects/pos-systems/schemas/order.yaml`：`Order` schema 從空殼補上 `id`、`items`、`totalAmount`、`createdAt`、`employeeId`。
- 影響 `api-specs/projects/pos-systems/schemas/payment.yaml`：`Payment` schema 從空殼補上 `id`、`orderId`、`method`、`amount`、`paidAt`。
- 影響 `api-specs/projects/pos-systems/schemas/receipt.yaml`：`Receipt` schema 從空殼補上 `id`、`orderId`、`printedAt`、`printerStatus`。
- 影響 `api-specs/projects/pos-systems/schemas/common.yaml`：`EmployeeSession` schema 從空殼補上欄位。
- 不影響既有營運後台的 `AdminSession`、`MerchantDTO` 等既有 schema。
- 不影響 `p2p-exchange-service`、`games-system`、`staff-scheduling`、`knowledge-base`。

## 本次不含（留給後續版本）

- 商品編輯、刪除
- 信用卡/第三方金流整合
- 雲端列印服務
- 營運後台「商家連線狀態」獨立機制（已另外列為 v2 待辦，見 PEP-53）
