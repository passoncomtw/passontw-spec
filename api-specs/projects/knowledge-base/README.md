# Knowledge Base API

個人知識庫服務。目標是透過 Telegram Bot 收發訊息、Threads 留言收藏兩種管道收集資料，由 AI 協助整理成筆記與 wiki，並以雲端算力三重備援（Fallback）閘道作為 TGBot 對話的統一 LLM 後端。

## 子系統總覽

knowledge-base 下有三個彼此獨立、互不呼叫的子系統，僅共用專案命名空間與（部分）Google Drive 資料夾：

| 子系統 | 說明 | 現況 |
|--------|------|------|
| TGBot 對話流程 | Telegram Bot 收發訊息，n8n workflow 整理成檔案並上傳 Drive | 已完成，尚未串接 fallback 閘道 |
| LLM Fallback 閘道 | 統一 OpenAI 相容 `/v1/chat/completions`，三重備援 nvidia-kimi → openrouter-pony → local-ollama | 僅有 OpenAPI 規格與 openspec change（`knowledge-base-v1-fallback-gateway`），尚未實作 |
| Threads 資料收集 | Mentions 留言觸發收藏，讀取原文與外部連結寫入 `raw/`；獨立排程直連本機 Ollama 將 `raw/` 整理進 `wiki/` | 僅有 openspec change（`knowledge-base-threads-collection`），尚未實作 |

## 現況與目標的落差（開發現況）

1. **TGBot 對話流程（n8n workflow）**：**已完成**。
   - Workflow：`https://n8n.passon.tw/workflow/3Amdvkf1TpWv8iRu`
   - 使用者傳訊息給 Telegram Bot → n8n 直接呼叫外部 LLM（目前**未經過**本專案的 fallback 閘道，是 n8n 內建 AI node / HTTP node 直接打外部供應商）→ AI 回覆訊息給使用者。
   - 部署位置：DigitalOcean droplet（與 OpenClaw、jev 服務同機）。
2. **LLM Fallback 閘道服務（本專案 OpenAPI spec 對應的實作）**：**尚未實作、尚未與 n8n 串接**。
   - 目前僅有 `openapi.yaml` + schemas 規格，沒有可運行的服務程式碼。
   - 尚未整合進 TGBot 流程；n8n 目前是繞過閘道直接打外部 LLM。
   - 規劃詳見 `openspec/changes/knowledge-base-v1-fallback-gateway/`。
3. **Threads 資料收集（Flow A 收藏 / Flow B 整理）**：**尚未實作，僅有規格**。
   - 規格詳見 `openspec/changes/knowledge-base-threads-collection/`。
   - Flow A：主帳號在 Threads 貼文下留言標記收藏帳號 → webhook 觸發 → 讀取原文與外部連結內容 → 寫入 Google Drive 的 `knowledge-base/raw/threads/`、`knowledge-base/raw/web/`。
   - Flow B：獨立排程流程，定時讀取 `raw/`，**直連本機 Ollama**（不經過本專案的三重備援閘道）產生摘要，整理進 `knowledge-base/wiki/`，完成後移除已處理的 raw 檔。
   - Flow A、Flow B 與 TGBot 對話流程三者互不依賴，不共用 n8n workflow；Flow B 刻意不走閘道的理由見 design.md（避免 fallback 到雲端供應商導致資料外流第三方）。
   - 前置驗證待辦：需先以測試帳號確認 mentions 的 root_post 能否讀到他人貼文內容，方案才算成立。

**待辦（後續版本）**：
- 讓 TGBot 的 n8n workflow 改成呼叫本閘道的 `/v1/chat/completions`，取代直接呼叫外部 LLM，藉此享有三重備援（NVIDIA Kimi → OpenRouter Pony → 本機 Ollama）與供應商狀態監控能力。
- 依 `knowledge-base-threads-collection` 的 tasks.md 實作 Threads 收集 Flow A / Flow B。

## 預設供應商順序

| 優先 | 供應商 ID | 說明 |
|------|-----------|------|
| 1 | nvidia-kimi | NVIDIA Kimi k2.5，速度快、性能強 |
| 2 | openrouter-pony | OpenRouter Pony Alpha，免費額度、日常推理夠用 |
| 3 | local-ollama | 本機 Ollama，雲端全掛時底牌 |

## 專案目錄

以下僅為 LLM Fallback 閘道子系統的 OpenAPI 規格；Threads 資料收集子系統無對外 REST API（webhook 接收 + 寫入 Google Drive），規格以 openspec change 的形式維護，見下方「相關 openspec changes」。

- `openapi.yaml` 閘道 API（統一 chat、providers、fallback）
- `schemas/chat.yaml` 聊天請求/回應（OpenAI 相容）
- `schemas/provider.yaml` 供應商與狀態
- `schemas/fallback.yaml` Fallback 順序設定

## 相關 openspec changes

- `openspec/changes/knowledge-base-v1-fallback-gateway/`：LLM Fallback 閘道實作提案
- `openspec/changes/knowledge-base-threads-collection/`：Threads 資料收集（Flow A 收藏 / Flow B 整理）提案

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
- `GET /v1/providers`、`GET /v1/providers/{providerId}` 回傳目前狀態，供 OpenClaw、n8n 或監控使用。

### 4. 設定

- Fallback 順序：可從設定檔載入，或透過 `PUT /v1/fallback` 更新（實作可選）。
- API keys：NVIDIA、OpenRouter 等由環境變數或設定檔注入，不寫入 spec。

### 5. 與 OpenClaw / n8n 整合

- OpenClaw 將閘道設為單一 LLM 端點（base URL 指向本閘道）。
- n8n TGBot workflow（見上方「現況與目標的落差」）待後續版本改為呼叫本閘道，取代直接呼叫外部 LLM。
- 閘道內部負責三重備援，呼叫方無需改多組設定即可享有自動切換。

### 6. 依賴與部署

- 無強制依賴；本機需可連線至 NVIDIA / OpenRouter，以及（若啟用第三順位）本機 Ollama。
- 部署目標：DigitalOcean droplet，與 OpenClaw、jev、n8n 同機或同網段部署。
- 尚待決定：對外/對內網開放範圍、是否套用 `bearerAuth`（目前 spec 為 `security: []`，未驗證即可呼叫）。
