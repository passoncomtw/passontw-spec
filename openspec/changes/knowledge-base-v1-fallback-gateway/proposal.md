## Why

`knowledge-base`（前身 `llm-fallback-gateway`）目前只有 OpenAPI 規格，沒有可運行的服務。與此同時，獨立環境上的 n8n TGBot workflow（`n8n.passon.tw/workflow/3Amdvkf1TpWv8iRu`）已經完成「收 Telegram 訊息 → 呼叫外部 LLM → 整理成檔案 → 上傳 Google Drive → 回覆使用者」的完整流程，但目前是用自訂 HTTP Request node **直接**呼叫單一外部 LLM 供應商，沒有備援：一旦該供應商超限或斷線，整條筆記整理流程就會中斷。本次提案的目標是把閘道服務實作出來，讓 n8n 改呼叫閘道，取得三重備援（nvidia-kimi → openrouter-pony → local-ollama）的韌性，而不需要改動 n8n 既有的整理/上傳邏輯。

## What Changes

- 實作 `knowledge-base` 閘道服務本身（語言未定，Go/Node/Python 皆可，建議單一二進位或容器），提供 `POST /v1/chat/completions`，依序嘗試 nvidia-kimi → openrouter-pony → local-ollama，直到成功或全部失敗（503）。
- **BREAKING**：閘道新增 bearer auth 要求（`Authorization: Bearer <token>`）。目前 spec 是 `security: []`（完全開放），V1 起呼叫方必須帶合法 token，否則所有既有（假設性的）無驗證呼叫方式都會失效。Provider API keys 只存在閘道端，呼叫方（n8n）不再需要持有外部 LLM 金鑰。
- 部署在 OpenClaw droplet（與 local-ollama 同機），透過 Cloudflare Tunnel（cloudflared）對外曝露一個子網域，droplet 不開放對外 port，TLS 由 Cloudflare 處理。
- 更新 n8n 現有的自訂 HTTP Request node：URL 改指向閘道子網域 `/v1/chat/completions`，Authorization header 改為閘道 bearer token；其餘 workflow（整理成檔案、上傳 Google Drive、回覆使用者）不變動。
- 更新 `knowledge-base` 專案文件（README、CHANGELOG）反映「閘道已實作、已與 n8n 串接」的現況。

## Capabilities

### New Capabilities
- `knowledge-base-gateway`：LLM Fallback 閘道能力——統一 OpenAI 相容的 `POST /v1/chat/completions` 入口，依序嘗試 nvidia-kimi、openrouter-pony、local-ollama 三個供應商直到成功，並要求 bearer auth。

### Modified Capabilities
（無，`knowledge-base` 目前尚無 baseline spec）

## Impact

- 影響 `api-specs/projects/knowledge-base/openapi.yaml`：`/chat/completions` path 新增 `security: [bearerAuth]` 要求。
- 影響 `api-specs/projects/knowledge-base/README.md`、`CHANGELOG.md`：更新為「閘道已實作、已與 n8n 串接」現況。
- 影響 n8n workflow `3Amdvkf1TpWv8iRu` 的自訂 HTTP Request node（URL、Authorization header）；workflow 其餘節點不變。
- 新增 droplet 端部署物件：閘道服務程式、systemd/容器設定、cloudflared 設定與子網域。
- 不影響 `pos-systems`、`p2p-exchange-service`、`games-system`、`staff-scheduling`。

## 本次不含（留給後續版本）

- `GET/PUT /fallback` 動態調整 fallback 順序（V1 先寫死在設定檔/環境變數）
- `GET /providers` 供應商狀態監控端點的完整實作（spec 已定義，非 V1 驗收必要項）
- Cloudflare Access 或更強的認證機制（service token、mTLS）——V1 先用單一靜態 bearer token
- 閘道涉入筆記/知識資料模型——完全不需要，該邏輯留在既有 n8n workflow + Google Drive
