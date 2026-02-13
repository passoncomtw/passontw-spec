# LLM Fallback Gateway API

雲端算力三重備援（Fallback）閘道規格。依「速度與性能」由高到低排列，前一個超限或斷線時自動切換下一順位。

## 預設供應商順序

| 優先 | 供應商 ID | 說明 |
|------|-----------|------|
| 1 | nvidia-kimi | NVIDIA Kimi k2.5，速度快、性能強 |
| 2 | openrouter-pony | OpenRouter Pony Alpha，免費額度、日常推理夠用 |
| 3 | local-ollama | 本機 Ollama，雲端全掛時底牌 |

## 專案目錄

- `openapi.yaml` 閘道 API（統一 chat、providers、fallback）
- `schemas/chat.yaml` 聊天請求/回應（OpenAI 相容）
- `schemas/provider.yaml` 供應商與狀態
- `schemas/fallback.yaml` Fallback 順序設定

## 實作規劃

### 1. 閘道服務

- 語言/框架：任選（Go/Node/Python），建議單一二進位或容器。
- 埠：與 spec 一致（例如 11435），避免與本機 Ollama 11434 衝突。
- 行為：
  - 讀取 fallback 順序（設定檔或 `GET/PUT /fallback`）。
  - 對外提供 `POST /v1/chat/completions`，請求格式與 OpenAI 相容。
  - 依序呼叫各供應商對應的 API（NVIDIA NIM、OpenRouter、Ollama），直到某一個回傳成功。
  - 回傳時可加上 `providerId` 表示實際使用的供應商。

### 2. 供應商介接

- **nvidia-kimi**：NVIDIA NIM / Moonshot API，需 API key；錯誤或 429 時標記 rate_limited/unavailable，並嘗試下一順位。
- **openrouter-pony**：OpenRouter API，model 名 Pony Alpha；同上處理錯誤與限流。
- **local-ollama**：本機 `http://localhost:11434/v1/chat/completions`；連線失敗時標記 unavailable。

### 3. 狀態與健康檢查

- 背景定期（或 on-demand）檢查各供應商：可呼叫各端點或輕量 health 請求。
- 更新 `Provider.status`（available / rate_limited / unavailable / error）。
- `GET /v1/providers`、`GET /v1/providers/{providerId}` 回傳目前狀態，供 OpenClaw 或監控使用。

### 4. 設定

- Fallback 順序：可從設定檔載入，或透過 `PUT /v1/fallback` 更新（實作可選）。
- API keys：NVIDIA、OpenRouter 等由環境變數或設定檔注入，不寫入 spec。

### 5. 與 OpenClaw 整合

- OpenClaw 將閘道設為單一 LLM 端點（base URL 指向本閘道）。
- 閘道內部負責三重備援，OpenClaw 無需改多組設定即可享有自動切換。

### 6. 依賴與部署

- 無強制依賴；本機需可連線至 NVIDIA / OpenRouter，以及（若啟用第三順位）本機 Ollama。
- 部署：本機執行、Docker 或與 OpenClaw 同機部署皆可。
