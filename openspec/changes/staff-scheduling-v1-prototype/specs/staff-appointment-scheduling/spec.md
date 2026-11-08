## ADDED Requirements

### Requirement: 後台新增人員帳號
系統 SHALL 允許後台使用者新增人員帳號（手機、密碼），建立時同時設定初始密碼；人員 SHALL NOT 擁有自助註冊入口。

#### Scenario: 成功新增人員帳號
- **WHEN** 後台使用者以合法身分提交新的人員手機號碼與初始密碼
- **THEN** 系統建立一筆 `Employee` 記錄，密碼以雜湊方式儲存

#### Scenario: 手機號碼重複
- **WHEN** 後台使用者提交的手機號碼已存在於既有人員
- **THEN** 系統拒絕建立，回傳對應錯誤，不產生重複帳號

### Requirement: 客戶自助註冊
系統 SHALL 允許客戶在 App 自行以手機與密碼註冊帳號，不需後台建立。

#### Scenario: 成功註冊
- **WHEN** 客戶提交未被使用的手機號碼與密碼
- **THEN** 系統建立一筆 `Customer` 記錄，密碼以雜湊方式儲存

#### Scenario: 手機號碼已被註冊
- **WHEN** 客戶提交的手機號碼已存在於既有客戶帳號
- **THEN** 系統拒絕註冊，回傳對應錯誤

### Requirement: 人員與客戶登入
系統 SHALL 允許人員與客戶以手機與密碼登入同一支 App，並依登入身份回傳對應角色可用的功能範圍。

#### Scenario: 登入成功
- **WHEN** 人員或客戶輸入正確的手機號碼與密碼
- **THEN** 系統回傳合法的 bearer token

#### Scenario: 登入失敗
- **WHEN** 輸入的手機號碼或密碼不正確
- **THEN** 系統拒絕登入，不簽發 token

### Requirement: 後台建立預約
系統 SHALL 允許後台使用者選擇人員、客戶、時段（起訖時間）建立一筆預約（Appointment），初始狀態為 `confirmed`。

#### Scenario: 成功建立預約
- **WHEN** 後台使用者提交有效的 employeeId、customerId、startTime、endTime，且無時段衝突
- **THEN** 系統建立一筆 `Appointment` 記錄，`status` 為 `confirmed`

#### Scenario: 缺少必要欄位
- **WHEN** 後台使用者提交的預約缺少人員、客戶或時段任一項
- **THEN** 系統拒絕建立，回傳對應錯誤

### Requirement: 同一人員時段衝突檢查
系統 SHALL 在建立預約時檢查同一人員是否已有時段重疊的既有預約（排除已取消的預約），重疊時 SHALL 拒絕建立。

#### Scenario: 人員時段重疊
- **WHEN** 欲建立的預約時段與該人員既有一筆 `status` 為 `confirmed` 的預約時段重疊
- **THEN** 系統拒絕建立該筆預約

#### Scenario: 與已取消的預約重疊不算衝突
- **WHEN** 欲建立的預約時段僅與該人員一筆 `status` 為 `cancelled` 的預約時段重疊
- **THEN** 系統正常建立該筆預約，不視為衝突

### Requirement: 同一客戶時段衝突檢查
系統 SHALL 在建立預約時檢查同一客戶是否已有時段重疊的既有預約（排除已取消的預約），重疊時 SHALL 拒絕建立。

#### Scenario: 客戶時段重疊
- **WHEN** 欲建立的預約時段與該客戶既有一筆 `status` 為 `confirmed` 的預約時段重疊
- **THEN** 系統拒絕建立該筆預約

#### Scenario: 與已取消的預約重疊不算衝突
- **WHEN** 欲建立的預約時段僅與該客戶一筆 `status` 為 `cancelled` 的預約時段重疊
- **THEN** 系統正常建立該筆預約，不視為衝突

### Requirement: 取消預約
系統 SHALL 允許後台使用者取消任一筆預約、允許客戶取消自己名下的預約；人員 SHALL NOT 擁有取消預約的權限。

#### Scenario: 後台取消任一筆預約
- **WHEN** 後台使用者對一筆 `status` 為 `confirmed` 的預約執行取消
- **THEN** 該預約的 `status` 變更為 `cancelled`，`cancelledBy` 記為 `admin`

#### Scenario: 客戶取消自己的預約
- **WHEN** 客戶對一筆屬於自己（`customerId` 為該客戶）且 `status` 為 `confirmed` 的預約執行取消
- **THEN** 該預約的 `status` 變更為 `cancelled`，`cancelledBy` 記為 `customer`

#### Scenario: 客戶嘗試取消他人的預約
- **WHEN** 客戶嘗試取消一筆 `customerId` 非自己的預約
- **THEN** 系統拒絕該操作

#### Scenario: 人員嘗試取消預約
- **WHEN** 人員嘗試對任一筆預約執行取消操作
- **THEN** 系統拒絕該操作，人員無此權限

### Requirement: 人員查看自己的班表
系統 SHALL 允許人員查詢僅屬於自己名下的預約列表（班表），唯讀，SHALL NOT 提供取消或修改操作。

#### Scenario: 查詢自己的班表
- **WHEN** 已登入的人員查詢班表
- **THEN** 系統僅回傳 `employeeId` 為該人員的所有 `Appointment` 記錄

#### Scenario: 不可見其他人員的班表
- **WHEN** 人員 A 查詢班表
- **THEN** 回傳結果不包含任何 `employeeId` 非人員 A 的預約

### Requirement: 客戶查看自己的預約
系統 SHALL 允許客戶查詢僅屬於自己名下的預約列表，並可對其中任一筆發起取消。

#### Scenario: 查詢自己的預約
- **WHEN** 已登入的客戶查詢預約列表
- **THEN** 系統僅回傳 `customerId` 為該客戶的所有 `Appointment` 記錄

#### Scenario: 不可見其他客戶的預約
- **WHEN** 客戶 A 查詢預約列表
- **THEN** 回傳結果不包含任何 `customerId` 非客戶 A 的預約

### Requirement: 後台與 App API 需通過 Bearer Auth 驗證
系統 SHALL 要求後台 Web、人員 App、客戶 App 的所有 API 請求帶有合法的 `Authorization: Bearer <token>`，未帶或帶錯 token 的請求 SHALL 被拒絕。

#### Scenario: 缺少或錯誤 token
- **WHEN** 任一 API 請求未帶 `Authorization` header，或帶入的 token 不正確
- **THEN** 系統回傳 401，不執行任何操作

#### Scenario: 合法 token
- **WHEN** 請求帶入正確的 `Authorization: Bearer <token>`
- **THEN** 系統依請求者角色處理該請求
