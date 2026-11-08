> 已被取代（2026-11-08）：p2p-exchange-service 的基準規格已統一為 `openspec/specs/` 下的 7 份主規格（`p2p-conventions`、`p2p-listing`、`p2p-order`、`p2p-dispute`、`p2p-wallet`、`p2p-deposit`、`p2p-withdrawal`）。本 change 僅作歷史參考，請勿 sync 或據以實作。是否移入 `archive/` 待使用者決定。

## ⚠️ 現況更新（2026-10-02，已被實際系統超越）

經與使用者確認，`token-system`（舊名，已改名為 `p2p-exchange-service`）描述的產品與 Jira PEP 專案既有的真實程式碼庫（Go / go-zero，已部署，後台 `p2p-exchange-web.passon.tw`）是**同一個產品**。本提案當初假設 `p2p-exchange-service` 規格完全空白、需要從零開始實作，但實際上這個產品已經大量完成（對應 Jira Epic 1~15，含掛單、下單、託管、多幣別錢包、法幣與鏈上入出金等）。

**本提案以下內容已不再代表實際開發方向，僅保留作歷史參考**：建立掛單、對掛單下單成交並託管凍結、標記已付款、確認收款放幣、取消解除託管等 7 條 Requirement，絕大部分已在 `p2p-exchange-service` 實作完成。

**目前實際的待辦事項**改以 PEP-44（2026-09-25 現況盤點）為準，追蹤於 Jira **Epic 20（token-system — 待辦事項補強）**，內容是客服角色 RBAC、後台出金功能、USDT 提領人工審核、掛單配對規則顯式驗證、Escrow 升級、手續費介面、Legacy 路由安全性等 8 項，與本提案原始範疇完全不同。若要了解 p2p-exchange-service 目前真正缺少什麼，請參考 Jira Epic 20，不要依據本文件規劃實作。

---

## Why

`p2p-exchange-service`（幣安 C2C 平台）目前只有 `Order`、`Trade` 的 schema stub，`paths` 為空，完全沒有可執行的 API。經過 explore 討論確認：這個系統的終局目標是仿 Binance C2C 的完整點對點交易平台（廣告掛牌、託管、付款憑證、放幣、爭議仲裁），但要分三個版本逐步建立，而不是一次到位。本次提案是第一版：讓使用者對使用者的交易（含資產託管）先能運作。

## What Changes

- 新增 p2p-exchange-service 的 API 端點與業務邏輯，涵蓋：建立掛單（Order）、對既有掛單下單成交（建立 Trade）、託管凍結、標記已付款、賣家確認收款放幣、取消/逾時解除凍結。
- 角色對稱：任何使用者都可以是掛單方或下單方，系統不區分「買家」「賣家」固定角色（僅在單筆 Trade 內以誰持有代幣、誰付款來區分資金流向）。
- 支援多幣種/多代幣交易對（幣種 A 換幣種 B 或法幣）。
- **不含**（刻意留給後續版本，見「後續規劃」）：廣告/掛牌上架介面、固定買賣角色分工、爭議/申訴/客服仲裁。

## Capabilities

### New Capabilities
- `p2p-exchange-service`: 幣安 C2C 平台 V1——使用者對使用者、角色對稱、含託管凍結的代幣交易能力

### Modified Capabilities
（無，p2p-exchange-service 目前尚無 baseline spec）

## Impact

- 影響 `api-specs/projects/p2p-exchange-service/openapi.yaml`（新增 paths）與 `schemas/order.yaml`、`schemas/trade.yaml`（補齊欄位與狀態機，取代「內容後續補充」）。
- 不影響其他專案（pos-systems、games-system、staff-scheduling、llm-fallback-gateway）。

## 後續規劃（Roadmap，記錄以避免未來重新討論）

這是三版路線圖的第一版，後續版本範圍已在 explore 階段與使用者確認，記錄如下，**未來啟動 V2、V3 時直接依此規劃，不需要重新討論定位**：

- **V1（本提案）**：使用者對使用者交易，角色對稱，含託管凍結，不含廣告掛牌、不含爭議仲裁。
- **V2（下一版）**：導入「買家／賣家角色分別」——正式區分掛牌方（賣家）與下單方（買家），並新增「廣告/掛牌」資源（價格、數量、付款方式），對應 Binance C2C 流程中「賣家上架廣告」的步驟。此版本也對應使用者提到的「平台對使用者」演進方向（平台可作為固定一側的角色）。
- **V3（再下一版）**：加入爭議/申訴流程與客服仲裁狀態機，處理「買家轉帳但賣家不確認收款」等爭議情境。
