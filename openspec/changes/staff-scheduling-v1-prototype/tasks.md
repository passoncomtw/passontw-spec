## 1. 資料模型

- [ ] 1.1 更新 `Employee` schema（id、name、phone、password 雜湊、createdAt），取代現有空殼
- [ ] 1.2 新增 `Customer` schema（id、name、phone、password 雜湊、createdAt）
- [ ] 1.3 將 `Shift` 改為 `Appointment` schema（id、employeeId、customerId、startTime、endTime、status [confirmed/cancelled]、cancelledBy [admin/customer]、createdAt），取代現有空殼

## 2. 後台 Web API

- [ ] 2.1 實作新增人員帳號 API（手機＋初始密碼，密碼雜湊儲存，手機重複時拒絕）
- [ ] 2.2 實作建立預約 API（選人員、客戶、時段，缺必要欄位時拒絕）
- [ ] 2.3 實作同一人員時段衝突檢查（排除已取消的預約）
- [ ] 2.4 實作同一客戶時段衝突檢查（排除已取消的預約）
- [ ] 2.5 實作取消任一筆預約 API（`status` → `cancelled`，`cancelledBy` 記為 `admin`）

## 3. 客戶 App API

- [ ] 3.1 實作客戶自助註冊 API（手機＋密碼，手機已註冊時拒絕）
- [ ] 3.2 實作客戶登入 API（手機＋密碼驗證，簽發 bearer token）
- [ ] 3.3 實作客戶查詢自己預約列表 API（僅回傳 `customerId` 為自己的記錄）
- [ ] 3.4 實作客戶取消自己預約 API（`status` → `cancelled`，`cancelledBy` 記為 `customer`；取消他人預約時拒絕）

## 4. 人員 App API

- [ ] 4.1 實作人員登入 API（手機＋密碼驗證，簽發 bearer token）
- [ ] 4.2 實作人員查詢自己班表 API（僅回傳 `employeeId` 為自己的記錄，唯讀）

## 5. 權限與驗證

- [ ] 5.1 後台 Web、人員 App、客戶 App 的所有 API 套用既有 `bearerAuth`（JWT），未帶或錯誤 token 回傳 401
- [ ] 5.2 確保人員角色無法呼叫任何取消/修改預約的 API

## 6. 前端頁面（UI 範疇）

- [ ] 6.1 後台 Web 頁面：人員帳號管理、建立預約表單、預約列表與取消操作
- [ ] 6.2 人員 App 頁面：登入、自己的班表（唯讀）
- [ ] 6.3 客戶 App 頁面：註冊、登入、自己的預約列表與取消操作

## 7. 驗收驗證

- [ ] 7.1 驗證後台新增人員帳號後，人員可用該帳號登入 App
- [ ] 7.2 驗證手機號碼重複時，後台無法新增重複人員帳號，客戶也無法重複註冊
- [ ] 7.3 驗證後台建立預約後，該預約同時出現在對應人員與客戶的 App 列表中
- [ ] 7.4 驗證同一人員時段重疊時無法建立預約
- [ ] 7.5 驗證同一客戶時段重疊時無法建立預約
- [ ] 7.6 驗證與已取消預約重疊的時段可正常建立新預約（不視為衝突）
- [ ] 7.7 驗證後台可取消任一筆預約
- [ ] 7.8 驗證客戶可取消自己的預約，但無法取消他人的預約
- [ ] 7.9 驗證人員無法執行任何取消操作
- [ ] 7.10 驗證人員 App 僅能查看、無法修改或取消班表
- [ ] 7.11 驗證所有 API 在缺少或錯誤 token 時回傳 401

## 8. 文件更新

- [ ] 8.1 更新 `api-specs/projects/staff-scheduling/README.md`，說明角色與核心流程現況
- [ ] 8.2 更新 `api-specs/projects/staff-scheduling/CHANGELOG.md`，記錄本次新增的 v1 prototype 範疇
