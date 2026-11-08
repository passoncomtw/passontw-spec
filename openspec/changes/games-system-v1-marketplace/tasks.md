## 1. 資料模型

- [ ] 1.1 定義 `Merchant` schema（id、username、password 雜湊、createdAt），取代現有空殼
- [ ] 1.2 更新 `Game` schema（id、merchantId、name、externalUrl、status [pending/approved]、createdAt、approvedAt），取代現有空殼
- [ ] 1.3 更新 `Session` schema（id、gameId、enteredAt、leftAt），取代現有空殼

## 2. 營運後台 API

- [ ] 2.1 實作新增商戶帳號 API（username、密碼，密碼雜湊儲存，username 重複時拒絕）
- [ ] 2.2 實作查詢待審核遊戲清單 API
- [ ] 2.3 實作審核通過 API（`pending` → `approved`，記錄 `approvedAt`；非 `pending` 狀態時拒絕）

## 3. 商戶後台 API

- [ ] 3.1 實作商戶登入 API（username + 密碼驗證，簽發 bearer token）
- [ ] 3.2 實作商戶上架遊戲 API（名稱 + 外部遊戲網址必填，建立 `status: pending` 的 `Game`）
- [ ] 3.3 實作商戶查詢自己遊戲列表 API（僅回傳 `merchantId` 為自己的記錄，含所有狀態）

## 4. 玩家前端 API

- [ ] 4.1 實作匿名查詢已上架遊戲列表 API（僅回傳 `status: approved` 的 `Game`）
- [ ] 4.2 實作玩家進入遊戲 API（驗證遊戲為 `approved` 狀態，建立 `Session` 記錄並回傳 `externalUrl` 供前端 iframe 嵌入）
- [ ] 4.3 實作玩家離開遊戲 API（更新對應 `Session` 的 `leftAt`）

## 5. 權限與驗證

- [ ] 5.1 商戶後台、營運後台 API 套用既有 `bearerAuth`（JWT），未帶或錯誤 token 回傳 401
- [ ] 5.2 確保玩家前端相關 API（列表、進入、離開）維持匿名可存取，不套用 bearerAuth

## 6. 前端頁面（UI 範疇）

- [ ] 6.1 商戶後台頁面：登入、上架遊戲表單、自己的遊戲列表（含狀態顯示）
- [ ] 6.2 營運後台頁面：商戶帳號管理、待審核遊戲清單與審核通過操作
- [ ] 6.3 玩家前端頁面：已上架遊戲列表、遊戲頁面（iframe 嵌入 `externalUrl`）、離開按鈕回到列表

## 7. 驗收驗證

- [ ] 7.1 驗證營運後台新增商戶帳號後，商戶可用該帳號登入商戶後台
- [ ] 7.2 驗證 username 重複時，營運後台無法新增重複商戶帳號
- [ ] 7.3 驗證商戶上架遊戲後，該筆遊戲狀態為「待審核」，且只出現在該商戶自己的遊戲列表中，不出現在其他商戶的列表
- [ ] 7.4 驗證待審核遊戲不會出現在玩家前端的已上架列表中
- [ ] 7.5 驗證營運後台審核通過後，該遊戲狀態變為「已上架」並出現在玩家前端列表
- [ ] 7.6 驗證玩家可匿名（無需登入）瀏覽已上架遊戲列表
- [ ] 7.7 驗證玩家點擊進入遊戲後，頁面以 iframe 嵌入商戶提供的外部網址，並建立一筆 Session 記錄下進入時間
- [ ] 7.8 驗證玩家點擊離開按鈕後，回到遊戲列表，且對應 Session 記錄補上離開時間
- [ ] 7.9 驗證商戶後台、營運後台 API 在缺少或錯誤 token 時回傳 401

## 8. 文件更新

- [ ] 8.1 更新 `api-specs/projects/games-system/README.md`，說明三方角色與核心流程現況
- [ ] 8.2 更新 `api-specs/projects/games-system/CHANGELOG.md`，記錄本次新增的 v1 prototype 範疇
