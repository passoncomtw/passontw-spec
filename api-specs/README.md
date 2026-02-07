# API Specs

多項目 OpenAPI 規格庫。

## 專案

| 專案 | 說明 |
|------|------|
| pos-systems | POS 系統 |
| token-system | 幣安 C2C 平台 |
| games-system | 遊戲遊玩平台 |

## 目錄

- `projects/` 各專案 OpenAPI 與 schemas
- `shared/` 共用 schemas 與 components
- `scripts/` 驗證、bundle、發布腳本

## 使用

- 驗證: `./scripts/validate-all.sh`
- Bundle: `./scripts/bundle.sh`（需安裝 @redocly/cli）
- 共用變更影響: `./scripts/impact-analysis.sh <檔案路徑>`
