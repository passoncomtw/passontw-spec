## ADDED Requirements

### Requirement: 員工登入/登出
系統 SHALL 允許商家端員工以帳號密碼登入商家 App，並簽發 bearer token 供後續 API 呼叫使用；SHALL 支援登出使該 token 失效。

#### Scenario: 登入成功
- **WHEN** 員工輸入正確的帳號與密碼
- **THEN** 系統回傳合法的 bearer token

#### Scenario: 登入失敗
- **WHEN** 員工輸入的帳號或密碼不正確
- **THEN** 系統拒絕登入，不簽發 token

#### Scenario: 登出
- **WHEN** 已登入員工送出登出請求
- **THEN** 系統使該次登入的 token 失效，後續以該 token 呼叫 API 皆被拒絕

### Requirement: 新增商品
系統 SHALL 允許已登入員工新增商品（名稱、價格）。

#### Scenario: 成功新增商品
- **WHEN** 已登入員工提交商品名稱與價格
- **THEN** 系統建立一筆 `Product` 記錄

#### Scenario: 缺少必要欄位
- **WHEN** 已登入員工提交的商品缺少名稱或價格
- **THEN** 系統拒絕建立，回傳對應錯誤

### Requirement: 查詢商品列表
系統 SHALL 允許已登入員工查詢目前所有商品列表，供結帳時選用。

#### Scenario: 查詢商品列表
- **WHEN** 已登入員工查詢商品列表
- **THEN** 系統回傳目前所有 `Product` 記錄

### Requirement: 結帳建立訂單與現金付款
系統 SHALL 允許已登入員工選擇一項或多項商品與數量建立訂單，計算總金額，並以現金收款方式完成結帳。

#### Scenario: 成功結帳
- **WHEN** 已登入員工提交一項或多項商品與數量
- **THEN** 系統建立一筆 `Order` 記錄（含 `totalAmount`、`employeeId`）與一筆對應的 `Payment` 記錄（`method` 為 `cash`）

#### Scenario: 結帳品項為空
- **WHEN** 已登入員工提交的訂單未包含任何商品
- **THEN** 系統拒絕建立，回傳對應錯誤

### Requirement: 出單機連線列印收據
系統 SHALL 在結帳完成後，透過區域網路連線 ESC/POS 相容出單機列印收據；列印失敗 SHALL NOT 影響已完成的結帳結果。

#### Scenario: 列印成功
- **WHEN** 結帳完成後系統連線出單機觸發列印
- **THEN** 系統建立一筆 `Receipt` 記錄，`printerStatus` 標記為成功，`printedAt` 記錄列印時間

#### Scenario: 列印失敗
- **WHEN** 結帳完成後連線出單機失敗或列印逾時
- **THEN** 系統仍保留已建立的 `Order` 與 `Payment` 記錄，`Receipt.printerStatus` 標記為失敗，供後續人工補印，不回滾訂單或付款

### Requirement: 商家端 API 需通過 Bearer Auth 驗證
系統 SHALL 要求商家端 App 的所有 API 請求（登入/登出除外）帶有合法的 `Authorization: Bearer <token>`，未帶或帶錯 token 的請求 SHALL 被拒絕。

#### Scenario: 缺少或錯誤 token
- **WHEN** 任一需要驗證的 API 請求未帶 `Authorization` header，或帶入的 token 不正確
- **THEN** 系統回傳 401，不執行任何操作

#### Scenario: 合法 token
- **WHEN** 請求帶入正確的 `Authorization: Bearer <token>`
- **THEN** 系統依請求內容處理該操作
