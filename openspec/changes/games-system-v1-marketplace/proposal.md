## Why

`games-system` 專案目前只有初始化時建立的空骨架，`openapi.yaml` 沒有任何 API endpoint，`Game`、`Session` schema 皆為空殼，沒有任何業務邏輯或資料模型定義。使用者需要一個最小可行的遊戲平台原型：商戶可以自助申請上架遊戲，平台審核後，玩家可在前端匿名瀏覽並遊玩已上架的遊戲。本次提案補上這個三方角色（營運後台、商戶、玩家）的核心流程，作為 v1 prototype。

## What Changes

- 新增營運後台能力：新增商戶帳號（username + 密碼）、審核商戶送出的遊戲上架申請（v1 僅「通過」，無駁回流程）。
- 新增商戶後台能力：商戶以營運後台建立的帳號登入、上架遊戲（填寫名稱與外部遊戲網址，送出後進入待審核狀態）、查看自己名下的遊戲列表（含待審核與已上架狀態）。
- 新增玩家前端能力：匿名瀏覽所有已上架（審核通過）的遊戲列表、點擊進入遊戲頁面（以 iframe 嵌入商戶提供的外部遊戲網址）、點擊離開按鈕回到遊戲列表；進入與離開時各建立一筆 Session 記錄對應時間戳記。
- 重新定義 `Game`、新增 `Merchant` 兩個核心實體；`Session` 從空殼補上實際欄位，取代目前「內容後續補充」的佔位 schema。
- **架構決策**：商戶與營運後台皆沿用既有 `openapi.yaml` 的 `bearerAuth`（JWT）機制；玩家前端匿名存取、不需要任何登入或使用者身分即可瀏覽與遊玩。

## Capabilities

### New Capabilities
- `games-marketplace`：商戶上架遊戲、平台審核、玩家匿名瀏覽與遊玩的完整核心流程，涵蓋營運後台的商戶帳號管理與審核、商戶後台的上架與列表查詢、玩家前端的遊戲列表與進入/離開 Session 記錄。

### Modified Capabilities
（無。`games-system` 目前尚無 baseline spec。）

## Impact

- 影響 `api-specs/projects/games-system/openapi.yaml`：新增商戶帳號管理、遊戲上架、審核、遊戲列表、Session 相關 API endpoint（實作階段補上）。
- 影響 `api-specs/projects/games-system/schemas/game.yaml`：`Game` schema 從空殼補上 `merchantId`、`name`、`externalUrl`、`status`、`createdAt`、`approvedAt` 等欄位。
- 影響 `api-specs/projects/games-system/schemas/session.yaml`：`Session` schema 從空殼補上 `gameId`、`enteredAt`、`leftAt` 等欄位。
- 新增 `Merchant` schema（商戶帳號）。
- 不影響 `pos-systems`、`p2p-exchange-service`、`staff-scheduling`、`knowledge-base`。

## 本次不含（留給後續版本）

- 審核駁回流程（v1 只有通過）
- 遊戲下架功能（上架後永久顯示，無論商戶或營運後台都不能下架）
- 遊戲分類、縮圖、描述等豐富上架欄位（v1 只有名稱 + 外部網址）
- 玩家帳號與登入機制
- 商戶自行編輯或撤回已送出的上架申請
- 任何基於 Session 資料的報表/統計 API（v1 只負責記錄原始進入/離開時間，不做分析呈現）
- 營運後台使用者自身的帳號建立流程（假設為既有/預先建立，不在本次範疇）
