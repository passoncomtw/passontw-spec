# POS System API

POS 系統 OpenAPI 規格。兩套前端與對應後端。

## 架構

| 前端 | 後端部署 | 說明 |
|------|----------|------|
| 營運後台（Web） | Linux server | 統一 admin 登入/登出、各商家連線狀況 |
| 商家 App（Electron） | 樹莓派、商家區域網路 | 員工登入/登出、商品（關東煮）、結帳、出單機 |

## 專案目錄

- `openapi.yaml` 內含兩組 server：營運後台 API、商家端 API
- `schemas/` common（session）、merchant、product、order、payment、receipt
