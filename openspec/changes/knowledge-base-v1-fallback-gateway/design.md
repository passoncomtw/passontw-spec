## Context

`knowledge-base`（前身 `llm-fallback-gateway`）目前只有 OpenAPI 規格（`chat/completions`、`providers`、`fallback` 三組端點），沒有可運行的服務。獨立環境上的 n8n TGBot workflow 已完成「收 Telegram 訊息 → 呼叫外部 LLM → 整理成檔案 → 上傳 Google Drive → 回覆使用者」的流程，但直接呼叫單一外部 LLM 供應商，沒有備援。

部署拓樸（經 explore 討論確認）：
- n8n 環境（`n8n.passon.tw`）與 OpenClaw droplet（DigitalOcean）是**兩個獨立環境**。
- 閘道服務要跑在 OpenClaw droplet 上，與規劃中的 `local-ollama` 第三順位同機。
- droplet 不開放對外 port；用 Cloudflare Tunnel（cloudflared）出站連線對外曝露一個子網域，TLS 由 Cloudflare 處理。
- n8n 端目前用**自訂 HTTP Request node**（非內建 OpenAI node）呼叫外部 LLM，換成閘道時只需改 URL 與 Authorization header。
- `schemas/chat.yaml` 的 `ChatCompletionResponse` 已設計成統一格式（`choices[0].message.content` + `providerId` 擴充欄位），不管背後是哪個供應商回應，回應格式一致，n8n 端不需要為不同供應商分別解析。

## Goals / Non-Goals

**Goals:**
- 讓 n8n TGBot workflow 透過閘道呼叫 LLM，取得三重備援（nvidia-kimi → openrouter-pony → local-ollama）的韌性。
- 閘道對外要求 bearer auth，供應商 API keys 只存在閘道端。
- 閘道透過 Cloudflare Tunnel 對外曝露，droplet 不開放對外 port。
- n8n 端只需改動一個 HTTP Request node 的 URL 與 Authorization header，其餘 workflow 邏輯不變。

**Non-Goals:**
- 不做 `GET/PUT /fallback` 動態調整 fallback 順序（V1 寫死在設定檔/環境變數）。
- 不做 `GET /providers` 供應商狀態監控端點的完整實作。
- 不做 Cloudflare Access、service token、mTLS 等更強認證機制。
- 不處理筆記/知識資料模型；該邏輯留在既有 n8n workflow + Google Drive，閘道完全不涉入。
- 不處理 OpenClaw 對閘道的實際整合測試（spec 相容但非本次驗收範圍）。

## Decisions

### 1. 語言/框架：待實作階段選定，建議單一二進位或容器
不在本設計文件中鎖定語言；建議挑選能單一二進位部署或容器化、且對三個供應商都有現成 HTTP client 支援的語言（Go/Node/Python 皆可）。原因：V1 目標是「架構坐穩」，語言本身不是本次決策重點，交由實作階段依熟悉度選定。

### 2. Fallback 策略：依序嘗試，第一個成功即回傳
依 `nvidia-kimi → openrouter-pony → local-ollama` 順序依序呼叫，遇到錯誤或逾時視為該供應商不可用，嘗試下一順位；全部失敗回傳 503。
- **考慮過的替代方案**：平行呼叫多個供應商取最快回應——放棄，因為會浪費配額且增加成本，與「省成本、資源有限」的個人專案脈絡不符。

### 3. 認證：單一靜態 bearer token（環境變數注入）
V1 用一組固定 token，由閘道啟動時從環境變數讀取，n8n 端在 Authorization header 帶入同一個 token。
- **考慮過的替代方案**：Cloudflare Access（Zero Trust）——放棄於 V1，因為會增加 n8n 端串接複雜度（需處理 service token 交換），留到後續版本視需要再加。
- **風險**：單一 token 外洩即失效整個閘道防護，需搭配 Cloudflare Tunnel（不開放對外 port）降低暴露面。

### 4. 對外曝露：Cloudflare Tunnel，不開放對外 port
用 `cloudflared` 在 droplet 端建立出站連線至 Cloudflare，對外提供一個子網域；droplet 不需開任何 inbound port，降低攻擊面，且 TLS 憑證由 Cloudflare 自動處理，不需自行管理憑證。
- **考慮過的替代方案**：droplet 直接開 port + 自建 reverse proxy（nginx/Caddy）+ 自簽或 Let's Encrypt TLS——放棄於 V1，因為「先用最簡單的方式打通」是使用者明確要求，Cloudflare Tunnel 設定量更小。

### 5. n8n 端改動範圍：只改一個 HTTP Request node 的 URL 與 header
因為閘道回應格式（`ChatCompletionResponse`）已與 OpenAI 相容且統一（不因供應商不同而變化），n8n 端不需要改動回應解析邏輯或下游的「整理成檔案、上傳 Google Drive」節點。

## Risks / Trade-offs

- **[風險] 單一靜態 bearer token 外洩** → 緩解：搭配 Cloudflare Tunnel 不開放對外 port，降低被掃描/暴力嘗試的暴露面；後續版本可視需要升級為 Cloudflare Access 或 token 輪替機制。
- **[風險] 三個供應商依序重試會增加單次回應延遲**（若 nvidia-kimi 逾時才 fallback 到下一順位，TGBot 回覆會變慢）→ 緩解：實作階段需設定合理的逾時時間（例如每個供應商幾秒內未回應即視為失敗，進下一順位），避免累加逾時造成使用者長時間等待。
- **[風險] local-ollama 與閘道同機，若 droplet 資源（vCPU/RAM）不足以同時跑 OpenClaw + jev + Ollama + 閘道本身** → 緩解：需在實作前確認 droplet 規格是否足夠；若不足，local-ollama 第三順位可能需要調整（例如降級為選用，非必要順位）。
- **[取捨] V1 不做 `/providers` 監控，出問題時較難即時得知是哪個供應商失敗** → 緩解：V1 至少要求閘道記錄結構化 log（呼叫的供應商、成功/失敗、耗時），方便事後查 log 排查，監控端點留到後續版本。

## Migration Plan

1. 實作閘道服務、加上 bearer auth，本機或 droplet 上先行驗證三重備援邏輯（可用假 API key 讓前面供應商刻意失敗，驗證 fallback 有觸發）。
2. 部署閘道到 OpenClaw droplet，設定 cloudflared tunnel 與子網域。
3. 在 n8n 上**先複製一份**現有 workflow 做測試修改（不直接改動生產 workflow），把 HTTP Request node 指向新閘道子網域，驗證端到端（Telegram 訊息 → 閘道 → LLM → 回覆 → Google Drive 檔案）皆正常。
4. 驗證通過後，將修改套用到正式的 workflow `3Amdvkf1TpWv8iRu`。
5. **Rollback**：若閘道異常，將 n8n 的 HTTP Request node URL/Authorization header 改回原本直接呼叫外部 LLM 的設定即可還原，不影響「整理成檔案、上傳 Google Drive」邏輯。

## Open Questions

- OpenClaw droplet 的實際規格（vCPU/RAM）是否足以同時運行 OpenClaw、jev、閘道服務、以及 local-ollama？需要在實作前確認。
- 閘道服務的語言/框架尚未選定，留待實作階段決定。
- Cloudflare 子網域要掛在哪個既有 domain 下（例如 `passon.tw` 底下的子網域命名），需要使用者於實作階段提供。
