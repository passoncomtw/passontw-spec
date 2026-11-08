# p2p-exchange-service API Changelog

## [1.0.0] - 2026-11-08
### Changed
- 整份改寫為實際路由（`/app/*`、`/backend/*` 等 39 paths、42 operations），取代舊設計（`/orders`、`/trades`）
- 金額欄位一律為 Decimal 字串
- 訂單狀態：matched、paid、releasing、completed、cancelled、timeout、disputed、refunded
- schemas 拆分為 common、auth、listing、order、wallet、deposit_withdraw、backend

### Removed
- `schemas/trade.yaml`
- `/v1/*` legacy 路由不納入
