## 1. 資料模型

- [ ] 1.1 更新 `Product` schema（id、name、price、createdAt），取代現有空殼
- [ ] 1.2 更新 `Order` schema（id、items、totalAmount、createdAt、employeeId），取代現有空殼
- [ ] 1.3 更新 `Payment` schema（id、orderId、method [cash]、amount、paidAt），取代現有空殼
- [ ] 1.4 更新 `Receipt` schema（id、orderId、printedAt、printerStatus），取代現有空殼
- [ ] 1.5 更新 `EmployeeSession` schema，取代現有空殼

## 2. 員工登入 API

- [ ] 2.1 實作員工登入 API（帳密驗證，簽發 bearer token）
- [ ] 2.2 實作員工登出 API（使 token 失效）

## 3. 商品管理 API

- [ ] 3.1 實作新增商品 API（名稱、價格必填）
- [ ] 3.2 實作查詢商品列表 API

## 4. 結帳 API

- [ ] 4.1 實作結帳 API（選擇商品與數量，計算總金額，品項為空時拒絕）
- [ ] 4.2 實作建立 `Order` 與 `Payment`（`method: cash`）記錄

## 5. 出單機連線

- [ ] 5.1 實作 ESC/POS 相容出單機連線列印（IP + Port 直連）
- [ ] 5.2 實作列印失敗時建立 `Receipt`（`printerStatus: failed`）但不回滾訂單/付款
- [ ] 5.3 實作人工補印機制（針對 `printerStatus: failed` 的訂單）

## 6. 權限與驗證

- [ ] 6.1 商家端 App 的所有 API（登入/登出除外）套用既有 `bearerAuth`，未帶或錯誤 token 回傳 401

## 7. 前端頁面（Electron App，UI 範疇）

- [ ] 7.1 登入頁面
- [ ] 7.2 商品管理頁面（新增、列表）
- [ ] 7.3 結帳頁面（選擇商品、計算總額、現金收款）
- [ ] 7.4 收據列印狀態提示（成功/失敗，失敗時提供補印操作）

## 8. 驗收驗證

- [ ] 8.1 驗證員工登入成功後可取得有效 token，登出後該 token 失效
- [ ] 8.2 驗證新增商品後可在商品列表查詢到
- [ ] 8.3 驗證結帳成功後建立對應的 Order 與 Payment（cash）記錄
- [ ] 8.4 驗證結帳品項為空時無法建立訂單
- [ ] 8.5 驗證出單機連線成功時列印收據並記錄成功狀態
- [ ] 8.6 驗證出單機連線失敗時，訂單與付款仍正常保留，收據標記失敗狀態
- [ ] 8.7 驗證所有需驗證的 API 在缺少或錯誤 token 時回傳 401

## 9. 文件更新

- [ ] 9.1 更新 `api-specs/projects/pos-systems/README.md`，說明商家端 App 的現況
- [ ] 9.2 更新 `api-specs/projects/pos-systems/CHANGELOG.md`，記錄本次新增的商家端 App 範疇
