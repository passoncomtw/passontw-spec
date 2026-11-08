## ADDED Requirements

### Requirement: 營運後台建立商戶帳號
系統 SHALL 允許營運後台使用者新增商戶帳號（username、密碼），商戶 SHALL NOT 擁有自助註冊入口。

#### Scenario: 成功新增商戶帳號
- **WHEN** 營運後台使用者以合法身分提交新的商戶 username 與密碼
- **THEN** 系統建立一筆 `Merchant` 記錄，密碼以雜湊方式儲存

#### Scenario: username 重複
- **WHEN** 營運後台使用者提交的 username 已存在於既有商戶
- **THEN** 系統拒絕建立，回傳對應錯誤，不產生重複帳號

### Requirement: 商戶登入商戶後台
系統 SHALL 允許商戶以營運後台建立的 username 與密碼登入商戶後台，並簽發 bearer token 供後續 API 呼叫使用。

#### Scenario: 登入成功
- **WHEN** 商戶輸入正確的 username 與密碼
- **THEN** 系統回傳合法的 bearer token

#### Scenario: 登入失敗
- **WHEN** 商戶輸入的 username 或密碼不正確
- **THEN** 系統拒絕登入，不簽發 token

### Requirement: 商戶上架遊戲
系統 SHALL 允許已登入的商戶以名稱與外部遊戲網址建立一筆遊戲上架申請，初始狀態為「待審核」。

#### Scenario: 成功送出上架申請
- **WHEN** 已登入的商戶提交遊戲名稱與外部遊戲網址
- **THEN** 系統建立一筆 `Game` 記錄，`status` 為 `pending`，`merchantId` 對應該商戶

#### Scenario: 缺少必要欄位
- **WHEN** 商戶提交的上架申請缺少名稱或外部遊戲網址
- **THEN** 系統拒絕建立，回傳對應錯誤

### Requirement: 商戶查詢自己的遊戲列表
系統 SHALL 允許商戶查詢僅屬於自己名下的遊戲列表，涵蓋所有狀態（待審核、已上架），SHALL NOT 顯示其他商戶的遊戲。

#### Scenario: 查詢自己的遊戲列表
- **WHEN** 已登入的商戶查詢遊戲列表
- **THEN** 系統僅回傳 `merchantId` 為該商戶的所有 `Game` 記錄，不論狀態

#### Scenario: 不可見其他商戶的遊戲
- **WHEN** 商戶 A 查詢遊戲列表
- **THEN** 回傳結果不包含任何 `merchantId` 非商戶 A 的遊戲

### Requirement: 營運後台審核遊戲上架申請
系統 SHALL 允許營運後台使用者將「待審核」狀態的遊戲審核通過，轉為「已上架」狀態；v1 SHALL NOT 提供駁回功能。

#### Scenario: 審核通過
- **WHEN** 營運後台使用者對一筆 `status` 為 `pending` 的遊戲執行審核通過
- **THEN** 該遊戲的 `status` 變更為 `approved`，並記錄 `approvedAt`

#### Scenario: 審核非待審核狀態的遊戲
- **WHEN** 營運後台使用者嘗試審核一筆 `status` 已為 `approved` 的遊戲
- **THEN** 系統拒絕該操作，不重複變更狀態

### Requirement: 玩家匿名瀏覽已上架遊戲列表
系統 SHALL 允許任何使用者（無需登入）查詢所有 `status` 為 `approved` 的遊戲列表，彙整所有商戶的已上架遊戲。

#### Scenario: 匿名查詢已上架遊戲
- **WHEN** 任何使用者（未帶任何登入憑證）查詢前端遊戲列表
- **THEN** 系統回傳所有 `status` 為 `approved` 的 `Game` 記錄，不區分商戶

#### Scenario: 待審核遊戲不出現在前端列表
- **WHEN** 某筆遊戲的 `status` 仍為 `pending`
- **THEN** 該筆遊戲 SHALL NOT 出現在玩家前端的遊戲列表中

### Requirement: 玩家進入遊戲建立 Session 記錄
系統 SHALL 在玩家（匿名）點擊進入某個已上架遊戲時，以 iframe 嵌入該遊戲的外部網址，並建立一筆 `Session` 記錄，記下進入時間。

#### Scenario: 進入已上架遊戲
- **WHEN** 玩家點擊一筆 `status` 為 `approved` 的遊戲
- **THEN** 前端以 iframe 嵌入該遊戲的 `externalUrl`，系統建立一筆 `Session` 記錄，`gameId` 對應該遊戲、`enteredAt` 記為當下時間、`leftAt` 為空

#### Scenario: 進入未上架遊戲
- **WHEN** 玩家嘗試進入一筆 `status` 非 `approved` 的遊戲
- **THEN** 系統拒絕該請求，不建立 Session 記錄

### Requirement: 玩家離開遊戲更新 Session 記錄
系統 SHALL 在玩家點擊離開按鈕、回到遊戲列表時，將對應的 `Session` 記錄補上離開時間。

#### Scenario: 離開遊戲
- **WHEN** 玩家在進入遊戲後點擊離開按鈕
- **THEN** 系統將對應的 `Session` 記錄的 `leftAt` 更新為當下時間，前端導回遊戲列表頁面

### Requirement: 商戶與營運後台 API 需通過 Bearer Auth 驗證
系統 SHALL 要求商戶後台、營運後台的所有 API 請求帶有合法的 `Authorization: Bearer <token>`，未帶或帶錯 token 的請求 SHALL 被拒絕；玩家前端的遊戲列表、進入、離開相關 API SHALL 保持匿名可存取，不要求登入。

#### Scenario: 商戶/營運後台 API 缺少或錯誤 token
- **WHEN** 商戶後台或營運後台的 API 請求未帶 `Authorization` header，或帶入的 token 不正確
- **THEN** 系統回傳 401，不執行任何商戶/營運相關操作

#### Scenario: 玩家前端 API 匿名存取
- **WHEN** 玩家呼叫遊戲列表、進入遊戲、離開遊戲等前端相關 API，未帶任何 `Authorization` header
- **THEN** 系統正常處理請求，不要求登入
