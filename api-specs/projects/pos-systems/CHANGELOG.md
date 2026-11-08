# POS System API Changelog

## [未發布]
### Changed
- 將 `openapi.yaml` 內原本直接寫死的 schema（`LoginRequest`、`UserDTO`、`LoginData`、`LoginResponse`、`FieldError`、`ErrorResponse`、`Pagination`、`MerchantDTO`、`MerchantListData`、`MerchantListResponse`）搬移至對應的 `schemas/common.yaml`、`schemas/merchant.yaml`，`openapi.yaml` 改以 `$ref` 外部引用，與其他專案的目錄慣例一致
### Status
- 營運後台已實作：管理員登入/登出（`/api/admin/auth/login`、`/api/admin/auth/logout`）、商家列表查詢（`/api/admin/merchants`，含分頁與關鍵字搜尋，`MerchantDTO.status` 涵蓋基本的商家連線狀態）
- 商家 App（Electron，樹莓派部署）尚未實作：員工登入/登出、新增商品、結帳、連線出單機皆未開始；`Product`、`Order`、`Payment`、`Receipt`、`EmployeeSession` schema 仍是空殼
- README 所述「兩組 server（營運後台 API、商家端 API）」目前 `openapi.yaml` 只有營運後台一組；待商家端 API 實作時再一併補上第二組 server 設定

## [1.0.0] - 未定
### Added
- 初始結構
